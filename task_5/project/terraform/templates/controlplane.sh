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
apt-get install -y awscli jq curl openssh-client
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

# Retrieve EC2 tag values
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

# Sanitize and set hostname
HOSTNAME_CLEAN=$(echo "$HOSTNAME_VALUE" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-zA-Z0-9.-')
hostnamectl set-hostname "$HOSTNAME_CLEAN"
echo "127.0.0.1 $HOSTNAME_CLEAN" >> /etc/hosts
echo "====> Hostname set to $HOSTNAME_CLEAN"

# Start SSM agent
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
echo "====> SSM agent started."

# Retrieve SSH certificate from SSM
CERT=$(aws ssm get-parameter \
    --name "/$PROJECT_NAME/$ENVIRONMENT_NAME/common/ssh_key" \
    --with-decryption \
    --query "Parameter.Value" \
    --output text)

if [[ -z "$CERT" ]]; then
    echo "====> Failed to retrieve SSH certificate."
    exit 1
fi

KEY_FILE="$PROJECT_NAME-$ENVIRONMENT_NAME-ssh-key.pem"
echo "$CERT" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
chown ubuntu:ubuntu "$KEY_FILE"
echo "SSH_KEY_FILE=$KEY_FILE" >> /etc/environment
echo "====> SSH certificate saved to $KEY_FILE"

# Get public and private IPs
CONTROL_PRIVATE_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4)

# ----> START K3s CONTROL PLANE INSTALL
echo "====> Installing k3s control plane..."

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="--write-kubeconfig-mode 644 \
  --tls-san k8s.aws.elysium-space.com \
  --tls-san ${CONTROL_PRIVATE_IP} \
  --kube-apiserver-arg bind-address=0.0.0.0" \
  sh -

echo "====> Waiting for k3s to become active..."
until systemctl is-active --quiet k3s; do
  echo "k3s not active, retrying in 5s..."
  sleep 5
done

echo "====> k3s is active. Proceeding..."

# Record the IP for k3s internal use
echo "$CONTROL_PRIVATE_IP" | sudo tee /var/lib/rancher/k3s/server/ip

# Modify kubeconfig to use private IP instead of 127.0.0.1
KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
sed -i "s|https://127.0.0.1:6443|https://${CONTROL_PRIVATE_IP}:6443|" "$KUBECONFIG_PATH"

# Store kubeconfig in SSM Parameter Store
echo "====> Uploading kubeconfig to SSM Parameter Store..."
aws ssm put-parameter \
  --name "/${PROJECT_NAME}/${ENVIRONMENT_NAME}/kube/kubeconfig" \
  --value "file://${KUBECONFIG_PATH}" \
  --type SecureString \
  --overwrite

echo "====> Control plane node provisioning complete at $(date)"
echo "====> EC2 instance configuration completed at $(date)"
