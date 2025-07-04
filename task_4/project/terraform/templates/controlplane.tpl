#!/bin/bash
# Set the hostname
hostnamectl set-hostname ${PROJECT_NAME}-k3s-cp-${ENVIRONMENT_NAME}
if [ $? -eq 0 ]; then
    echo "====> Hostname have been set succsessfully"
    echo "127.0.0.1 $(hostname)" >> /etc/hosts
    cloud-init single --name set-hostname --frequency always
else
    echo "====> Failed to set instance hostname"
    # exit 1
fi

# Update the instance
apt-get update -y
if [ $? -eq 0 ]; then
    echo "====> Updated the instance successfully."
else
    echo "====> Failed to update the instance."
    # exit 1
fi

# Install AWS CLI and jq if needed
apt-get install -y awscli jq
if [ $? -eq 0 ]; then
    echo "====> AWS CLI and JQ installed successfully"
else
    echo "====> Failed to install AWS CLI and JQ"
    # exit 1
fi

# Creates token to authenticate and retrieve instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
if [ ! -z $TOKEN ]; then
    echo "====> Created token for instance metadata."
else
    echo "====> Failed to create token."
    # exit 1
fi

# Set the AWS region using the token
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/placement/region)
if [ ! -z $AWS_REGION ]; then
    export AWS_DEFAULT_REGION=$AWS_REGION
    echo "====> Setting AWS Region to: $AWS_DEFAULT_REGION"
else
    echo "====> Failed to fetch AWS region."
    # exit 1
fi

# Retrieve the SSH certificate
CERT=$(aws ssm get-parameter --name "${KEY_PARAM_PATH}" --with-decryption --query "Parameter.Value" --output text)
if [ ! -z $CERT ]; then
    echo "====> Certificate received successfully"
else
    echo "====> Failed to get SSH certificate"
    # exit 1
fi

# Write it to file
echo "$${CERT}" > "$${CERT_PATH}"
if [ $? -eq 0 ]; then
    echo "====> Saved SSH certificate to file"
else
    echo "====> Failed to save SSH certificate"
    # exit 1
fi

# Set SSH certificate file permissions
chmod 600 "$${CERT_PATH}"
if [ $? -eq 0 ]; then
    echo "====> Permissions was successfully set"
else
    echo "====> Failed to set permissions to file"
    # exit 1
fi

# Change certificate ownership
chown ubuntu:ubuntu "$${CERT_PATH}"
if [ $? -eq 0 ]; then
    echo "====> Certificate ownership changed successfully"
else
    echo "====> Failed to changle certificate ownership"
    # exit 1
fi

# Install K3s as control plane node
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--write-kubeconfig-mode 644' sh -
if [ $? -eq 0 ]; then
    echo "====> K3s has been successfully installed as control plane node"
else
    echo "====> Failed to install K3s"
    # exit 1
fi

# Set K3s kubernetes cluster IP control plane IP address
curl -s http://169.254.169.254/latest/meta-data/local-ipv4 > /var/lib/rancher/k3s/server/ip
if [ $? -eq 0 ]; then
    echo "====> Server IP allocated succsessfully"
else
    echo "====> Failed to set cluster IP address"
fi

# Export K3s kubernetes cluster kubeconfig to SSM Parameter Store
aws ssm put-parameter --name "${KUBECONFIG_PARAM_PATH}" --value file:///etc/rancher/k3s/k3s.yaml --type SecureString --overwrite
if [ $? -eq 0 ]; then
    echo "====> Kubeconfig has been successfully exported to SSM Parameter Store"
else
    echo "====> Failed to upload kubeconfig"
    # exit 1
fi

# Export K3s kubernetes cluster node token to SSM Parameter Store
aws ssm put-parameter --name "${NODE_TOKEN_PARAM_PATH}" --value file:///var/lib/rancher/k3s/server/node-token --type SecureString --overwrite
if [ $? -eq 0 ]; then
    echo "====> Node token has been successfully exported to SSM Parameter Store"
else
    echo "====> Failed to upload node token"
    # exit 1
fi
