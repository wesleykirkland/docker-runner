# GitHub Actions Self-Hosted Runner (Containerized)

This repository contains a containerized GitHub Actions self-hosted runner that can be deployed on any Docker-compatible host. Multiple runners can be launched on a single server to handle parallel job execution for a repository.

It takes a GitHub PAT and auto-registers runners with either a specific repository or an entire organization, depending on whether you set `REPO` or `ORG`. It will automatically pull the latest runner code.

## Features

- **Ubuntu 26.04 base** - Current LTS base with security updates
- **Multi-platform support** - Works on both AMD64 (x86_64) and ARM64 (Apple Silicon, ARM servers)
- **Repository runners** - Runners register directly with the repository you provide
- **Organization runners** - Runners register at the organization level and can be assigned to a runner group
- **Automatic registration** - Runners self-register with your GitHub repository or organization
- **Custom labels** - Add custom labels to selectively run workflows on specific runners
- **Graceful cleanup** - Runners automatically deregister when stopped
- **Scalable** - Run multiple instances on a single host
- **Monthly security updates** - Automated builds ensure latest security patches
- **mise-managed tools** - Installs AWS CLI, SOPS, jq, Node.js, Python, and Ruby through mise-en-place

## Prerequisites

- Docker or Podman installed on your host
- A GitHub Personal Access Token:
  - `repo` scope for repository runners
  - `admin:org` scope for organization runners
- A GitHub repository (`REPO`) or organization (`ORG`) where you want to add self-hosted runners — pick one, they're mutually exclusive per runner instance

## Quick Start

### 1. Create a GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name (e.g., "Repository runner token")
4. Select the `repo` scope for a repository runner, or `admin:org` for an organization runner
5. Click "Generate token" and copy the token

### 2. Pull the Image

```bash
docker pull ghcr.io/wesleykirkland/docker-runner:latest
```

### 3. Run a Single Repository Runner

```bash
docker run -d \
  --name github-runner-1 \
  -e REPO="wesleykirkland/docker-runner" \
  -e ACCESS_TOKEN="your_github_token_here" \
  ghcr.io/wesleykirkland/docker-runner:latest
```

Replace:

- `wesleykirkland/docker-runner` with your GitHub repository (format: username/repo)
- `your_github_token_here` with your GitHub Personal Access Token (with `repo` scope)

### 3b. Run a Single Organization Runner

To register a runner at the organization level instead of a single repository, set `ORG` instead of `REPO`:

```bash
docker run -d \
  --name github-runner-org-1 \
  -e ORG="your-organization" \
  -e ACCESS_TOKEN="your_github_token_here" \
  ghcr.io/wesleykirkland/docker-runner:latest
```

Replace:

- `your-organization` with your GitHub organization name
- `your_github_token_here` with your GitHub Personal Access Token (with `admin:org` scope)

Organization runners can optionally be assigned to a runner group with `RUNNER_GROUP` (see [Environment Variables](#environment-variables)). `REPO` and `ORG` are mutually exclusive — setting both, or neither, causes the container to exit with an error at startup.

### 4. Run with Custom Labels

You can add custom labels to selectively run workflows on specific runners:

```bash
docker run -d \
  --name github-runner-deploy \
  -e REPO="wesleykirkland/docker-runner" \
  -e ACCESS_TOKEN="your_token" \
  -e RUNNER_LABELS="deploy,production,linux" \
  ghcr.io/wesleykirkland/docker-runner:latest
```

Then in your GitHub Actions workflow:

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, deploy, production]
    steps:
      - name: Deploy to production
        run: ./scripts/deploy.sh
```

### 5. Run Multiple Runners

You can run multiple runners on the same host for parallel job execution:

```bash
# General purpose runner
docker run -d --name github-runner-1 \
  -e REPO="wesleykirkland/docker-runner" \
  -e ACCESS_TOKEN="your_token" \
  ghcr.io/wesleykirkland/docker-runner:latest

# Deployment runner
docker run -d --name github-runner-deploy \
  -e REPO="wesleykirkland/docker-runner" \
  -e ACCESS_TOKEN="your_token" \
  -e RUNNER_LABELS="deploy,production" \
  ghcr.io/wesleykirkland/docker-runner:latest

# Build runner
docker run -d --name github-runner-build \
  -e REPO="wesleykirkland/docker-runner" \
  -e ACCESS_TOKEN="your_token" \
  -e RUNNER_LABELS="build,docker" \
  ghcr.io/wesleykirkland/docker-runner:latest
```

## Using Docker Compose

Create a `compose.yml` file:

```yaml
services:
  runner:
    image: ghcr.io/wesleykirkland/docker-runner:latest
    environment:
      - REPO=wesleykirkland/docker-runner
      - ACCESS_TOKEN=your_github_token_here
      # Optional: Add custom labels
      - RUNNER_LABELS=docker,linux
    deploy:
      mode: replicated
      replicas: 4
      resources:
        limits:
          cpus: '0.35'
          memory: 300M
        reservations:
          cpus: '0.25'
          memory: 128M

  # Example: Dedicated deployment runners
  runner-deploy:
    image: ghcr.io/wesleykirkland/docker-runner:latest
    environment:
      - REPO=wesleykirkland/docker-runner
      - ACCESS_TOKEN=your_github_token_here
      - RUNNER_LABELS=deploy,production
    deploy:
      replicas: 2

  # Example: Organization-wide runners (requires admin:org token scope)
  runner-org:
    image: ghcr.io/wesleykirkland/docker-runner:latest
    environment:
      - ORG=your-organization
      - ACCESS_TOKEN=your_github_token_here
      - RUNNER_LABELS=docker,linux
      # - RUNNER_GROUP=default
    deploy:
      replicas: 2
```

Then run:

```bash
docker compose up -d
```

Or scale to a specific number:

```bash
docker compose up -d --scale runner=4
```

## Environment Variables

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `REPO` | One of `REPO`/`ORG` | GitHub repository for a repository-scoped runner (format: username/repo). Mutually exclusive with `ORG`. | `wesleykirkland/docker-runner` |
| `ORG` | One of `REPO`/`ORG` | GitHub organization for an organization-scoped runner. Mutually exclusive with `REPO`. | `wesleykirkland` |
| `ACCESS_TOKEN` | Yes | GitHub Personal Access Token — `repo` scope for `REPO`, `admin:org` scope for `ORG` | `ghp_xxxxxxxxxxxx` |
| `RUNNER_LABELS` | No | Comma-separated custom labels for selective task execution | `deploy,production,linux` |
| `RUNNER_NAME` | No | Custom runner name (auto-generated if not set) | `my-production-runner` |
| `RUNNER_GROUP` | No | Runner group to assign the runner to (organization runners only, ignored for `REPO`) | `default` |

## Resource Limits

It's important to set resource limits to prevent runners from consuming all host resources. Adjust based on your server capacity:

- **Minimum per runner**: 128MB RAM, 0.25 CPU
- **Recommended per runner**: 256MB RAM, 0.5 CPU
- **For a 2GB RAM / 2 vCPU server**: Run 4-6 runners with limits shown above

## Stopping Runners

Runners will automatically deregister when stopped gracefully:

```bash
# Stop a single runner
docker stop github-runner-1

# Stop all runners
docker compose down
```

**Important**: Use `docker stop` (SIGTERM) instead of `docker kill` (SIGKILL) to allow proper cleanup.

## Verifying Runners

Check that your runners are registered:

1. Go to your GitHub repository (for `REPO`) or organization (for `ORG`) page
2. Navigate to Settings → Actions → Runners
3. You should see your self-hosted runners listed as "Idle" or "Active"
4. Repository runners are available only to the configured repository; organization runners are available to any repository in the organization permitted to use the assigned runner group

## Building from Source

```bash
# Clone the repository
git clone https://github.com/wesleykirkland/docker-runner.git
cd docker-runner

# Build the image (automatically detects your platform)
docker build -f Containerfile -t github-runner:local .

# Or build for a specific platform
docker build -f Containerfile --platform linux/amd64 -t github-runner:local .
docker build -f Containerfile --platform linux/arm64 -t github-runner:local .

# Run it
docker run -d \
  -e REPO="your-organization/your-repository" \
  -e ACCESS_TOKEN="your_token" \
  github-runner:local

# Or as an organization runner
docker run -d \
  -e ORG="your-organization" \
  -e ACCESS_TOKEN="your_token" \
  github-runner:local
```

## Toolchain

The image uses [mise-en-place](https://mise.jdx.dev/) for versioned CLI and runtime tools. Tool versions are declared in `mise.toml` and installed into `/opt/mise`; `/opt/mise/shims` is added to `PATH` so workflows can call tools normally.

Currently managed by mise:

- AWS CLI
- SOPS
- jq
- Node.js
- Python
- Ruby

APT is still used for Ubuntu system dependencies, build libraries, Git, SSH, archive tools, and the GitHub Actions runner dependency installer.

## Troubleshooting

### Runners not appearing in GitHub

- Verify your `ACCESS_TOKEN` has the correct scope: `repo` for repository runners, `admin:org` for organization runners
- Check that `REPO` is set to `owner/repository`, or `ORG` is set to your organization name (not both)
- View container logs: `docker logs github-runner-1`
- Ensure you have admin permissions on the repository, or owner/admin permissions on the organization

### Container exits immediately with a REPO/ORG error

- The container validates that exactly one of `REPO` or `ORG` is set and will exit at startup if both or neither are provided. Check your environment variables.

### Zombie runners (offline but still listed)

If runners weren't stopped gracefully (e.g., server crash), they may appear as offline in GitHub. Remove them manually:

1. Go to Settings → Actions → Runners
2. Click on the offline runner
3. Click "Remove"

## Security Considerations

- **Token security**: Store your GitHub token securely (use Docker secrets or environment files)
- **Token scope**: Use the `repo` scope for repository runners; `admin:org` is required for organization runners and is a much broader grant, so scope those tokens and hosts accordingly
- **Network isolation**: Consider running runners in an isolated network
- **Regular updates**: The image is rebuilt monthly to include security patches
- **Least privilege**: The runner runs as a non-root user (`docker`)
- **Access scope**: Repository runners only have access to the configured repository; organization runners are reachable by any repository in the org permitted to use their runner group, so prefer a dedicated runner group scoped to trusted repositories

## Automated Builds

This image is automatically built and published monthly to ensure security patches are included. Builds are triggered:

- On the 1st of every month (scheduled)
- On every push to `main` branch
- On every tagged release

Container Image: `ghcr.io/wesleykirkland/docker-runner`

## License

MIT License - See [LICENSE](LICENSE) file for details

## Credits

Based on the excellent tutorial by Alessandro Baccini: [How to containerize a GitHub Actions self-hosted runner](https://baccini-al.medium.com/how-to-containerize-a-github-actions-self-hosted-runner-5994cc08b9fb)
