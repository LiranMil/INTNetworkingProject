#!/bin/bash
$key2="/home/ubuntu/lmkey.pem"

# Check if KEY_PATH environment variable is set
if [ -z "$KEY_PATH" ]; then
    echo "KEY_PATH environment variable is missing."
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

# Debugging output
echo "Using SSH key: $KEY_PATH"
echo "Connecting to public instance: $PUBLIC_IP"
if [ -n "$PRIVATE_IP" ]; then
    echo "Connecting to private instance: $PRIVATE_IP"
fi

# Handle connections based on provided arguments
if [ -z "$PRIVATE_IP" ]; then
    # No private IP provided; connect to the public instance only
    ssh -i "$KEY_PATH" ubuntu@"$PUBLIC_IP"
else
    # Private IP provided; connect to the private instance via the public instance
    if [ -z "$COMMAND" ]; then
        # No command provided; open an interactive SSH session to the private instance
        ssh -i "$KEY_PATH" -t ubuntu@"$PUBLIC_IP" ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_IP"
    else
        # Command provided; execute the command on the private instance
        ssh -i "$KEY_PATH" -t ubuntu@"$PUBLIC_IP" ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_IP" "$COMMAND"
    fi
fi
