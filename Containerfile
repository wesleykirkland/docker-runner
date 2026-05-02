FROM ubuntu:26.04

ARG TARGETPLATFORM
ARG TARGETARCH

# Prevents installdependencies.sh from prompting the user and blocking the image creation
ARG DEBIAN_FRONTEND=noninteractive

ENV MISE_DATA_DIR=/opt/mise \
    MISE_CONFIG_DIR=/etc/mise \
    MISE_CACHE_DIR=/var/cache/mise \
    MISE_INSTALL_PATH=/usr/local/bin/mise \
    PATH="/opt/mise/shims:/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"

RUN apt-get update -y && apt-get upgrade -y && useradd -m docker

# Install OS-level dependencies for the runner and mise-managed tools.
RUN apt-get install -y --no-install-recommends \
    ca-certificates curl wget git gnupg unzip zip tar gzip \
    build-essential make cmake \
    libssl-dev libffi-dev \
    git-lfs \
    bzip2 xz-utils \
    openssh-client \
    rsync

RUN curl -fsSL https://mise.run | sh

COPY mise.toml /etc/mise/config.toml
RUN mise -y install \
    && mise doctor \
    && mise reshim

# Download the appropriate runner based on architecture (latest version)
RUN cd /home/docker && mkdir actions-runner && cd actions-runner \
    && if [ "$TARGETARCH" = "arm64" ]; then \
         RUNNER_ARCH="arm64"; \
       else \
         RUNNER_ARCH="x64"; \
       fi \
    && RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r .tag_name | sed 's/^v//') \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && rm ./actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz

RUN chown -R docker ~docker /opt/mise /var/cache/mise && /home/docker/actions-runner/bin/installdependencies.sh

# Copy start.sh script and make it executable (as root before switching users)
COPY start.sh /home/docker/start.sh
RUN chmod +x /home/docker/start.sh && chown docker:docker /home/docker/start.sh

# Since the config and run script for actions are not allowed to be run by root,
# set the user to "docker" so all subsequent commands are run as the docker user
USER docker

WORKDIR /home/docker

ENTRYPOINT ["./start.sh"]
