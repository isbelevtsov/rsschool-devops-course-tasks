#!/bin/bash

# This script assumes you've already run: terraform apply
export AWS_PROFILE=ow1eye
cat <<EOF >> ~/.aws/credentials

[$(terraform output -raw iam_user_name)]
aws_access_key_id = $(terraform output -raw iam_access_key_id)
aws_secret_access_key = $(terraform output -raw iam_secret_access_key)
EOF

cat <<EOF >> ~/.aws/config

[profile $(terraform output -raw iam_user_name)]
region = $(terraform output -raw aws_region)
output = json
EOF
echo "AWS credentials for user $(terraform output -raw iam_user_name) saved to ~/.aws/credentials and ~/.aws/config"
