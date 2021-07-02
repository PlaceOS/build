ARG CRYSTAL_VERSION=1.0.0
ARG PLACE_COMMIT="DEV"

FROM crystallang/crystal:${CRYSTAL_VERSION} as build

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

# Add trusted CAs for communicating with external services
RUN update-ca-certificates

# Create binary directories
RUN mkdir -p repositories bin/drivers
# Install watchexec
RUN curl -sLO https://github.com/watchexec/watchexec/releases/download/cli-v1.16.0/watchexec-1.16.0-x86_64-unknown-linux-gnu.deb && \
    dpkg -i watchexec-1.16.0-x86_64-unknown-linux-gnu.deb && \
    rm -rf ./*.deb

RUN mkdir -p /app/bin/drivers

# Install shards before adding source.
COPY shard.yml /app
COPY shard.lock /app
RUN shards install --ignore-crystal-version

# Build digest tool before copying rest of source for better caching.
COPY src/digest_cli.cr /app/src/digest_cli.cr
RUN CRYSTAL_PATH=lib:/usr/share/crystal/src/ \
    LLVM_CONFIG=$(/usr/share/crystal/src/llvm/ext/find-llvm-config) \
    shards build digest_cli -Dpreview_mt --ignore-crystal-version --no-debug --production

# Add the rest of the source last for efficient caching
COPY scripts /app/scripts
COPY src /app/src

RUN PLACE_COMMIT=${PLACE_COMMIT} \
    UNAME_AT_COMPILE_TIME=true \
    shards build --error-trace -Dpreview_mt --release --ignore-crystal-version --production build

###############################################################################

ENV HOME="/app"
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV CRYSTAL_VERSION=$CRYSTAL_VERSION

# Create a non-privileged user
ARG IMAGE_UID="10001"
ENV UID=$IMAGE_UID
ENV USER=appuser
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"

RUN chown appuser -R /app

# Install asdf version manager
SHELL ["/bin/bash", "-l", "-c"]
RUN git clone --depth 1 https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.8.0 && \
    $HOME/.asdf/bin/asdf plugin-add crystal https://github.com/asdf-community/asdf-crystal.git && \
    echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc && \
    echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.profile && \
    source ~/.bashrc

USER appuser:appuser
RUN chown appuser -R /app

EXPOSE 3000
HEALTHCHECK CMD wget -qO- http://localhost:3000/api/build/v1
CMD ["/app/scripts/entrypoint.sh", "--server", "-b", "0.0.0.0", "-p", "3000"]