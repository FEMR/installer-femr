#!/bin/bash

# Configuration
SQL_CONTAINER="docker.io/library/mysql:9.1.0"
FEMR_CONTAINER="teamfemrdev/teamfemr:latest"
DNS_CONTAINER="strm/dnsmasq:latest"
OUTPUT_DIR="$1"

if [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <output_directory>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "Pulling required Docker images..."
docker pull "$SQL_CONTAINER"
docker pull "$FEMR_CONTAINER"
docker pull "$DNS_CONTAINER"

echo "Saving Docker images to archive..."
docker save \
    "$SQL_CONTAINER" \
    "$FEMR_CONTAINER" \
    "$DNS_CONTAINER" \
    -o "$OUTPUT_DIR/femr-images.tar"

echo "Docker images saved to $OUTPUT_DIR/femr-images.tar"