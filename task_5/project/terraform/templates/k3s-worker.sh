#!/bin/bash
set -euo pipefail

# Redirect all output to log
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "====> Running EC2 user data script on $(hostname) at $(date)"

# Update the instance
echo "====> Updating the system..."
apt-get update -y
echo "====> System updated."

# Install required packages
echo "====> Installing packages: awscli, jq, curl, openssh-client"
DEBIAN_FRONTEND=noninteractive apt-get install -y awscli jq curl openssh-client
echo "====> Packages installed."

# Retrieve instance metadata token
echo "====> Fetching metadata token..."
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

if [[ -z "$TOKEN" ]]; then
    echo "====> Failed to fetch metadata token."
    exit 1
fi
echo "====> Metadata token acquired."

# Get instance ID and region
echo "====> Retrieving instance metadata..."
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/instance-id)

AWS_REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/placement/region)

if [[ -z "$INSTANCE_ID" || -z "$AWS_REGION" ]]; then
    echo "====> Failed to retrieve instance metadata (ID or region)."
    exit 1
fi
echo "====> Instance ID: $INSTANCE_ID"
echo "====> AWS Region: $AWS_REGION"

# Configure AWS CLI
echo "====> Configuring AWS CLI..."
if ! command -v aws >/dev/null 2>&1; then
  echo "====> AWS CLI is not installed. Please install it to proceed."
  exit 1
fi
mkdir -p /home/ubuntu/.aws
cat > /home/ubuntu/.aws/config <<EOF
[default]
region = $AWS_REGION
EOF
chown -R ubuntu:ubuntu /home/ubuntu/.aws
chmod 600 /home/ubuntu/.aws/config
export AWS_DEFAULT_REGION="$AWS_REGION"
echo "AWS_REGION=$AWS_REGION" >> /etc/environment
echo "AWS_DEFAULT_REGION=$AWS_REGION" >> /etc/environment
echo "====> AWS CLI configured with region $AWS_REGION"

# Check if AWS CLI is authenticated
echo "====> Checking AWS CLI authentication..."
if ! command -v aws >/dev/null 2>&1; then
  echo "====> AWS CLI is not installed. Please install it to proceed."
  exit 1
fi
aws sts get-caller-identity >/dev/null 2>&1 || {
  echo "====> AWS CLI is not authenticated. Ensure instance profile is attached."
  exit 1
}
echo "====> AWS CLI is authenticated successfully."

# Retrieve EC2 tag values
echo "====> Retrieving EC2 tag values..."
get_tag_value() {
  local key="$1"
  aws ec2 describe-tags \
    --region "$AWS_REGION" \
    --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=$key" \
    --query "Tags[0].Value" --output text
}

HOSTNAME_VALUE=$(get_tag_value "Name")
PROJECT_NAME=$(get_tag_value "Project")
ENVIRONMENT_NAME=$(get_tag_value "Environment")

if [[ -z "$HOSTNAME_VALUE" || -z "$PROJECT_NAME" || -z "$ENVIRONMENT_NAME" ]]; then
    echo "====> Failed to retrieve one or more required tags."
    exit 1
fi

echo "====> Hostname: $HOSTNAME_VALUE"
echo "====> Project: $PROJECT_NAME"
echo "====> Environment: $ENVIRONMENT_NAME"
echo "====> Tags retrieved successfully"

# Sanitize and set hostname
echo "====> Setting hostname..."
HOSTNAME_CLEAN=$(echo "$HOSTNAME_VALUE" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-zA-Z0-9.-')
hostnamectl set-hostname "$HOSTNAME_CLEAN"
echo "127.0.0.1 $HOSTNAME_CLEAN" >> /etc/hosts
echo "====> Hostname set to $HOSTNAME_CLEAN"

# Start SSM agent
echo "====> Starting Amazon SSM Agent..."
if ! command -v snap >/dev/null 2>&1; then
    echo "====> Snap is not installed. Installing snapd..."
    apt-get install -y snapd
    echo "====> Snapd installed."
fi
if ! command -v amazon-ssm-agent >/dev/null 2>&1; then
    echo "====> Amazon SSM Agent is not installed. Installing..."
    snap install amazon-ssm-agent --classic
    echo "====> Amazon SSM Agent installed."
fi
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
echo "====> Amazon SSM Agent started"

# Retrieve SSH certificate from SSM
echo "====> Retrieving SSH certificate from SSM..."
CERT=$(aws ssm get-parameter \
    --name "/$PROJECT_NAME/$ENVIRONMENT_NAME/common/ssh_key" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text)

if [[ -z "$CERT" ]]; then
    echo "====> Failed to retrieve SSH certificate."
    exit 1
fi
echo "====> SSH certificate retrieved successfully."

KEY_FILE="$PROJECT_NAME-$ENVIRONMENT_NAME-ssh-key.pem"
echo "====> Saving SSH certificate..."
echo "$CERT" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
chown ubuntu:ubuntu "$KEY_FILE"
echo "SSH_KEY_FILE=$KEY_FILE" >> /etc/environment
echo "====> SSH certificate saved to $KEY_FILE"

# Prepare directory for Jenkins persistent data
echo "====> Preparing Jenkins data directory..."
JENKINS_DATA_DIR=$(aws ssm get-parameter \
    --name "/$PROJECT_NAME/$ENVIRONMENT_NAME/kube/jenkins_data_dir" \
    --query "Parameter.Value" \
    --output text)
if [[ -z "$JENKINS_DATA_DIR" ]]; then
    echo "====> Failed to retrieve Jenkins data directory from SSM."
    exit 1
fi
echo "====> Setting Jenkins data directory to ${JENKINS_DATA_DIR}..."
sudo mkdir -p ${JENKINS_DATA_DIR} && sudo chown ubuntu:ubuntu ${JENKINS_DATA_DIR}
if [ $? -eq 0 ]; then
    echo "====> Data directory has been created successfully ${JENKINS_DATA_DIR}"
else
    echo "====> Failed to create Jenkins data directory"
    # exit 1
fi

# Fetch control plane IP from EC2 tags
echo "====> Fetching control plane IP from EC2 tags..."
CONTROL_PLANE_IP=$(aws ec2 describe-instances \
  --region "$AWS_REGION" \
  --filters \
    "Name=tag:Project,Values=$PROJECT_NAME" \
    "Name=tag:Environment,Values=$ENVIRONMENT_NAME" \
    "Name=tag:Role,Values=k3s-control-plane" \
    "Name=instance-state-name,Values=running" \
  --query "Reservations[0].Instances[0].PrivateIpAddress" \
  --output text)
if [[ -z "$CONTROL_PLANE_IP" ]]; then
  echo "====> ERROR: Failed to retrieve control plane IP address."
  exit 1
fi
echo "====> Control plane IP: $CONTROL_PLANE_IP"

# Wait for k3s control plane to be ready
echo "====> Waiting for control plane to be ready at $CONTROL_PLANE_IP..."
until ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ubuntu@"$CONTROL_PLANE_IP" 'systemctl is-active --quiet k3s'; do
  echo "====> k3s not active yet, retrying in 5s..."
  sleep 5
done
echo "====> k3s control plane is active."

# Fetch K3s token
echo "====> Fetching K3s token from control plane..."
K3S_TOKEN=$(ssh -o StrictHostKeyChecking=no -i "$KEY_FILE" ubuntu@"$CONTROL_PLANE_IP" 'sudo cat /var/lib/rancher/k3s/server/node-token')
K3S_URL="https://${CONTROL_PLANE_IP}:6443"

if [[ -z "$K3S_TOKEN" ]]; then
  echo "====> ERROR: Failed to retrieve k3s token."
  exit 1
fi
echo "====> K3s token retrieved successfully."

# Install k3s as worker
echo "====> Installing K3s worker..."
curl -sfL https://get.k3s.io | K3S_URL="$K3S_URL" K3S_TOKEN="$K3S_TOKEN" sh -s - agent
echo "====> K3s worker installation completed."

echo "====> Worker node provisioning complete at $(date)"
echo "====> EC2 instance configuration completed at $(date)"
