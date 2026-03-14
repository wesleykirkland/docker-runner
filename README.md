# GitHub Actions Self-Hosted Runner (Containerized)

This repository contains a containerized GitHub Actions self-hosted runner that can be deployed on any Docker-compatible host. Multiple runners can be launched on a single server to handle parallel job execution across your entire organization.

This takes a PAT scoped to `repo:*` and auto adds runners to specific repos. Organization wide runners are untested. It will automatically pull the latest runner code.

## Features

- **Ubuntu 20.04 base** - Stable and well-supported
- **Multi-platform support** - Works on both AMD64 (x86_64) and ARM64 (Apple Silicon, ARM servers)
- **Organization-wide runners** - Runners available to all repositories in your organization
- **Automatic registration** - Runners self-register with your GitHub organization
- **Custom labels** - Add custom labels to selectively run workflows on specific runners
- **Graceful cleanup** - Runners automatically deregister when stopped
- **Scalable** - Run multiple instances on a single host
- **Monthly security updates** - Automated builds ensure latest security patches
- **Latest tools** - Always installs the latest GitHub Actions runner, SOPS, and AWS CLI

## Prerequisites

- Docker or Podman installed on your host
- GitHub Personal Access Token with `repo:*` scope
- GitHub organization where you want to add self-hosted runners

## Quick Start

### 1. Create a GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a name (e.g., "Organization runner token")
4. Select the `admin:org` scope (full control of organizations and teams)
5. Click "Generate token" and copy the token

### 2. Pull the Image

```bash
docker pull ghcr.io/wesleykirkland/docker-runner:latest
```

### 3. Run a Single Runner

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
| `REPO` | Yes | GitHub repository (format: username/repo) | `wesleykirkland/docker-runner` |
| `ACCESS_TOKEN` | Yes | GitHub Personal Access Token with `repo` scope | `ghp_xxxxxxxxxxxx` |
| `RUNNER_LABELS` | No | Comma-separated custom labels for selective task execution | `deploy,production,linux` |
| `RUNNER_NAME` | No | Custom runner name (auto-generated if not set) | `my-production-runner` |

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

1. Go to your GitHub organization page
2. Navigate to Settings → Actions → Runners
3. You should see your self-hosted runners listed as "Idle" or "Active"
4. These runners will be available to all repositories in your organization

## Building from Source

```bash
# Clone the repository
git clone https://github.com/wesleykirkland/docker-runner.git
cd docker-runner

# Build the image (automatically detects your platform)
docker build -t github-runner:local .

# Or build for a specific platform
docker build --platform linux/amd64 -t github-runner:local .
docker build --platform linux/arm64 -t github-runner:local .

# Run it
docker run -d \
  -e ORG="your-organization" \
  -e ACCESS_TOKEN="your_token" \
  github-runner:local
```

## Troubleshooting

### Runners not appearing in GitHub

- Verify your `ACCESS_TOKEN` has the correct `admin:org` scope
- Check that `ORG` is your GitHub organization name
- View container logs: `docker logs github-runner-1`
- Ensure you have admin permissions on the organization

### Zombie runners (offline but still listed)

If runners weren't stopped gracefully (e.g., server crash), they may appear as offline in GitHub. Remove them manually:

1. Go to Settings → Actions → Runners
2. Click on the offline runner
3. Click "Remove"

## Security Considerations

- **Token security**: Store your GitHub token securely (use Docker secrets or environment files)
- **Token scope**: Use `admin:org` scope for organization-wide runners
- **Network isolation**: Consider running runners in an isolated network
- **Regular updates**: The image is rebuilt monthly to include security patches
- **Least privilege**: The runner runs as a non-root user (`docker`)
- **Organization access**: Runners have access to all repositories in your organization

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
