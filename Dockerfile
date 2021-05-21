ARG CRYSTAL_VERSION=1.0.0
FROM crystallang/crystal:${CRYSTAL_VERSION} as build

ARG PLACE_COMMIT=DEV

WORKDIR /app

RUN apt update
RUN apt install --no-install-recommends -y \
        bash \
        ca-certificates \
        curl \
        git \
        llvm-10 llvm-10-dev \
        tzdata

# Install the latest version of LibSSH2
RUN curl -sLO https://launchpad.net/ubuntu/+source/libgpg-error/1.32-1/+build/15118612/+files/libgpg-error0_1.32-1_amd64.deb && dpkg -i libgpg-error0_1.32-1_amd64.deb
RUN curl -sLO https://launchpad.net/ubuntu/+source/libgcrypt20/1.8.3-1ubuntu1/+build/15106861/+files/libgcrypt20_1.8.3-1ubuntu1_amd64.deb && dpkg -i libgcrypt20_1.8.3-1ubuntu1_amd64.deb
RUN curl -sLO https://launchpad.net/ubuntu/+source/libssh2/1.8.0-2/+build/15151524/+files/libssh2-1_1.8.0-2_amd64.deb && dpkg -i libssh2-1_1.8.0-2_amd64.deb
RUN curl -sLO https://launchpad.net/ubuntu/+source/libgpg-error/1.32-1/+build/15118612/+files/libgpg-error-dev_1.32-1_amd64.deb && dpkg -i libgpg-error-dev_1.32-1_amd64.deb
RUN curl -sLO https://launchpad.net/ubuntu/+source/libgcrypt20/1.8.3-1ubuntu1/+build/15106861/+files/libgcrypt20-dev_1.8.3-1ubuntu1_amd64.deb && dpkg -i libgcrypt20-dev_1.8.3-1ubuntu1_amd64.deb
RUN curl -sLO https://launchpad.net/ubuntu/+source/libssh2/1.8.0-2/+build/15151524/+files/libssh2-1-dev_1.8.0-2_amd64.deb && dpkg -i libssh2-1-dev_1.8.0-2_amd64.deb
RUN rm -rf ./*.deb

# Add trusted CAs for communicating with external services
RUN update-ca-certificates

SHELL ["/bin/bash", "-l", "-c"]

# Install asdf version manager
RUN git clone https://github.com/asdf-vm/asdf.git $HOME/.asdf --branch v0.8.0
RUN $HOME/.asdf/bin/asdf plugin-add crystal https://github.com/asdf-community/asdf-crystal.git

RUN echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.bashrc && \
    echo -e '\n. $HOME/.asdf/asdf.sh' >> ~/.profile && \
    source ~/.bashrc

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

RUN CRYSTAL_PATH=lib:/usr/share/crystal/src/ \
    LLVM_CONFIG=$(/usr/share/crystal/src/llvm/ext/find-llvm-config) \
    PLACE_COMMIT=${PLACE_COMMIT} \
    UNAME_AT_COMPILE_TIME=true \
    shards build --error-trace --ignore-crystal-version --production -Dpreview_mt --release

RUN chown appuser -R /app

###############################################################################

USER appuser:appuser

EXPOSE 3000
HEALTHCHECK CMD wget -qO- http://localhost:3000/api/build/v1
CMD ["/app/scripts/entrypoint.sh", "--server", "-b", "0.0.0.0", "-p", "3000"]
