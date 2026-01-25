FROM ubuntu:20.04

ARG RUNNER_VERSION="2.331.0"
ARG TARGETPLATFORM
ARG TARGETARCH

# Prevents installdependencies.sh from prompting the user and blocking the image creation
ARG DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt upgrade -y && useradd -m docker

# Install common dependencies for GitHub Actions workflows and deployments
# Includes: git, curl, wget, jq, build tools, Python, Node.js, archive tools
RUN apt install -y --no-install-recommends \
    curl wget jq git unzip zip tar gzip \
    build-essential make cmake \
    libssl-dev ca-certificates \
    python3 python3-pip python3-venv python3-dev libffi-dev \
    nodejs npm \
    git-lfs \
    bzip2 xz-utils

# Download the appropriate runner based on architecture
RUN cd /home/docker && mkdir actions-runner && cd actions-runner \
    && if [ "$TARGETARCH" = "arm64" ]; then \
         RUNNER_ARCH="arm64"; \
       else \
         RUNNER_ARCH="x64"; \
       fi \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && rm ./actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz

RUN chown -R docker ~docker && /home/docker/actions-runner/bin/installdependencies.sh

# Copy start.sh script and make it executable (as root before switching users)
COPY start.sh /home/docker/start.sh
RUN chmod +x /home/docker/start.sh && chown docker:docker /home/docker/start.sh

# Since the config and run script for actions are not allowed to be run by root,
# set the user to "docker" so all subsequent commands are run as the docker user
USER docker

WORKDIR /home/docker

ENTRYPOINT ["./start.sh"]
