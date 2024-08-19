#!/bin/bash

if [ -z "$1" ]; then
    echo "Usage: $0 <private-instance-ip>"
    exit 1
fi

PRIVATE_IP=$1
NEW_KEY_PATH=~/new_ssh_key
OLD_KEY_PATH="$KEY_PATH"

# Step 1:
ssh-keygen -t rsa -b 2048 -f "$NEW_KEY_PATH" -N ""
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate a new SSH key."
    exit 1
fi

# Step 2:
chmod 400 "$NEW_KEY_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to set permissions on the new SSH key."
    exit 1
fi

# Step 3:
ssh -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_IP" "echo '$(cat ${NEW_KEY_PATH}.pub)' >> ~/.ssh/authorized_keys"
if [ $? -ne 0 ]; then
    echo "Error: Failed to copy the new SSH key to the private instance."
    exit 1
fi

# Step 4:
ssh -i "$OLD_KEY_PATH" ubuntu@"$PRIVATE_IP" "sed -i '/$(cat ${OLD_KEY_PATH}.pub)/d' ~/.ssh/authorized_keys"
if [ $? -ne 0 ]; then
    echo "Error: Failed to remove the old SSH key from the private instance."
    exit 1
fi

# Step 5:
ssh -i "$NEW_KEY_PATH" ubuntu@"$PRIVATE_IP" "exit"
if [ $? -ne 0 ]; then
    echo "Error: Failed to connect to the private instance with the new SSH key."
    exit 1
fi

# Step 6:
cp "$OLD_KEY_PATH" "${OLD_KEY_PATH}.backup"
mv "$NEW_KEY_PATH" "$OLD_KEY_PATH"
mv "${NEW_KEY_PATH}.pub" "${OLD_KEY_PATH}.pub"
echo "Key rotation successful. New key is now in place."

# Step 7:
export KEY_PATH="$OLD_KEY_PATH"
echo "KEY_PATH updated to use the new key."
