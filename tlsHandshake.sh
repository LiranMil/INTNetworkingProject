#!/bin/bash

# Check for server IP argument
if [ -z "$1" ]; then
    echo "Usage: $0 <server-ip>"
    exit 1
fi

SERVER_IP=$1
CLIENT_HELLO_JSON='{
   "version": "1.3",
   "ciphersSuites": [
      "TLS_AES_128_GCM_SHA256",
      "TLS_CHACHA20_POLY1305_SHA256"
   ],
   "message": "Client Hello"
}'
CA_CERT_URL="https://exit-zero-academy.github.io/DevOpsTheHardWayAssets/networking_project/cert-ca-aws.pem"
CERT_FILE="cert.pem"
CA_CERT_FILE="cert-ca-aws.pem"
MASTER_KEY_FILE="master_key.txt"
ENCRYPTED_MASTER_KEY_FILE="encrypted_master_key.b64"
ENCRYPTED_SAMPLE_MESSAGE_FILE="encrypted_sample_message.der"

# Step 1: Send Client Hello
response=$(curl -s -X POST -H "Content-Type: application/json" -d "$CLIENT_HELLO_JSON" http://$SERVER_IP:8080/clienthello)
if [ $? -ne 0 ] || [ -z "$response" ]; then
    echo "Failed to send Client Hello."
    exit 1
fi

# Step 2: Handle Server Hello
SESSION_ID=$(echo "$response" | jq -r '.sessionID')
SERVER_CERT=$(echo "$response" | jq -r '.serverCert')
if [ -z "$SESSION_ID" ] || [ -z "$SERVER_CERT" ]; then
    echo "Failed to parse Server Hello response."
    exit 1
fi
echo "$SERVER_CERT" | base64 -d > "$CERT_FILE"

# Download CA certificate
wget -q "$CA_CERT_URL" -O "$CA_CERT_FILE"

# Step 3: Verify Server Certificate
if ! openssl verify -CAfile "$CA_CERT_FILE" "$CERT_FILE" > /dev/null 2>&1; then
    echo "Server Certificate is invalid."
    rm "$CERT_FILE" "$CA_CERT_FILE"
    exit 5
fi

# Step 4: Generate and Encrypt Master Key
openssl rand -base64 32 > "$MASTER_KEY_FILE"
MASTER_KEY=$(cat "$MASTER_KEY_FILE")
echo "Generated Master Key: $MASTER_KEY"

# Encrypt the master key using the server certificate
openssl smime -encrypt -aes-256-cbc -in "$MASTER_KEY_FILE" -out "$ENCRYPTED_MASTER_KEY_FILE" "$CERT_FILE" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to encrypt the master key."
    rm "$CERT_FILE" "$CA_CERT_FILE" "$MASTER_KEY_FILE"
    exit 1
fi

ENCRYPTED_MASTER_KEY=$(base64 -w 0 < "$ENCRYPTED_MASTER_KEY_FILE")

# Step 5: Send Key Exchange
KEY_EXCHANGE_JSON=$(cat <<EOF
{
    "sessionID": "$SESSION_ID",
    "masterKey": "$ENCRYPTED_MASTER_KEY",
    "sampleMessage": "Hi server, please encrypt me and send to client!"
}
EOF
)
response=$(curl -s -X POST -H "Content-Type: application/json" -d "$KEY_EXCHANGE_JSON" http://$SERVER_IP:8080/keyexchange)
if [ $? -ne 0 ] || [ -z "$response" ]; then
    echo "Failed to send Key Exchange."
    rm "$CERT_FILE" "$CA_CERT_FILE" "$MASTER_KEY_FILE" "$ENCRYPTED_MASTER_KEY_FILE"
    exit 1
fi

# Step 6: Handle Server Response
ENCRYPTED_SAMPLE_MESSAGE=$(echo "$response" | jq -r '.encryptedSampleMessage')
if [ -z "$ENCRYPTED_SAMPLE_MESSAGE" ]; then
    echo "Failed to parse Key Exchange response."
    rm "$CERT_FILE" "$CA_CERT_FILE" "$MASTER_KEY_FILE" "$ENCRYPTED_MASTER_KEY_FILE"
    exit 1
fi
echo "$ENCRYPTED_SAMPLE_MESSAGE" | base64 -d > "$ENCRYPTED_SAMPLE_MESSAGE_FILE"

# Decrypt the sample message
DECRYPTED_SAMPLE_MESSAGE=$(openssl enc -d -aes-256-cbc -in "$ENCRYPTED_SAMPLE_MESSAGE_FILE" -pass pass:"$MASTER_KEY")
if [ "$DECRYPTED_SAMPLE_MESSAGE" != "Hi server, please encrypt me and send to client!" ]; then
    echo "Server symmetric encryption using the exchanged master-key has failed."
    rm "$CERT_FILE" "$CA_CERT_FILE" "$MASTER_KEY_FILE" "$ENCRYPTED_MASTER_KEY_FILE" "$ENCRYPTED_SAMPLE_MESSAGE_FILE"
    exit 6
fi

# Success
echo "Client-Server TLS handshake has been completed successfully"

# Cleanup
rm "$CERT_FILE" "$CA_CERT_FILE" "$MASTER_KEY_FILE" "$ENCRYPTED_MASTER_KEY_FILE" "$ENCRYPTED_SAMPLE_MESSAGE_FILE"
