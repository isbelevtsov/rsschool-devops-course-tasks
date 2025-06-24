#!/bin/bash

# Define inherited variables
CERT_PATH="${CERT_PATH}"
PARAM_NAME="${PARAM_NAME}"

# Update the instance
apt-get update -y
if [ $? -eq 0 ]; then
    echo "Updated the instance successfully."
else
    echo "Failed to update the instance."
    exit 1
fi

# Install AWS CLI and jq if needed
apt-get install -y awscli jq
if [ $? -eq 0 ]; then
    echo "AWS CLI and JQ installed successfully"
else
    echo "Failed to install AWS CLI and JQ"
    exit 1
fi

# Retrieve the SSH certificate
CERT=$$(aws ssm get-parameter --name "$${PARAM_NAME}" --with-decryption --query "Parameter.Value" --output text)
if [ $? -eq 0 ]; then
    echo "Certificate received successfully"
else
    echo "Failed to get SSH certificate"
    exit 1
fi

# Write it to file
echo "$${CERT}" > "$${CERT_PATH}"
if [ $? -eq 0 ]; then
    echo "Saved SSH certificate to file"
else
    echo "Failed to save SSH certificate"
    exit 1
fi

#Set SSH certificate file permissions
chmod 600 "$${CERT_PATH}"
if [ $? -eq 0 ]; then
    echo "Permissions was successfully set"
else
    echo "Failed to set permissions to file"
    exit 1
fi
