#!/bin/bash

set -e

echo "Repository: ${REPO}"
echo "Fetching registration token..."

# Get registration token from GitHub API (repository-specific)
RESPONSE=$(curl -sS -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/repos/${REPO}/actions/runners/registration-token)
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
    REMOVE_RESPONSE=$(curl -sS -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/repos/${REPO}/actions/runners/remove-token)
    REMOVE_TOKEN=$(echo "${REMOVE_RESPONSE}" | jq -r .token)

    if [ "${REMOVE_TOKEN}" != "null" ] && [ -n "${REMOVE_TOKEN}" ]; then
        ./config.sh remove --token ${REMOVE_TOKEN}
    else
        echo "Warning: Could not get removal token, forcing cleanup..."
        rm -rf .runner .credentials .credentials_rsaparams
    fi
fi

# Configure the runner for the repository
echo "Configuring runner for repository: ${REPO}"

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

./config.sh --url https://github.com/${REPO} --token ${REG_TOKEN} ${LABELS_ARG} ${NAME_ARG}

# Cleanup function to remove runner when container stops
cleanup() {
    echo "Removing runner..."
    # Get removal token
    REMOVE_RESPONSE=$(curl -sS -X POST -H "Authorization: token ${ACCESS_TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/repos/${REPO}/actions/runners/remove-token)
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

