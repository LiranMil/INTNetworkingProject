#!/bin/bash

# Check if a private instance IP is provided
if [ -z "$1" ]; then
    echo "Please provide the private instance IP."
    exit 1
fi

PRIVATE_INSTANCE_IP="$1"
NEW_KEY_NAME="id_rsa"
NEW_KEY_PATH="$HOME/.ssh/$NEW_KEY_NAME"
OLD_KEY_PATH="$NEW_KEY_PATH.old"
OLD_KEY_PATH_PUB="$HOME/.ssh/$NEW_KEY_NAME.pub.old"

# Backup the existing SSH key
if [ -f "$NEW_KEY_PATH" ]; then
    mv "$NEW_KEY_PATH" "$OLD_KEY_PATH"
    echo "Renamed old private key to $OLD_KEY_PATH"
else
    echo "No existing private key found."
fi

if [ -f "$NEW_KEY_PATH_PUB" ]; then
    mv "$NEW_KEY_PATH_PUB" "$OLD_KEY_PATH_PUB"
    echo "Renamed old public key to $OLD_KEY_PATH_PUB"
else
    echo "No existing public key found."
fi

# Generate a new SSH key
if ! ssh-keygen -t rsa -b 2048 -f "$NEW_KEY_PATH" -N ""; then
    echo "Failed to generate SSH key."
    exit 1
fi

# Set permissions for the new private key
if ! sudo chmod 400 "$NEW_KEY_PATH"; then
    echo "Failed to set permissions on the new key."
    exit 1
fi

# Copy the new public key to the private instance
if ! ssh -i "$OLD_KEY_PATH" "ubuntu@$PRIVATE_INSTANCE_IP" "cat > ~/.ssh/authorized_keys" < "$NEW_KEY_PATH.pub"; then
    echo "Failed to copy the new key to the private instance."
    exit 1
fi

# Test the SSH connection with the new key
echo "Testing SSH connection with the new key..."
if ! ssh -i "$NEW_KEY_PATH" "ubuntu@$PRIVATE_INSTANCE_IP" -o StrictHostKeyChecking=no "echo 'Connection successful with new key'"; then
    echo "Failed to connect with the new key."
    exit 1
fi

# Cleanup old key files
echo "Key rotation successful. You can now use the new key to access the private instance."
rm -f "$OLD_KEY_PATH" "$OLD_KEY_PATH_PUB"
