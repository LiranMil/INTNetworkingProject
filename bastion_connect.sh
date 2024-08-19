#!/bin/bash

#לבדוק האם אם קי-פאט חסר
if [ -z "$KEY_PATH" ]; then
    echo "Error: KEY_PATH environment variable is required."
    exit 5
fi

#בודק האם באמת יש IP כלשהו
if [ $# -lt 1 ]; then
    echo "Error: Please provide the bastion (public instance) IP address."
    exit 5
fi

#הגדרת משתנים
PUBLIC_IP=$1
PRIVATE_IP=$2
COMMAND=${@:3}

#
if [ -z "$PRIVATE_IP" ]; then
    ssh -i "$KEY_PATH" ubuntu@"$PUBLIC_IP"
else
    if [ -z "$COMMAND" ]; then
        ssh -i "$KEY_PATH" -A ubuntu@"$PUBLIC_IP" ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_IP"
    else
        ssh -i "$KEY_PATH" -A ubuntu@"$PUBLIC_IP" ssh -i "$KEY_PATH" ubuntu@"$PRIVATE_IP" "$COMMAND"
    fi
fi
