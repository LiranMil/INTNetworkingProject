#!/bin/bash

# Check if the private instance IP is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <private-instance-ip>"
    exit 1
fi

PRIVATE_IP="$1"

# Define paths
PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"
PUBLIC_KEY_PATH="$PRIVATE_KEY_PATH.pub"
OLD_PRIVATE_KEY_PATH="$PRIVATE_KEY_PATH.old"
OLD_KEY_PATH_PUB="$PUBLIC_KEY_PATH.old"

# Move old key to a backup location
if [ -f "$PRIVATE_KEY_PATH" ]; then
    mv "$PRIVATE_KEY_PATH" "$OLD_PRIVATE_KEY_PATH"
else
    echo "Old private key not found at $PRIVATE_KEY_PATH"
    exit 1
fi

if [ -f "$PUBLIC_KEY_PATH" ]; then
    mv "$PUBLIC_KEY_PATH" "$OLD_KEY_PATH_PUB"
else
    echo "Old public key not found at $PUBLIC_KEY_PATH"
    exit 1
fi

# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY_PATH" -N "" -C "Key rotated on $(date)" > /dev/null
chmod 400 "$PRIVATE_KEY_PATH"

# Ensure the new public key file exists
if [ ! -f "$PUBLIC_KEY_PATH" ]; then
    echo "Failed to generate new public key at $PUBLIC_KEY_PATH"
    exit 1
fi

# Copy the new public key to the private instance
if ! ssh -i "$OLD_PRIVATE_KEY_PATH" ubuntu@"$PRIVATE_IP" "cat > ~/.ssh/authorized_keys" < "$PUBLIC_KEY_PATH"; then
    echo "Failed to copy public key to the private machine"
    exit 1
fi

# Test SSH connection with the new key
echo "Testing SSH connection with the new key..."
if ssh -o StrictHostKeyChecking=no -i "$PRIVATE_KEY_PATH" ubuntu@"$PRIVATE_IP" "exit"; then
    echo "SSH connection successful with the new key."
else
    echo "SSH connection failed with the new key."
    exit 1
fi

echo "Key rotation completed successfully."
