# GitHub Actions Self-Hosted Runner (Containerized)

This repository contains a containerized GitHub Actions self-hosted runner that can be deployed on any Docker-compatible host. Multiple runners can be launched on a single server to handle parallel job execution across your entire organization.

This takes a PAT scoped to `repo:*` and auto adds runners to specific repos. Organization wide runners are untested. It will automatically pull the latest runner code.

## Features

- **Ubuntu 20.04 base** - Stable and well-supported
- **Multi-platform support** - Works on both AMD64 (x86_64) and ARM64 (Apple Silicon, ARM servers)
- **Organization-wide runners** - Runners available to all repositories in your organization
- **Automatic registration** - Runners self-register with your GitHub organization
- **Graceful cleanup** - Runners automatically deregister when stopped
- **Scalable** - Run multiple instances on a single host
- **Monthly security updates** - Automated builds ensure latest security patches

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
  -e ORG="wesleykirkland" \
  -e ACCESS_TOKEN="your_github_token_here" \
  ghcr.io/wesleykirkland/docker-runner:latest
```

Replace:

- `wesleykirkland` with your GitHub organization name
- `your_github_token_here` with your GitHub Personal Access Token (with `admin:org` scope)

### 4. Run Multiple Runners

You can run multiple runners on the same host for parallel job execution across your organization:

```bash
# Runner 1
docker run -d --name github-runner-1 \
  -e ORG="wesleykirkland" \
  -e ACCESS_TOKEN="your_token" \
  ghcr.io/wesleykirkland/docker-runner:latest

# Runner 2
docker run -d --name github-runner-2 \
  -e ORG="wesleykirkland" \
  -e ACCESS_TOKEN="your_token" \
  ghcr.io/wesleykirkland/docker-runner:latest

# Runner 3
docker run -d --name github-runner-3 \
  -e ORG="wesleykirkland" \
  -e ACCESS_TOKEN="your_token" \
  ghcr.io/wesleykirkland/docker-runner:latest
```

## Using Docker Compose

Create a `compose.yml` file:

```yaml
version: '3.8'

services:
  runner:
    image: ghcr.io/wesleykirkland/docker-runner:latest
    environment:
      - ORG=wesleykirkland
      - ACCESS_TOKEN=your_github_token_here
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
```

Then run:

```bash
docker compose up -d
```

Or scale to a specific number:

```bash
docker compose up -d --scale runner=4
```

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
