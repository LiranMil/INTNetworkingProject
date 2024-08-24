#!/bin/bash

# Check if the private instance IP is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <private-instance-ip>"
    exit 1
fi

PRIVATE_IP="$1"
NEW_KEY_PATH="/home/ubuntu/new_ssh_key"
OLD_KEY_PATH="/home/ubuntu/old_ssh_key"

# Step 1: Generate a new SSH key pair
ssh-keygen -t rsa -b 2048 -f "$NEW_KEY_PATH" -N ""
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate a new SSH key."
    exit 1
fi

# Set permissions
chmod 400 "$NEW_KEY_PATH"
chmod 400 "${NEW_KEY_PATH}.pub"

# Step 2: Add the new public key to the private instance
ssh -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_IP" "echo '$(cat ${NEW_KEY_PATH}.pub)' >> ~/.ssh/authorized_keys"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy the new SSH key to the private instance."
    exit 1
fi

# Step 3: Remove the old key from the private instance
OLD_KEY_CONTENT=$(cat "${OLD_KEY_PATH}.pub")
ssh -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_IP" "sed -i '/${OLD_KEY_CONTENT//\//\\/}/d' ~/.ssh/authorized_keys"
if [ $? -ne 0 ]; then
    echo "Error: Failed to remove the old SSH key from the private instance."
    exit 1
fi

# Step 4: Test the new key
ssh -i "$NEW_KEY_PATH" ubuntu@"$PRIVATE_IP" "exit"
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to the private instance with the new SSH key."
    exit 1
fi

# Step 5: Replace the old key with the new key
cp "$OLD_KEY_PATH" "${OLD_KEY_PATH}.backup"
mv "$NEW_KEY_PATH" "$OLD_KEY_PATH"
mv "${NEW_KEY_PATH}.pub" "${OLD_KEY_PATH}.pub"
echo "Key rotation successful. New key is now in place."

# Step 6: Update KEY_PATH environment variable
export KEY_PATH="$OLD_KEY_PATH"
echo "KEY_PATH updated to use the new key."
