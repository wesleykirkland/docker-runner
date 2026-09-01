#!/bin/bash

set -e

# Validate that exactly one of REPO or ORG is set
if [ -n "${REPO}" ] && [ -n "${ORG}" ]; then
    echo "ERROR: Both REPO and ORG are set. Set only one to choose repository-scoped or organization-scoped runner registration."
    exit 1
fi

if [ -z "${REPO}" ] && [ -z "${ORG}" ]; then
    echo "ERROR: Neither REPO nor ORG is set. Set REPO (owner/repo) for a repository runner or ORG (org name) for an organization runner."
    exit 1
fi

if [ -n "${ORG}" ]; then
    SCOPE="org"
    API_BASE="https://api.github.com/orgs/${ORG}/actions/runners"
    CONFIG_URL="https://github.com/${ORG}"
    TARGET_LABEL="organization: ${ORG}"
else
    SCOPE="repo"
    API_BASE="https://api.github.com/repos/${REPO}/actions/runners"
    CONFIG_URL="https://github.com/${REPO}"
    TARGET_LABEL="repository: ${REPO}"
fi

echo "Target ${TARGET_LABEL}"
echo "Fetching registration token..."

# Get registration token from GitHub API
RESPONSE=$(curl -sS -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" "${API_BASE}/registration-token")
echo "API Response: ${RESPONSE}"

REG_TOKEN=$(echo "${RESPONSE}" | jq -r .token)

if [ "${REG_TOKEN}" == "null" ] || [ -z "${REG_TOKEN}" ]; then
    echo "ERROR: Failed to get registration token"
    echo "Response: ${RESPONSE}"
    exit 1
fi

echo "Token retrieved successfully"

cd /home/docker/actions-runner

# Remove existing runner configuration if it exists
if [ -f ".runner" ]; then
    echo "Existing runner configuration found. Removing..."
    # Get removal token
    REMOVE_RESPONSE=$(curl -sS -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" "${API_BASE}/remove-token")
    REMOVE_TOKEN=$(echo "${REMOVE_RESPONSE}" | jq -r .token)

    if [ "${REMOVE_TOKEN}" != "null" ] && [ -n "${REMOVE_TOKEN}" ]; then
        ./config.sh remove --token ${REMOVE_TOKEN}
    else
        echo "Warning: Could not get removal token, forcing cleanup..."
        rm -rf .runner .credentials .credentials_rsaparams
    fi
fi

# Configure the runner
echo "Configuring runner for ${TARGET_LABEL}"

# Build labels argument if RUNNER_LABELS is set
LABELS_ARG=""
if [ -n "${RUNNER_LABELS}" ]; then
    echo "Custom labels: ${RUNNER_LABELS}"
    LABELS_ARG="--labels ${RUNNER_LABELS}"
fi

# Build runner name argument if RUNNER_NAME is set
NAME_ARG=""
if [ -n "${RUNNER_NAME}" ]; then
    echo "Runner name: ${RUNNER_NAME}"
    NAME_ARG="--name ${RUNNER_NAME}"
fi

# Build runner group argument if RUNNER_GROUP is set (organization runners only)
GROUP_ARG=""
if [ "${SCOPE}" == "org" ] && [ -n "${RUNNER_GROUP}" ]; then
    echo "Runner group: ${RUNNER_GROUP}"
    GROUP_ARG="--runnergroup ${RUNNER_GROUP}"
fi

./config.sh --url ${CONFIG_URL} --token ${REG_TOKEN} ${LABELS_ARG} ${NAME_ARG} ${GROUP_ARG}

# Cleanup function to remove runner when container stops
cleanup() {
    echo "Removing runner..."
    # Get removal token
    REMOVE_RESPONSE=$(curl -sS -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" "${API_BASE}/remove-token")
    REMOVE_TOKEN=$(echo "${REMOVE_RESPONSE}" | jq -r .token)

    if [ "${REMOVE_TOKEN}" != "null" ] && [ -n "${REMOVE_TOKEN}" ]; then
        ./config.sh remove --token ${REMOVE_TOKEN}
    fi
}

# Trap SIGINT and SIGTERM signals to cleanup before exit
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

# Start the runner
./run.sh & wait $!
