#!/bin/bash
set -e

# This script is used to render Jenkins configuration files from Jinja2 templates.

### Environment variables for rendering ###
# Global #
APP_URL="http://flask.aws.elysium-space.com"
BUILD_IMAGE=true
EMAIL_RECIPIENT="isbelevtsov@gmail.com"
ENVIRONMENT_NAME="dev" # Only for multitool Dockerfile
GIT_REPO="https://github.com/isbelevtsov/rsschool-devops-course-tasks.git"
GIT_BRANCH="task_6"
IMAGE_NAME="isbelevtsov/flask-app"
IMAGE_TAG="latest"
PROJECT_NAME="rs" # Only for multitool Dockerfile
PUSH_IMAGE=true
SONAR_ORGANIZATION="isbelevtsov"
SONAR_PROJECT_KEY="isbelevtsov_rsschool-devops-course-tasks"
# AWS-specific #
AWS_ACCOUNT_ID="123456789012"
AWS_REGION="eu-north-1"
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
SCAN_IMAGE=true

for arg in "$@"; do
    echo "Processing argument: $arg"
    case $arg in
        --jenkins-config=*)
            JENKINS_CONFIG="${arg#*=}"
            echo "Jenkins configuration file set to: $JENKINS_CONFIG"
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--jenkins-config=<config_file>]"
            echo "Example: $0 --jenkins-config=../jenkins/multitool-aws.jenkinsfile.j2"
            exit 1
            ;;
    esac
done

if [ -z "$JENKINS_CONFIG" ]; then
    echo "Error: JENKINS_CONFIG must be set. Please provide the path to the Jinja2 template file."
    exit 1
fi

NEW_JENKINS_CONFIG="${JENKINS_CONFIG%.j2}"
FILENAME=$(basename "$JENKINS_CONFIG")

echo "Rendering Jenkins configuration from $JENKINS_CONFIG to $NEW_JENKINS_CONFIG"
if [[ $FILENAME == multitool* ]]; then
    if [[ $FILENAME == *aws* ]]; then
        jinja2 "$JENKINS_CONFIG" \
            -D APP_URL="$APP_URL" \
            -D AWS_ACCOUNT_ID="$AWS_ACCOUNT_ID" \
            -D AWS_REGION="$AWS_REGION" \
            -D BUILD_IMAGE="$BUILD_IMAGE" \
            -D ECR_REGISTRY="$ECR_REGISTRY" \
            -D EMAIL_RECIPIENT="$EMAIL_RECIPIENT" \
            -D ENVIRONMENT_NAME="$ENVIRONMENT_NAME" \
            -D GIT_REPO="$GIT_REPO" \
            -D GIT_BRANCH="$GIT_BRANCH" \
            -D IMAGE_NAME="$IMAGE_NAME" \
            -D IMAGE_TAG="$IMAGE_TAG" \
            -D PROJECT_NAME="$PROJECT_NAME" \
            -D PUSH_IMAGE="$PUSH_IMAGE" \
            -D SCAN_IMAGE="$SCAN_IMAGE" \
            -D SONAR_ORGANIZATION="$SONAR_ORGANIZATION" \
            -D SONAR_PROJECT_KEY="$SONAR_PROJECT_KEY" \
            > "$NEW_JENKINS_CONFIG"
    else
        jinja2 "$JENKINS_CONFIG" \
            -D APP_URL="$APP_URL" \
            -D BUILD_IMAGE="$BUILD_IMAGE" \
            -D EMAIL_RECIPIENT="$EMAIL_RECIPIENT" \
            -D ENVIRONMENT_NAME="$ENVIRONMENT_NAME" \
            -D GIT_REPO="$GIT_REPO" \
            -D GIT_BRANCH="$GIT_BRANCH" \
            -D IMAGE_NAME="$IMAGE_NAME" \
            -D IMAGE_TAG="$IMAGE_TAG" \
            -D PROJECT_NAME="$PROJECT_NAME" \
            -D PUSH_IMAGE="$PUSH_IMAGE" \
            -D SONAR_ORGANIZATION="$SONAR_ORGANIZATION" \
            -D SONAR_PROJECT_KEY="$SONAR_PROJECT_KEY" \
            > "$NEW_JENKINS_CONFIG"
    fi
else
    jinja2 "$JENKINS_CONFIG" \
        -D APP_URL="$APP_URL" \
        -D BUILD_IMAGE="$BUILD_IMAGE" \
        -D EMAIL_RECIPIENT="$EMAIL_RECIPIENT" \
        -D GIT_REPO="$GIT_REPO" \
        -D GIT_BRANCH="$GIT_BRANCH" \
        -D IMAGE_NAME="$IMAGE_NAME" \
        -D IMAGE_TAG="$IMAGE_TAG" \
        -D PUSH_IMAGE="$PUSH_IMAGE" \
        -D SONAR_ORGANIZATION="$SONAR_ORGANIZATION" \
        -D SONAR_PROJECT_KEY="$SONAR_PROJECT_KEY" \
        > "$NEW_JENKINS_CONFIG"
fi
