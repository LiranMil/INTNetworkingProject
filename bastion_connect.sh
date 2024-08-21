#!/bin/bash

# Check if KEY_PATH environment variable is set
if [ -z "$KEY_PATH" ]; then
    echo "Error: KEY_PATH environment variable is required."
    exit 5
fi

# Check if a public IP address is provided
if [ $# -lt 1 ]; then
    echo "Error: Please provide the bastion (public instance) IP address."
    exit 5
fi

# Define variables
PUBLIC_IP=$1
PRIVATE_IP=$2
COMMAND=${@:3}

# Check if PRIVATE_IP is provided
if [ -z "$PRIVATE_IP" ]; then
    # Connect to the public instance only
    ssh -i "$KEY_PATH" ubuntu@"$PUBLIC_IP"
else
    if [ -z "$COMMAND" ]; then
        # Connect to the private instance through the public instance
        ssh -i "$KEY_PATH" -A ubuntu@"$PUBLIC_IP" ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_IP"
    else
        # Execute a command on the private instance through the public instance
        ssh -i "$KEY_PATH" -A ubuntu@"$PUBLIC_IP" ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_IP" "$COMMAND"
    fi
fi
