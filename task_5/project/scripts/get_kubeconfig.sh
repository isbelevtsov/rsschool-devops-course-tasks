#!/bin/bash

export AWS_DEFAULT_REGION= # Replace with your AWS region
export AWS_PROFILE= # Replace with your AWS profile
export AWS_ACCESS_KEY_ID= # Replace with your AWS access key ID
export AWS_SECRET_ACCESS_KEY= # Replace with your AWS secret access key
export SSM_PARAMETER_NAME="" # Replace with your SSM parameter name
export KUBECONFIG_PATH=../kubernetes # Path where kubeconfig will be saved

if [ -z "$AWS_DEFAULT_REGION" ] || [ -z "$AWS_PROFILE" ] || [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ] || [ -z "$SSM_PARAMETER_NAME" ]; then
    echo "Please set AWS_DEFAULT_REGION, AWS_PROFILE, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and SSM_PARAMETER_NAME."
    exit 1
fi

# Ensure the .kube directory exists
if [ -d $KUBECONFIG_PATH ]; then
    echo "$KUBECONFIG_PATH directory already exists."
else
    echo "Creating $KUBECONFIG_PATH directory."
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
