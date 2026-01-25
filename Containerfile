FROM ubuntu:20.04

ARG TARGETPLATFORM
ARG TARGETARCH

# Prevents installdependencies.sh from prompting the user and blocking the image creation
ARG DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt upgrade -y && useradd -m docker

# Install common dependencies for GitHub Actions workflows and deployments
# Includes: git, curl, wget, jq, build tools, Python, Node.js, archive tools, SSH, rsync
RUN apt install -y --no-install-recommends \
    curl wget jq git unzip zip tar gzip \
    build-essential make cmake \
    libssl-dev ca-certificates \
    python3 python3-pip python3-venv python3-dev libffi-dev \
    nodejs npm \
    git-lfs \
    bzip2 xz-utils \
    openssh-client \
    rsync

# Install Mozilla SOPS from GitHub releases (latest version)
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      SOPS_ARCH="arm64"; \
    else \
      SOPS_ARCH="amd64"; \
    fi \
    && SOPS_VERSION=$(curl -s https://api.github.com/repos/getsops/sops/releases/latest | jq -r .tag_name | sed 's/^v//') \
    && curl -L -o /usr/local/bin/sops https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${SOPS_ARCH} \
    && chmod +x /usr/local/bin/sops

# Install AWS CLI v2
RUN if [ "$TARGETARCH" = "arm64" ]; then \
      AWS_ARCH="aarch64"; \
    else \
      AWS_ARCH="x86_64"; \
    fi \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

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

RUN chown -R docker ~docker && /home/docker/actions-runner/bin/installdependencies.sh

# Copy start.sh script and make it executable (as root before switching users)
COPY start.sh /home/docker/start.sh
RUN chmod +x /home/docker/start.sh && chown docker:docker /home/docker/start.sh

# Since the config and run script for actions are not allowed to be run by root,
# set the user to "docker" so all subsequent commands are run as the docker user
USER docker

WORKDIR /home/docker

ENTRYPOINT ["./start.sh"]
