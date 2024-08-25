#!/bin/bash

# Check if the private instance IP is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <private-instance-ip>"
    exit 1
fi

PRIVATE_IP="$1"
#cp "$HOME/key.pem" "$HOME/.ssh/id_rsa_old"


PRIVATE_KEY_PATH="$HOME/.ssh/id_rsa"   # Path to store the new key
PUBLIC_KEY_PATH="$PRIVATE_KEY_PATH".pub

OLD_PRIVATE_KEY_PATH="$PRIVATE_KEY_PATH".old  # Path to your old key
mv "$PRIVATE_KEY_PATH" "$OLD_PRIVATE_KEY_PATH"

OLD_KEY_PATH_PUB="$PUBLIC_KEY_PATH".old
mv "$PUBLIC_KEY_PATH" "$OLD_KEY_PATH_PUB"

# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY_PATH" -N ""  -C "Key rotated on $(date)" > /dev/null
chmod 400 "$PRIVATE_KEY_PATH"

# Ensure the old key exists before using it
#if [ ! -f "$OLD_KEY_PATH" ]; then
#    echo "Old key not found at $OLD_KEY_PATH"
#    exit 1
#fi

if ! ssh -i "$OLD_PRIVATE_KEY_PATH" ubuntu@"$PRIVATE_IP" "cat > ~/.ssh/authorized_keys" < "$PUBLIC_KEY_PATH"; then
  echo "Failed to copy public key to the private machine"
  exit 1
fi


# Test SSH connection with the new key
echo "connect"
ssh -o StrictHostKeyChecking=no -i "$NEW_KEY_PATH" ubuntu@"$PRIVATE_IP"