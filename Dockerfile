ARG CRYSTAL_VERSION=1.0.0

# Digest CLI
###############################################################################
FROM crystallang/crystal:${CRYSTAL_VERSION} as digest

ARG CRYSTAL_VERSION=1.0.0
ARG PLACE_COMMIT="DEV"

WORKDIR /app

RUN apt-get update && \
    apt-get install -y apt-transport-https && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive \
    apt install --no-install-recommends -y \
        bash \
        ca-certificates \
        curl \
        llvm-10 llvm-10-dev \
        libssh2-1 libssh2-1-dev \
        libyaml-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install shards before adding source.
COPY shard.yml /app
COPY shard.lock /app
RUN shards install --ignore-crystal-version

# Build digest tool before copying rest of source for better caching.
COPY src/digest_cli.cr /app/src/digest_cli.cr
RUN CRYSTAL_PATH=lib:/usr/share/crystal/src/ \
    LLVM_CONFIG=$(/usr/share/crystal/src/llvm/ext/find-llvm-config) \
    shards build digest_cli -Dpreview_mt --ignore-crystal-version --no-debug --production

# Extract dependencies
RUN ldd /app/bin/digest_cli | tr -s '[:blank:]' '\n' | grep '^/' | xargs -I % sh -c 'mkdir -p $(dirname deps%); cp % deps%;'

# Build
###############################################################################

FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine as build

ARG CRYSTAL_VERSION=1.0.0
ARG PLACE_COMMIT="DEV"

WORKDIR /app

# Install the latest version of LibSSH2, ping, etc
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    iputils \
    libssh2-static \
    yaml-static

# Add a glibc shim
# NOTE: Once musl builds are a supported target, `asdf` should be updated to use those builds
RUN mkdir keys && (cd keys && curl -slO https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub) && \
    curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.33-r0/glibc-2.33-r0.apk && \
    curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.33-r0/glibc-i18n-2.33-r0.apk && \
    curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.33-r0/glibc-bin-2.33-r0.apk && \
    curl -sLO https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.33-r0/glibc-dev-2.33-r0.apk && \
    apk add --allow-untrusted --keys-dir keys glibc-2.33-r0.apk && \
    apk add --allow-untrusted --keys-dir keys glibc-dev-2.33-r0.apk && \
    apk add --allow-untrusted --keys-dir keys glibc-bin-2.33-r0.apk && \
    apk add --allow-untrusted --keys-dir keys glibc-i18n-2.33-r0.apk && \
    rm -r keys *.apk

# Add trusted CAs for communicating with external services
RUN update-ca-certificates

# Install shards before adding source.
COPY shard.yml /app
COPY shard.lock /app
RUN shards install --ignore-crystal-version

# Copy the `digest_cli` binary, and all of its runtime dependencies
COPY --from=digest /app/deps /
COPY --from=digest /app/bin/digest_cli /app/bin

# Add the rest of the source last for efficient caching
COPY scripts /app/scripts
COPY src /app/src

RUN PLACE_COMMIT=${PLACE_COMMIT} \
    UNAME_AT_COMPILE_TIME=true \
    shards build --error-trace -Dpreview_mt --release --ignore-crystal-version --production build

###############################################################################

ENV HOME="/app"
ENV CRYSTAL_VERSION=$CRYSTAL_VERSION
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# Create a non-privileged user
ARG IMAGE_UID="10001"
ENV UID=$IMAGE_UID
ENV USER=appuser
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "${HOME}" \
    --shell "/sbin/nologin" \
    --uid "${UID}" \
    "${USER}"

# Install asdf version manager
SHELL ["/bin/bash", "-l", "-c"]
RUN git clone --depth 1 https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.8.0 && \
    $HOME/.asdf/bin/asdf plugin-add crystal https://github.com/asdf-community/asdf-crystal.git && \
    echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc && \
    echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.profile && \
    source ~/.bashrc

RUN chown appuser -R "${HOME}"
USER appuser:appuser

EXPOSE 3000
HEALTHCHECK CMD wget -qO- http://localhost:3000/api/build/v1
CMD ["/app/scripts/entrypoint.sh", "--server", "-b", "0.0.0.0", "-p", "3000"]
