#!/bin/bash
set -e

for arg in "$@"; do
    echo "Processing argument: $arg"
    case $arg in
        --image-repo=*)
            IMAGE_REPO="${arg#*=}"
            echo "Image repository set to: $IMAGE_REPO"
            ;;
        --image-name=*)
            IMAGE_NAME="${arg#*=}"
            echo "Image name set to: $IMAGE_NAME"
            ;;
        --image-tag=*)
            IMAGE_TAG="${arg#*=}"
            echo "Image tag set to: $IMAGE_TAG"
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Usage: $0 [--image-repo=<repo>] [--image-name=<name>] [--image-tag=<tag>]"
            echo "Example: $0 --image-repo=isbelevtsov --image-name=multitool --image-tag=latest"
            exit 1
            ;;
    esac
done

if [ -z "$IMAGE_REPO" ] || [ -z "$IMAGE_NAME" ] || [ -z "$IMAGE_TAG" ]; then
    echo "Error: IMAGE_REPO, IMAGE_NAME, and IMAGE_TAG must be set."
    exit 1
fi

# Check if builder exists
if ! docker buildx ls | grep -q '^multiarch-builder'; then
  echo "Creating buildx builder: multiarch-builder"
  docker buildx create --use --name multiarch-builder
  docker buildx inspect multiarch-builder --bootstrap
else
  echo "Buildx builder 'multiarch-builder' already exists"
fi

docker buildx build --platform linux/amd64,linux/arm64 \
    -t $IMAGE_REPO/$IMAGE_NAME:$IMAGE_TAG -t $IMAGE_REPO/$IMAGE_NAME:latest \
    --push ../docker/multitool/
