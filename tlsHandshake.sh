#!/bin/bash

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

response=$(curl -s -X POST -H "Content-Type: application/json" -d "$CLIENT_HELLO_JSON" http://$SERVER_IP:8080/clienthello)
if [ $? -ne 0 ] || [ -z "$response" ]; then
    echo "Failed to send Client Hello."
    exit 1
fi

SESSION_ID=$(echo "$response" | jq -r '.sessionID')
SERVER_CERT=$(echo "$response" | jq -r '.serverCert')
if [ -z "$SESSION_ID" ] || [ -z "$SERVER_CERT" ]; then
    echo "Failed to parse Server Hello response."
    exit 1
fi

echo "Server Certificate (PEM):"
echo "$SERVER_CERT"

echo "$SERVER_CERT" > "$CERT_FILE"

if [ ! -f "$CA_CERT_FILE" ]; then
    echo "Downloading CA certificate..."
    wget -q "$CA_CERT_URL" -O "$CA_CERT_FILE"
    if [ $? -ne 0 ]; then
        echo "Failed to download CA certificate."
        exit 5
    fi
fi

if ! openssl verify -CAfile "$CA_CERT_FILE" "$CERT_FILE" > /dev/null 2>&1; then
    echo "Server Certificate is invalid."
    rm "$CERT_FILE" "$CA_CERT_FILE"
    exit 5
fi

echo "Generating a random master key..."
openssl rand -base64 32 > "$MASTER_KEY_FILE"
MASTER_KEY=$(cat "$MASTER_KEY_FILE")
echo "Generated Master Key: $MASTER_KEY"

echo "Encrypting the master key with the server certificate..."
echo "$MASTER_KEY" | openssl rsautl -encrypt -inkey "$CERT_FILE" -pubin -out "$ENCRYPTED_MASTER_KEY_FILE"
if [ $? -ne 0 ]; then
    echo "Failed to encrypt the master key."
    rm "$CERT_FILE" "$CA_CERT_FILE" "$MASTER_KEY_FILE"
    exit 1
fi
ENCRYPTED_MASTER_KEY=$(cat "$ENCRYPTED_MASTER_KEY_FILE" | base64 -w 0)

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

ENCRYPTED_SAMPLE_MESSAGE=$(echo "$response" | jq -r '.encryptedSampleMessage')
if [ -z "$ENCRYPTED_SAMPLE_MESSAGE" ]; then
    echo "Failed to retrieve encryptedSampleMessage from the response."
    rm "$CERT_FILE" "$CA_CERT_FILE" "$MASTER_KEY_FILE" "$ENCRYPTED_MASTER_KEY_FILE"
    exit 1
fi

echo "Encrypted Sample Message (base64):"
echo "$ENCRYPTED_SAMPLE_MESSAGE"

echo "$ENCRYPTED_SAMPLE_MESSAGE" | base64 --decode > "$ENCRYPTED_SAMPLE_MESSAGE_FILE"

DECRYPTED_SAMPLE_MESSAGE=$(openssl enc -d -aes-256-cbc -in "$ENCRYPTED_SAMPLE_MESSAGE_FILE" -pass pass:"$MASTER_KEY")
if [ "$DECRYPTED_SAMPLE_MESSAGE" != "Hi server, please encrypt me and send to client!" ]; then
    echo "Server symmetric encryption using the exchanged master-key has failed."
    rm "$CERT_FILE" "$CA_CERT_FILE" "$MASTER_KEY_FILE" "$ENCRYPTED_MASTER_KEY_FILE" "$ENCRYPTED_SAMPLE_MESSAGE_FILE"
    exit 6
fi

echo "Client-Server TLS handshake has been completed successfully"

rm "$CERT_FILE" "$CA_CERT_FILE" "$MASTER_KEY_FILE" "$ENCRYPTED_MASTER_KEY_FILE" "$ENCRYPTED_SAMPLE_MESSAGE_FILE"
