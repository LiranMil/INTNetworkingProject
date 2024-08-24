#!/bin/bash

set -e

# Check if the private instance IP is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <private-instance-ip>"
    exit 1
fi

PRIVATE_IP="$1"
KEY_PATH=$(pwd)/private_key
OLD_PRIVATE_KEY_PATH=$(pwd)/private_key.old
NEW_PRIVATE_KEY_PATH=$(pwd)/private_key
NEW_PUBLIC_KEY_PATH=$(pwd)/private_key.pub

# Backup old keys
if [ -f "$KEY_PATH" ]; then
    mv "$KEY_PATH" "$OLD_PRIVATE_KEY_PATH"
    mv "$NEW_PUBLIC_KEY_PATH" "$NEW_PUBLIC_KEY_PATH.old"
fi

# Generate new SSH key pair
ssh-keygen -t rsa -b 4096 -f "$NEW_PRIVATE_KEY_PATH" -N "" -C "Key rotated on $(date)" > /dev/null
chmod 400 "$NEW_PRIVATE_KEY_PATH"

# Ensure old key exists
if [ ! -f "$OLD_PRIVATE_KEY_PATH" ]; then
    echo "Old key not found at $OLD_PRIVATE_KEY_PATH"
    exit 1
fi

# Copy the rotation script to the public instance
echo "Copying the rotation script into your public instance."
scp ssh_keys_rotation.sh ubuntu@$PUBLIC_IP:/home/ubuntu/

# Execute the rotation script on the public instance
echo "Connecting to your public instance and executing the rotation script."
ssh -i "$KEY_PATH" ubuntu@$PUBLIC_IP "./ssh_keys_rotation.sh $PRIVATE_IP"

# Fetch old keys
OLD_KEYS=$(bash bastion_connect.sh $PUBLIC_IP $PRIVATE_IP "cat ~/.ssh/authorized_keys")

# Fetch new keys
NEW_KEYS=$(bash bastion_connect.sh $PUBLIC_IP $PRIVATE_IP "cat ~/.ssh/authorized_keys")

echo "Public keys found in the ~/.ssh/authorized_keys file in your private instance, after the rotation:"
echo -e "------------------------------------------------------------------------------\n\n"
echo $NEW_KEYS

# Validate that old keys are no longer present
while read -r old_key; do
    if echo "$NEW_KEYS" | grep -qF "$old_key"; then
        echo "Some key that existed before rotation are still present after rotation."
        exit 1
    fi
done <<< "$OLD_KEYS"

echo "Key rotation completed successfully."
