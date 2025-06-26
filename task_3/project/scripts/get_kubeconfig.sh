#!/bin/bash

AWS_DEFAULT_REGION= # Replace with your AWS region
AWS_PROFILE= # Replace with your AWS profile
AWS_ACCESS_KEY_ID= # Replace with your AWS access key ID
AWS_SECRET_ACCESS_KEY= # Replace with your AWS secret access key
SSM_PARAMETER_NAME="/path/to/your/key" # Replace with your SSM parameter name
KUBECONFIG_PATH="~/.kube" # Path where kubeconfig will be saved

if [ -z "$AWS_DEFAULT_REGION" ] || [ -z "$AWS_PROFILE" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$SSM_PARAMETER_NAME" ]; then
    echo "Please set AWS_DEFAULT_REGION, AWS_PROFILE, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and SSM_PARAMETER_NAME."
    exit 1
fi

# Ensure the .kube directory exists
if [ -d $KUBECONFIG_PATH ]; then
    echo ".kube directory already exists in home directory."
else
    echo "Creating .kube directory in home directory."
    mkdir -p $KUBECONFIG_PATH
fi

# Check if kubeconfig already exists
if [ -f "${KUBECONFIG_PATH}/kubeconfig" ]; then
    echo "Kubeconfig file already exists at $KUBECONFIG_PATH/kubeconfig. Renaming existing file to kubeconfig.bak."
    mv $KUBECONFIG_PATH/kubeconfig $KUBECONFIG_PATH/kubeconfig.bak
fi

aws ssm get-parameter --name $SSM_PARAMETER_NAME --with-decryption --query "Parameter.Value" --output text > $KUBECONFIG_PATH/kubeconfig
if [ $? -eq 0 ]; then
    chmod 600 $KUBECONFIG_PATH/kubeconfig
    # export KUBECONFIG=$KUBECONFIG_PATH # Uncomment if you want to set KUBECONFIG environment variable
    echo "Successfully retrieved kubeconfig from SSM Parameter Store."
    echo "Kubeconfig is saved to $KUBECONFIG_PATH/kubeconfig"
else
    echo "Failed to retrieve kubeconfig from SSM Parameter Store."
    exit 1
fi
