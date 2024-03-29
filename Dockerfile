ARG CRYSTAL_VERSION=latest

FROM placeos/crystal:$CRYSTAL_VERSION as build
WORKDIR /app

# Set the commit via a build arg
ARG PLACE_COMMIT="DEV"
# Set the platform version via a build arg
ARG PLACE_VERSION="DEV"

# Install shards for caching
COPY shard.* .
RUN shards install --production --ignore-crystal-version --skip-postinstall --skip-executables

# Add source last for efficient caching
COPY src /app/src

# Build the required target
RUN PLACE_COMMIT=${PLACE_COMMIT} \
    PLACE_VERSION=${PLACE_VERSION} \
    UNAME_AT_COMPILE_TIME=true \
    CRYSTAL_VERSION=${CRYSTAL_VERSION} \
    shards build \
    build \
    --debug \
    --error-trace \
    --production \
    --release

RUN rm -r lib src

# Add scripts
COPY scripts /app/scripts

###############################################################################

ENV HOME="/app"
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ARG IMAGE_UID="10001"
ENV UID=$IMAGE_UID
ENV USER=appuser

# Create a non-privileged user
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "${HOME}" \
    --shell "/sbin/nologin" \
    --uid "${UID}" \
    "${USER}"

RUN chown appuser -R /app

EXPOSE 3000
ENTRYPOINT ["/app/bin/build", "server"]
HEALTHCHECK CMD ["/app/bin/build", "server", "--curl", "http://localhost:3000/api/build/v1"]
CMD ["/app/bin/build", "server"]
