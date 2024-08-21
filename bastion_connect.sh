
#!/bin/bash

if [ -z "$KEY_PATH" ]; then
    echo "KEY_PATH env var is expected"
    exit 5
fi

if [ $# -lt 1 ]; then
    echo "Please provide bastion IP address"
    exit 5
fi

PUBLIC_IP=$1
PRIVATE_IP=$2
COMMAND=$3


if [ -z "$PRIVATE_IP" ]; then
    ssh -i "$KEY_PATH" ubuntu@"$PUBLIC_IP"
else
    if [ -z "$COMMAND" ]; then
        ssh -i "$KEY_PATH" -t ubuntu@"$PUBLIC_IP" ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@"$PRIVATE_IP"
    else
        ssh -i "$KEY_PATH" -t ubuntu@"$PUBLIC_IP" ssh -i /home/ubuntu/.ssh/id_rsa ubuntu@"$PRIVATE_IP" "$COMMAND"
    fi
fi
