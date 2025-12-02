#!/bin/bash

# Script to generate MongoDB keyfile for replica set authentication
# This keyfile will be used by all MongoDB instances in the replica set

KEYFILE_PATH="./mongo/keyfile"
MONGO_DIR="./mongo"

echo "Generating MongoDB keyfile..."

# Create the mongo directory structure if it doesn't exist
if [ ! -d "$MONGO_DIR" ]; then
  echo "Creating mongo directory structure..."
  mkdir -p "$MONGO_DIR/node1/data"
  mkdir -p "$MONGO_DIR/node1/configdb"
  mkdir -p "$MONGO_DIR/node2/data"
  mkdir -p "$MONGO_DIR/node2/configdb"
  mkdir -p "$MONGO_DIR/node3/data"
  mkdir -p "$MONGO_DIR/node3/configdb"
  echo "Directory structure created successfully"
fi

# Create the keyfile with random content (512 bytes)
openssl rand -base64 756 > "$KEYFILE_PATH"

# Set correct permissions (MongoDB requires 400 or 600)
chmod 400 "$KEYFILE_PATH"

echo "Keyfile generated successfully at: $KEYFILE_PATH"
echo "Permissions set to 400 (read-only for owner)"
echo ""
echo "IMPORTANT: Ensure the keyfile has UID 999 (mongodb user) in the container"
echo "You may need to run: sudo chown 999:999 $KEYFILE_PATH"

