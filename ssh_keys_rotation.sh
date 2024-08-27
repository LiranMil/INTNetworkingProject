#!/bin/bash
set -e

# Ensure correct usage
if [ $# -ne 1 ]; then
  echo "Usage: $0 <private-instance-ip>"
  exit 1
fi

# Variables
PRIVATE_IP=$1
NEW_KEY_NAME="id_rsa"
NEW_KEY_PATH="$HOME/.ssh/$NEW_KEY_NAME"
OLD_KEY_PATH="$NEW_KEY_PATH"
OLD_KEY_PATH_PUB="$OLD_KEY_PATH.pub"

# Backup the old key
mv "$OLD_KEY_PATH" "$OLD_KEY_PATH".old
mv "$OLD_KEY_PATH_PUB" "$OLD_KEY_PATH_PUB".old
OLD_KEY_PATH="$OLD_KEY_PATH".old
OLD_KEY_PATH_PUB="$OLD_KEY_PATH_PUB".old

# Generate a new SSH key pair
if ! ssh-keygen -t rsa -b 2048 -f "$NEW_KEY_PATH" -N ""; then
   echo "Failed to generate SSH key"
   exit 1
fi

# Set permissions on the new key
if ! chmod 600 "$NEW_KEY_PATH"; then
   echo "Failed to set permissions on the new key"
   exit 1
fi

# Copy the new public key to the authorized_keys on the private instance
if ! ssh -i "$OLD_KEY_PATH" "ubuntu@$PRIVATE_IP" "cat > ~/.ssh/authorized_keys" < "$NEW_KEY_PATH.pub"; then
   echo "Failed to copy new key to the private instance"
   exit 1
fi

# Verify the new key works
if ! ssh -i "$NEW_KEY_PATH" ubuntu@$PRIVATE_IP -o StrictHostKeyChecking=no "echo 'Connection successful with new key'"; then
    echo "Failed to connect to the private instance using the new key"
    exit 1
fi

# Remove the old key locally and on the remote instance
rm -f "$OLD_KEY_PATH" "$OLD_KEY_PATH_PUB"

echo echo "SSH key rotation completed successfully."