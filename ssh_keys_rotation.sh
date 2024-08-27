#!/bin/bash
set -e

# Ensure correct usage
if [ $# -ne 1 ]; then
  echo "Usage: $0 <private-instance-ip>"
  exit 1
fi

PRIVATE_IP=$1
NEW_KEY_PATH="$HOME/.ssh/id_rsa_new"
PUBLIC_KEY_PATH="$NEW_KEY_PATH.pub"
OLD_KEY_PATH="$HOME/.ssh/id_rsa"
OLD_PUBLIC_KEY_PATH="$HOME/.ssh/id_rsa.pub"
BACKUP_KEY_PATH="$HOME/.ssh/id_rsa_backup"
BACKUP_PUBLIC_KEY_PATH="$HOME/.ssh/id_rsa_backup.pub"

# Backup existing SSH key
echo "Backing up old SSH key..."
if [ -f "$OLD_KEY_PATH" ]; then
  cp "$OLD_KEY_PATH" "$BACKUP_KEY_PATH"
  cp "$OLD_PUBLIC_KEY_PATH" "$BACKUP_PUBLIC_KEY_PATH"
else
  echo "No existing SSH key found. Skipping backup."
fi

# Generate a new SSH key pair
echo "Generating new SSH key pair..."
ssh-keygen -t rsa -b 2048 -f "$NEW_KEY_PATH" -N ""
chmod 600 "$NEW_KEY_PATH"

# Copy the new public key to the authorized_keys on the private instance
echo "Copying the new public key to the private instance..."
NEW_PUBLIC_KEY=$(cat "$PUBLIC_KEY_PATH")
if ! ssh -i "$OLD_KEY_PATH" ubuntu@$PRIVATE_IP "echo '$NEW_PUBLIC_KEY' >> ~/.ssh/authorized_keys"; then
  echo "Failed to copy the new public key to the private instance. Restoring backup..."
  if [ -f "$BACKUP_KEY_PATH" ]; then
    cp "$BACKUP_KEY_PATH" "$OLD_KEY_PATH"
    cp "$BACKUP_PUBLIC_KEY_PATH" "$OLD_PUBLIC_KEY_PATH"
  fi
  exit 1
fi

# Verify that the new key works
echo "Testing new SSH key..."
if ssh -i "$NEW_KEY_PATH" ubuntu@$PRIVATE_IP 'exit'; then
  echo "New key is working."
else
  echo "Failed to connect to the private instance using the new key. Restoring backup..."
  if [ -f "$BACKUP_KEY_PATH" ]; then
    cp "$BACKUP_KEY_PATH" "$OLD_KEY_PATH"
    cp "$BACKUP_PUBLIC_KEY_PATH" "$OLD_PUBLIC_KEY_PATH"
  fi
  exit 1
fi

# Remove the old public key from the authorized_keys on the private instance
echo "Removing old public key from the private instance..."
OLD_PUBLIC_KEY=$(cat "$OLD_PUBLIC_KEY_PATH")
if ! ssh -i "$NEW_KEY_PATH" ubuntu@$PRIVATE_IP "grep -vF '$OLD_PUBLIC_KEY' ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.tmp && mv ~/.ssh/authorized_keys.tmp ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"; then
  echo "Failed to remove the old public key. Restoring backup..."
  if [ -f "$BACKUP_KEY_PATH" ]; then
    cp "$BACKUP_KEY_PATH" "$OLD_KEY_PATH"
    cp "$BACKUP_PUBLIC_KEY_PATH" "$OLD_PUBLIC_KEY_PATH"
  fi
  exit 1
fi

# Verify that the old key no longer works
echo "Testing old SSH key..."
if ssh -i "$OLD_KEY_PATH" ubuntu@$PRIVATE_IP 'exit'; then
  echo "Old key is still valid, which shouldn't be the case. Restoring backup..."
  if [ -f "$BACKUP_KEY_PATH" ]; then
    cp "$BACKUP_KEY_PATH" "$OLD_KEY_PATH"
    cp "$BACKUP_PUBLIC_KEY_PATH" "$OLD_PUBLIC_KEY_PATH"
  fi
  exit 1
fi

# Remove old key from the local machine
echo "Removing old SSH keys from local machine..."
rm -f "$OLD_KEY_PATH" "$OLD_PUBLIC_KEY_PATH"

# Replace the old key with the new key locally
echo "Replacing old key with new key locally..."
mv "$NEW_KEY_PATH" "$HOME/.ssh/id_rsa"
mv "$PUBLIC_KEY_PATH" "$HOME/.ssh/id_rsa.pub"

# Clean up backup files
echo "Removing backup SSH keys..."
rm -f "$BACKUP_KEY_PATH" "$BACKUP_PUBLIC_KEY_PATH"

echo "SSH key rotation completed successfully."
