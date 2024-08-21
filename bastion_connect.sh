#!/bin/bash

# Verify that the KEY_PATH environment variable is set
if [ -z "$KEY_PATH" ]; then
    echo "Environment variable KEY_PATH is missing."
    exit 5
fi

# Ensure at least the public IP is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <public-ip> [private-ip] [command]"
    exit 5
fi

# Define variables
PUBLIC_IP=$1
PRIVATE_IP=$2
COMMAND=$3

# Check if the key file exists
if [ ! -f "$KEY_PATH" ]; then
    echo "Key file not found at $KEY_PATH."
    exit 2
fi

# Handle connections based on provided arguments
if [ -z "$PRIVATE_IP" ]; then
    # No private IP provided; connect to the public instance only
    ssh -i "$KEY_PATH" ubuntu@"$PUBLIC_IP"
else
    # Private IP provided; connect to the private instance via the public instance
    if [ -z "$COMMAND" ]; then
        # No command provided; open an interactive SSH session to the private instance
        ssh -i "$KEY_PATH" -t ubuntu@"$PUBLIC_IP" ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@"$PRIVATE_IP"
    else
        # Command provided; execute the command on the private instance
        ssh -i "$KEY_PATH" -t ubuntu@"$PUBLIC_IP" ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@"$PRIVATE_IP" "$COMMAND"
    fi
fi
