#!/bin/bash
# Set the hostname
hostnamectl set-hostname ${PROJECT_NAME}-bastion-${ENVIRONMENT_NAME}
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

# Install needed packages
apt-get install -y awscli jq nginx
if [ $? -eq 0 ]; then
    echo "====> Packages has been installed successfully"
else
    echo "====> Failed to install system packages"
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
if [ ! -z $AWS_REGIOM ]; then
    export AWS_DEFAULT_REGION=$AWS_REGION
    echo "====> Setting AWS Region to: $AWS_DEFAULT_REGION"
else
    echo "====> Failed to fetch AWS region."
    # exit 1
fi

# Retrieve the SSH certificate
CERT=$(aws ssm get-parameter --name "${KEY_PARAM_PATH}" --with-decryption --query "Parameter.Value" --output text)
if [ ! -z $CERT ]; then
    echo "====> SSH certificate received successfully"
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

# Retrive control plane node private IP address
K3S_CONTROL_PLANE_PRIVATE_IP=$(aws ec2 describe-instances \
  --filters "Name=tag:k3s_role,Values=controlplane" \
  --query "Reservations[*].Instances[*].PrivateIpAddress" \
  --output text)
if [ ! -z $K3S_CONTROL_PLANE_PRIVATE_IP ]; then
    echo "====> Getting K3s control plane node private IP address $${K3S_CONTROL_PLANE_PRIVATE_IP}"
else
    echo "====> Failed to fetch K3s control plane node private IP address"
    # exit 1
fi

# Backup existing default config
mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak 2>/dev/null || true
mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak 2>/dev/null || true

# Create Nginx reverse proxy config for K3s kubernetes cluster API
NGINX_KUBE_SITE_PATH="/etc/nginx/sites-available/k3s"
cat <<EOF > $NGINX_KUBE_SITE_PATH
server {
    listen 6443;
    server_name k8s.elysium-space.com;

    location / {
        proxy_pass https://$K3S_CONTROL_PLANE_PRIVATE_IP:6443;
        proxy_ssl_verify off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
if [ -f $NGINX_KUBE_SITE_PATH ]; then
    echo "====> Nginx config has been create succsessfully: $$NGINX_KUBE_SITE_PATH "
else
    echo "====> Failed to create Nginx reverse proxy config"
    # exit 1
fi

NGINX_JENKINS_SITE_PATH="/etc/nginx/sites-available/jenkins"
cat <<EOF > $NGINX_JENKINS_SITE_PATH
server {
    listen 8080;
    server_name jenkins.elysium-space.com;

    location / {
        proxy_pass https://$K3S_CONTROL_PLANE_PRIVATE_IP:8080;
        proxy_ssl_verify off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
if [ -f $NGINX_JENKINS_SITE_PATH ]; then
    echo "====> Nginx config has been create succsessfully: $$NGINX_JENKINS_SITE_PATH "
else
    echo "====> Failed to create Nginx reverse proxy config"
    # exit 1
fi

# Test Nginx configuration
nginx -t
if [ $? -eq 0 ]; then
    echo "====> Nginx configuration test has been succsessfully passed"
else
    echo "====> Failed to test Nginx configuration"
    # exit 1
fi

# Enable nginx sites
ln -s /etc/nginx/sites-available/k3s /etc/nginx/sites-enabled/ && ln -s /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
if [ $? -eq 0 ]; then
    echo "====> Nginx sites has been succsessfully enabled"
else
    echo "====> Failed to enable Nginx site"
    # exit 1
fi

# Restart and enable Nginx systemd service
systemctl restart nginx && systemctl enable nginx
if [ $? -eq 0 ]; then
    echo "====> Nginx service has been succsessfully restarted and enabled"
else
    echo "====> Failed to restart and enable Nginx systemd service"
    # exit 1
fi

# Open firewall
NGINX_PORT=6443
if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow "$NGINX_PORT/tcp"
elif command -v firewall-cmd >/dev/null 2>&1; then
    sudo firewall-cmd --add-port=$${NGINX_PORT}/tcp --permanent
    sudo firewall-cmd --reload
fi
if [ $? -eq 0 ]; then
    echo "Configuring firewall to allow TCP $${NGINX_PORT}"
else
    echo "Failed to open $${NGINX_PORT} thought firewall"
    # exit 1
fi
