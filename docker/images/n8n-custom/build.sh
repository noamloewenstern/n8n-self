#!/bin/bash
set -eo pipefail

export DOCKER_DEFAULT_PLATFORM=linux/amd64
echo "Building patched n8n image"
docker buildx build -t n8n-patch --platform linux/amd64 -f docker/images/n8n-custom/Dockerfile .
