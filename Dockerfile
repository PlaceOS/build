ARG CRYSTAL_VERSION=1.0.0
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine as build

ARG PLACE_COMMIT=DEV

WORKDIR /app

# Install the latest version of LLVM, LibSSH2, ping, curl, git, ca-certificates
RUN apk add --no-cache \
            bash \
            ca-certificates \
            curl \
            git \
            iputils \
            libssh2 libssh2-dev libssh2-static \
            llvm llvm-dev \
            tzdata \
            yaml-static

# Add trusted CAs for communicating with external services
RUN update-ca-certificates

# Install asdf version manager

RUN git clone https://github.com/asdf-vm/asdf.git /app/.asdf --branch v0.8.0
RUN /app/.asdf/bin/asdf plugin-add crystal https://github.com/asdf-community/asdf-crystal.git

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

RUN shards install --production

# Add source last for efficient caching
COPY src /app/src

# Build the required target
RUN CRYSTAL_PATH=lib:/usr/share/crystal/src/ \
    LLVM_CONFGI=$(/usr/share/crystal/src/llvm/ext/find-llvm-config) \
    PLACE_COMMIT=${PLACE_COMMIT} \
    UNAME_AT_COMPILE_TIME=true \
    shards build --error-trace --ignore-crystal-version --production

RUN chown appuser -R /app

###############################################################################

USER appuser:appuser

EXPOSE 3000
HEALTHCHECK CMD wget -qO- http://localhost:3000/api/build/v1
CMD ["/app/scripts/entrypoint.sh", "--server", "-b", "0.0.0.0", "-p", "3000"]
