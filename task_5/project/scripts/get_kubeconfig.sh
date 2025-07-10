#!/bin/bash

export AWS_DEFAULT_REGION="eu-north-1"                                          # Replace with your AWS region
export AWS_PROFILE="your_aws_profile"                                           # Replace with your AWS profile
export AWS_ACCESS_KEY_ID="your_aws_access_key_id"                               # Replace with your AWS access key ID
export AWS_SECRET_ACCESS_KEY="your_aws_secret_access_key"                       # Replace with your AWS secret access key
export PROJECT_NAME="rs"                                                        # Replace with your project name
export ENVIRONMENT_NAME="dev"                                                   # Replace with your environment name (e.g., dev, prod)
export KUBECONFIG_PARAM_PATH="/$PROJECT_NAME/$ENVIRONMENT_NAME/kube/kubeconfig" # SSM Parameter Store path for kubeconfig
export KUBECONFIG_LOCAL_PATH=../kubernetes/kubeconfig                           # Path where kubeconfig will be saved

if [ -z "$AWS_DEFAULT_REGION" ] || [ -z "$AWS_PROFILE" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$PROJECT_NAME" ] || [ -z "$ENVIRONMENT_NAME" ]; then
    echo "Please set AWS_DEFAULT_REGION, AWS_PROFILE, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, PROJECT_NAME, and ENVIRONMENT_NAME."
    exit 1
fi

# Check if kubeconfig already exists
if [ -f "${KUBECONFIG_LOCAL_PATH}" ]; then
    echo "Kubeconfig file already exists at $KUBECONFIG_LOCAL_PATH. Renaming existing file to kubeconfig.bak."
    mv $KUBECONFIG_LOCAL_PATH $KUBECONFIG_LOCAL_PATH.bak
fi

aws ssm get-parameter --name $KUBECONFIG_PARAM_PATH --with-decryption --query "Parameter.Value" --output text > $KUBECONFIG_LOCAL_PATH
if [ $? -eq 0 ]; then
    chmod 600 $KUBECONFIG_LOCAL_PATH
    # export KUBECONFIG=$KUBECONFIG_LOCAL_PATH # Uncomment if you want to set KUBECONFIG environment variable
    echo "Successfully retrieved kubeconfig from SSM Parameter Store."
    echo "Kubeconfig is saved to $KUBECONFIG_LOCAL_PATH"
else
    echo "Failed to retrieve kubeconfig from SSM Parameter Store."
    exit 1
fi
