#!/bin/bash
# Set the hostname
hostnamectl set-hostname ${PROJECT_NAME}-worker-${ENVIRONMENT_NAME}
if [ $? -eq 0 ]; then
    echo "====> Hostname have been set succsessfully"
    echo "127.0.0.1 $(hostname)" >> /etc/hosts
    cloud-init single --name set-hostname --frequency always
else
    echo "====> Failed to set instance hostname"
    exit 1
fi

# Update the instance
apt-get update -y
if [ $? -eq 0 ]; then
    echo "====> Updated the instance successfully."
else
    echo "====> Failed to update the instance."
    exit 1
fi

# Install AWS CLI and jq if needed
apt-get install -y awscli jq
if [ $? -eq 0 ]; then
    echo "====> AWS CLI and JQ installed successfully"
else
    echo "====> Failed to install AWS CLI and JQ"
    exit 1
fi

# Creates token to authenticate and retrieve instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
if [ ! -z $TOKEN ]; then
    echo "====> Created token for instance metadata."
else
    echo "====> Failed to create token."
    exit 1
fi

# Set the AWS region using the token
AWS_REGION=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/placement/region)
if [ ! -z $AWS_REGION ]; then
    export AWS_DEFAULT_REGION=$AWS_REGION
    echo "====> Setting AWS Region to: $AWS_DEFAULT_REGION"
else
    echo "====> Failed to fetch AWS region."
    exit 1
fi

# Retrieve the SSH certificate
CERT=$(aws ssm get-parameter --name "${KEY_PARAM_PATH}" --with-decryption --query "Parameter.Value" --output text)
if [ ! -z $CERT ]; then
    echo "====> Certificate received successfully"
else
    echo "====> Failed to get SSH certificate"
    exit 1
fi

# Write it to file
echo "$${CERT}" > "$${CERT_PATH}"
if [ $? -eq 0 ]; then
    echo "====> Saved SSH certificate to file"
else
    echo "====> Failed to save SSH certificate"
    exit 1
fi

# Set SSH certificate file permissions
chmod 600 "${CERT_PATH}"
if [ $? -eq 0 ]; then
    echo "====> Permissions was successfully set"
else
    echo "====> Failed to set permissions to file"
    exit 1
fi

# Change certificate ownership
chown ubuntu:ubuntu "${CERT_PATH}"
if [ $? -eq 0 ]; then
    echo "====> Certificate ownership changed successfully"
else
    echo "====> Failed to changle certificate ownership"
    exit 1
fi

# Retrive control plane node private IP address
K3S_CONTROL_PLANE_PRIVATE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:k3s_role,Values=controlplane" \
  --query "Reservations[*].Instances[*].PrivateIpAddress" \
  --output text)
if [ ! -z $${K3S_CONTROL_PLANE_PRIVATE_IP} ]; then
    echo "====> Getting K3s control plane node private IP address"
else
    echo "====> Failed to fetch K3s control plane node private IP address"
    exit 1
fi

# Retrieve K3s worker node token from control plane
K3S_TOKEN=$(ssh -o StrictHostKeyChecking=no -i ${CERT_PATH} ubuntu@$${K3S_CONTROL_PLANE_PRIVATE_IP} 'sudo cat /var/lib/rancher/k3s/server/node-token')
if [ ! -z $K3S_TOKEN ]; then
    echo "====> Getting K3s worker node token from control plane"
else
    echo "====> Failed to fetch K3s worker node token"
    exit 1
fi

# Set K3s control plane API server URL
K3S_URL=https://$${K3S_CONTROL_PLANE_PRIVATE_IP:6443}
echo "====> Setting K3s API server URL to $K3S_URL"

# Install K3s as worker node
curl -sfL https://get.k3s.io | sh -
if [ $? -eq 0 ]; then
    echo "====> K3s has been successfully installed as worker node"
else
    echo "====> Failed to install K3s"
    exit 1
fi

# Prepare data directory for Jenkins
sudo mkdir -p ${JENKINS_DATA_DIR} && sudo chown ubuntu:ubuntu ${JENKINS_DATA_DIR}
if [ $? -eq 0 ]; then
    echo "====> Data directory has been created successfully ${JENKINS_DATA_DIR}"
else
    echo "====> Failed to create Jenkins data directory"
    exit 1
fi
