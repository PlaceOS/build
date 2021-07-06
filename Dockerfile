ARG CRYSTAL_VERSION=1.0.0

# Build `digest_cli`
###############################################################################
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine-build as build-digest

WORKDIR /app

RUN apk add --update --no-cache \
            bash \
            yaml-static

# Build a missing llvm artefact, `llvm_ext.o`
COPY scripts/build_llvm_ext.sh build_llvm_ext.sh
RUN ./build_llvm_ext.sh

COPY shard.* .
RUN shards install --production --ignore-crystal-version

COPY src/digest_cli.cr src/digest_cli.cr

# Build the required target
RUN CRYSTAL_PATH=lib:/usr/share/crystal/src/ \
    LLVM_CONFIG=$(/usr/share/crystal/src/llvm/ext/find-llvm-config) \
    shards build --static --no-debug --error-trace --ignore-crystal-version --production digest_cli && \
    rm /usr/share/crystal/src/llvm/ext/llvm_ext.o

# Build `build`
###############################################################################
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine as build

ARG CRYSTAL_VERSION=1.0.0
ARG PLACE_COMMIT="DEV"

WORKDIR /app

COPY shard.* .
RUN shards install --production --ignore-crystal-version

# Add source last for efficient caching
COPY src /app/src

# Build the required target
RUN PLACE_COMMIT=${PLACE_COMMIT} \
    PLACE_VERSION=${PLACE_VERSION} \
    UNAME_AT_COMPILE_TIME=true \
    CRYSTAL_VERSION=${CRYSTAL_VERSION}} \
    shards build --no-debug --release --error-trace --ignore-crystal-version --production build

COPY --from=build-digest /app/bin/digest_cli /app/bin

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
HEALTHCHECK CMD /app/bin/build server --curl http://localhost:3000/api/build/v1
CMD ["/app/scripts/entrypoint.sh", server, "-b", "0.0.0.0", "-p", "3000"]
