#!/bin/bash
set -eo pipefail

echo "Building patched n8n image"
docker buildx build -t n8n-patch --platform linux/arm64 -f docker/images/n8n-custom/Dockerfile --build-arg PLATFORM=linux/arm64 .
