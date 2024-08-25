#!/bin/bash

if [ -z "$1" ]; then
   echo "please provide private-instance-ip"
   exit 1
fi

PRIVATE_INSTANCE_IP="$1"
NEW_KEY_NAME="id_rsa"
NEW_KEY_PATH="$HOME/.ssh/$NEW_KEY_NAME"
OLD_KEY_PATH="$NEW_KEY_PATH"
mv "$OLD_KEY_PATH" "$OLD_KEY_PATH".old
OLD_KEY_PATH="$OLD_KEY_PATH".old
OLD_KEY_PATH_PUB="$HOME/.ssh/$NEW_KEY_NAME.pub"
mv "$OLD_KEY_PATH_PUB" "$OLD_KEY_PATH_PUB".old
OLD_KEY_PATH_PUB="$OLD_KEY_PATH_PUB".old

if ! ssh-keygen -t rsa -b 2048 -f "$NEW_KEY_PATH" -N ""; then
   echo "Failed to generate SSH key"
   exit 1
fi

if ! sudo chmod 400 "$NEW_KEY_PATH"; then
   echo "Failed to set permissions on the key"
   exit 1
fi

echo "Old key path: $OLD_KEY_PATH"
echo "New key path: $NEW_KEY_PATH"

# Test SSH connection using old key
echo "Testing SSH connection with the old key..."
if ! ssh -i "$OLD_KEY_PATH" "ubuntu@$PRIVATE_INSTANCE_IP" "echo 'Old key test successful'"; then
   echo "Failed to connect with the old key"
   exit 1
fi

# Backup and clear authorized_keys
echo "Backing up and clearing authorized_keys..."
ssh -i "$OLD_KEY_PATH" "ubuntu@$PRIVATE_INSTANCE_IP" "cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.backup && echo '' > ~/.ssh/authorized_keys"

# Copy the new public key to the private instance's authorized_keys file
echo "Copying new key to authorized_keys..."
if ! ssh -i "$OLD_KEY_PATH" "ubuntu@$PRIVATE_INSTANCE_IP" "echo '$(cat $NEW_KEY_PATH.pub)' > ~/.ssh/authorized_keys"; then
   echo "Failed to copy key to the private machine"
   exit 1
fi

# Test SSH connection using the new key
echo "Testing SSH connection with the new key..."
if ! ssh -i "$NEW_KEY_PATH" "ubuntu@$PRIVATE_INSTANCE_IP" -o StrictHostKeyChecking=no "echo 'Connection successful with new key'"; then
    echo "Failed to connect with the new key"
    exit 1
fi

echo "Key rotation successful. You can now use the new key to access the private instance."
rm -f "$OLD_KEY_PATH" "$OLD_KEY_PATH_PUB"
