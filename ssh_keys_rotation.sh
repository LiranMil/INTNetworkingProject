#!/bin/bash

set -e

# Ensure correct usage
if [ $# -ne 1 ]; then
  echo "Usage: $0 <private-instance-ip>"
  exit 1
fi

# Variables
PRIVATE_IP=$1
NEW_KEY_PATH="$HOME/.ssh/id_rsa_new"
PUBLIC_KEY_PATH="$NEW_KEY_PATH.pub"
OLD_KEY_PATH="$HOME/.ssh/id_rsa"
AUTHORIZED_KEYS="$HOME/.ssh/authorized_keys"

# Generate a new SSH key pair
echo "Generating new SSH key pair..."
if [ -f "$NEW_KEY_PATH" ] || [ -f "$PUBLIC_KEY_PATH" ]; then
  echo "Removing existing key files before generating new keys."
  rm -f "$NEW_KEY_PATH" "$PUBLIC_KEY_PATH"
fi

ssh-keygen -t rsa -b 4096 -f "$NEW_KEY_PATH" -N ""
chmod 600 "$NEW_KEY_PATH"

# Check if the new key files were created
if [ ! -f "$NEW_KEY_PATH" ] || [ ! -f "$PUBLIC_KEY_PATH" ]; then
  echo "Failed to generate new SSH key pair."
  exit 1
fi

echo "New SSH key pair generated successfully."

# Read the new public key
NEW_PUBLIC_KEY=$(cat "$PUBLIC_KEY_PATH" 2>/dev/null)
if [ -z "$NEW_PUBLIC_KEY" ]; then
  echo "Failed to read new public key from $PUBLIC_KEY_PATH."
  exit 1
fi

# Add the new public key to authorized_keys on the private instance
echo "Adding new public key to authorized_keys on the private instance..."
ssh -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_IP" "echo '$NEW_PUBLIC_KEY' >> ~/.ssh/authorized_keys"
if [ $? -ne 0 ]; then
  echo "Failed to add new public key to authorized_keys."
  exit 1
fi

# Verify the new key works
echo "Verifying new key works..."
ssh -i "$NEW_KEY_PATH" ubuntu@"$PRIVATE_IP" 'exit'
if [ $? -ne 0 ]; then
  echo "Failed to connect to the private instance using the new key."
  exit 1
fi

# Remove the old key from authorized_keys on the private instance
OLD_PUBLIC_KEY=$(cat "$OLD_KEY_PATH.pub" 2>/dev/null)
if [ -z "$OLD_PUBLIC_KEY" ]; then
  echo "Failed to read old public key from $OLD_KEY_PATH.pub."
  exit 1
fi

ESCAPED_OLD_KEY=$(echo "$OLD_PUBLIC_KEY" | sed 's/[\/&]/\\&/g')
echo "Removing old public key from authorized_keys on the private instance..."
ssh -i "$NEW_KEY_PATH" ubuntu@"$PRIVATE_IP" "sed -i '/$ESCAPED_OLD_KEY/d' ~/.ssh/authorized_keys"
if [ $? -ne 0 ]; then
  echo "Failed to remove old public key from authorized_keys."
  exit 1
fi

# Verify the old key no longer works
echo "Verifying old key no longer works..."
ssh -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_IP" 'exit'
if [ $? -eq 0 ]; then
  echo "Old key is still valid, which shouldn't be the case."
  exit 1
fi

# Remove old key files
echo "Removing old key files..."
rm -f "$OLD_KEY_PATH" "$OLD_KEY_PATH.pub"

# Replace the old key with the new key locally
echo "Replacing old key with new key locally..."
mv "$NEW_KEY_PATH" "$HOME/.ssh/id_rsa"
mv "$PUBLIC_KEY_PATH" "$HOME/.ssh/id_rsa.pub"
chmod 600 "$HOME/.ssh/id_rsa"
chmod 644 "$HOME/.ssh/id_rsa.pub"

echo "SSH key rotation completed successfully."

