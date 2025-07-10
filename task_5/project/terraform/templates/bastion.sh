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
echo "====> Installing packages: awscli, jq, nginx, iptables-services, iptables-persistent"
apt-get install -y awscli jq nginx iptables-persistent iptables-services
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

if [[ -z "$HOSTNAME_VALUE" || -z "$PROJECT_NAME" || -z "$ENVIRONMENT_NAME" ]]; then
    echo "====> Failed to retrieve one or more required tags."
    exit 1
fi

echo "====> Hostname: $HOSTNAME_VALUE"
echo "====> Project: $PROJECT_NAME"
echo "====> Environment: $ENVIRONMENT_NAME"

# Sanitize and set hostname
HOSTNAME_CLEAN=$(echo "$HOSTNAME_VALUE" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-zA-Z0-9.-')
hostnamectl set-hostname "$HOSTNAME_CLEAN"
echo "127.0.0.1 $HOSTNAME_CLEAN" >> /etc/hosts
echo "====> Hostname set to $HOSTNAME_CLEAN"

# Start Amazon SSM agent
systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
echo "====> Amazon SSM Agent started"

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

KEY_FILE="/home/ubuntu/$PROJECT_NAME-$ENVIRONMENT_NAME-ssh-key.pem"
echo "====> Saving SSH certificate to $KEY_FILE"
echo "$CERT"
echo "$CERT" > "$KEY_FILE"
chmod 600 "$KEY_FILE"
chown ubuntu:ubuntu "$KEY_FILE"
echo "SSH_KEY_FILE=$KEY_FILE" >> /etc/environment
echo "====> SSH certificate saved to $KEY_FILE"

# Disable default Nginx config if exists
mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak 2>/dev/null || true
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak 2>/dev/null || true
echo "====> Default Nginx configuration disabled"

# Restart and enable Nginx
systemctl restart nginx
systemctl enable nginx
echo "====> Nginx restarted and enabled"

# Open firewall ports
PORTS=(22 80 443 6443)

if command -v ufw >/dev/null 2>&1; then
    echo "====> UFW detected. Allowing ports: ${PORTS[*]}"
    for PORT in "${PORTS[@]}"; do
        ufw allow "$PORT/tcp"
    done
elif command -v firewall-cmd >/dev/null 2>&1; then
    echo "====> firewalld detected. Opening ports: ${PORTS[*]}"
    for PORT in "${PORTS[@]}"; do
        firewall-cmd --add-port=${PORT}/tcp --permanent
    done
    firewall-cmd --reload
else
    echo "====> No supported firewall tool detected (ufw or firewalld)"
fi

# Enable IP forwarding for routing
echo "====> Enabling IP forwarding..."
systemctl enable iptables && systemctl start iptables
touch /etc/sysctl.d/custom-ip-forwarding.conf
chmod 666 /etc/sysctl.d/custom-ip-forwarding.conf
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/custom-ip-forwarding.conf
sysctl -p /etc/sysctl.d/custom-ip-forwarding.conf
echo "====> IP forwarding enabled"

# Set up NAT to allow private instances to access the internet through Bastion
echo "====> Setting up NAT for internet access..."
if ! command -v iptables >/dev/null 2>&1; then
    echo "====> iptables is not installed. Please install it to proceed."
    exit 1
fi
iptables -t nat -A POSTROUTING -o ens5 -s 0.0.0.0/0 -j MASQUERADE
iptables -F FORWARD
iptables-save -c > /etc/iptables/rules.v4
echo "====> NAT setup completed"

echo "====> Firewall rules applied"
echo "====> EC2 instance configuration completed at $(date)"
