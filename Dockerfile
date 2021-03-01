FROM crystallang/crystal:0.36.1-alpine as build

ARG PLACE_COMMIT=DEV

WORKDIR /app

# Install the latest version of LLVM, LibSSH2, ping, curl, git
RUN apk add --no-cache curl git iputils libssh2 libssh2-dev libssh2-static llvm llvm-dev

# Add trusted CAs for communicating with external services
RUN apk update && apk add --no-cache ca-certificates tzdata && update-ca-certificates

# Install asdf version manager
RUN git clone https://github.com/asdf-vm/asdf.git /app/.asdf --branch v0.8.0

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
USER appuser:appuser

# Install deps
COPY shard.yml /app
COPY shard.override.yml /app
COPY shard.lock /app
RUN shards install --production --release

# These provide certificate chain validation where communicating with external services over TLS
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# Add source last for efficient caching
COPY src /app/src

# Build the required target
RUN UNAME_AT_COMPILE_TIME=true \
    PLACE_COMMIT=${PLACE_COMMIT} \
    shards build --production --release --static --error-trace

# Create binary directories
RUN mkdir -p repositories bin/drivers
RUN chown appuser -R /app

###############################################################################

EXPOSE 3000
HEALTHCHECK CMD wget -qO- http://localhost:3000/api/build/v1
CMD ["/bin/build", "--server", "-b", "0.0.0.0", "-p", "3000"]
