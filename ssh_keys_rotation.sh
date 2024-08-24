#!/bin/bash

# Ensure a private instance IP is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <private-instance-ip>"
    exit 1
fi

PRIVATE_IP=$1
NEW_KEY_PATH=~/new_ssh_key
OLD_KEY_PATH="$KEY_PATH"

# Step 1: Generate a new SSH key pair
ssh-keygen -t rsa -b 2048 -f "$NEW_KEY_PATH" -N ""
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate a new SSH key."
    exit 1
fi

# Step 2: Set correct permissions on the new SSH key
chmod 400 "$NEW_KEY_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to set permissions on the new SSH key."
    exit 1
fi

# Step 3: Add the new public key to the authorized_keys on the private instance
ssh -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_IP" "mkdir -p ~/.ssh && echo '$(cat ${NEW_KEY_PATH}.pub)' >> ~/.ssh/authorized_keys"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy the new SSH key to the private instance."
    exit 1
fi

# Step 4: Remove the old SSH key from authorized_keys on the private instance
ssh -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_IP" "sed -i '/$(cat ${OLD_KEY_PATH}.pub)/d' ~/.ssh/authorized_keys"
if [ $? -ne 0 ]; then
    echo "Error: Failed to remove the old SSH key from the private instance."
    exit 1
fi

# Step 5: Test SSH connection with the new key
ssh -i "$NEW_KEY_PATH" ubuntu@"$PRIVATE_IP" "exit"
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to the private instance with the new SSH key."
    exit 1
fi

# Step 6: Backup the old key and update to the new key
cp "$OLD_KEY_PATH" "${OLD_KEY_PATH}.backup"
mv "$NEW_KEY_PATH" "$OLD_KEY_PATH"
mv "${NEW_KEY_PATH}.pub" "${OLD_KEY_PATH}.pub"
echo "Key rotation successful. New key is now in place."

# Step 7: Update the KEY_PATH environment variable
export KEY_PATH="$OLD_KEY_PATH"
echo "KEY_PATH updated to use the new key."

