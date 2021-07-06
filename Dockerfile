ARG CRYSTAL_VERSION=1.0.0
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine-build as build-digest

WORKDIR /app

# Install the latest version of LLVM, LibSSH2, ping, git, ca-certificates
RUN apk add --update --no-cache \
            bash \
            yaml-static

# Build a missing llvm artefact.
COPY scripts/build_llvm_ext.sh build_llvm_ext.sh
RUN ./build_llvm_ext.sh

COPY shard.* .
RUN shards install --production --ignore-crystal-version

COPY src/digest_cli.cr src/digest_cli.cr

# Build the required target
RUN CRYSTAL_PATH=lib:/usr/share/crystal/src/ \
    LLVM_CONFIG=$(/usr/share/crystal/src/llvm/ext/find-llvm-config) \
    shards build --release --no-debug --error-trace --ignore-crystal-version --production digest_cli && \
    rm /usr/share/crystal/src/llvm/ext/llvm_ext.o

FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine as build

ARG PLACE_COMMIT=DEV
ARG PLACE_VERSION=DEV

WORKDIR /app

# Install the latest version of LLVM, LibSSH2, ping, git, ca-certificates
RUN apk add --update --no-cache \
            bash \
            ca-certificates \
            iputils \
            libssh2-static \
            yaml-static

# Add trusted CAs for communicating with external services
RUN update-ca-certificates

# TODO: Awaiting asdf static crystal patch
# Install asdf version manager
# RUN git clone https://github.com/asdf-vm/asdf.git /app/.asdf --branch v0.8.0
# RUN /app/.asdf/bin/asdf plugin-add crystal https://github.com/asdf-community/asdf-crystal.git

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

# These provide certificate chain validation where communicating with external services over TLS
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# Create binary directories
RUN mkdir -p repositories bin/drivers

RUN mkdir /app/.shards

# Install deps
COPY shard.yml /app
COPY shard.lock /app

RUN shards install --production --ignore-crystal-version

# Add source last for efficient caching
COPY src /app/src

ENV CRYSTAL_VERSION=$CRYSTAL_VERSION

# Build the required target
RUN PLACE_COMMIT=${PLACE_COMMIT} \
    PLACE_VERSION=${PLACE_VERSION} \
    UNAME_AT_COMPILE_TIME=true \
    shards build --no-debug --release --error-trace --ignore-crystal-version --production build

COPY --from=build-digest /app/bin/digest_cli /app/bin

RUN chown appuser -R /app

###############################################################################

USER appuser:appuser

EXPOSE 3000
HEALTHCHECK CMD /app/bin/build server --curl http://localhost:3000/api/build/v1
CMD ["/app/scripts/entrypoint.sh", server, "-b", "0.0.0.0", "-p", "3000"]
