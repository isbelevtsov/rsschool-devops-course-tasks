FROM quay.io/buildah/stable:latest
LABEL maintainer="isbelevtsov"

RUN dnf install -y \
    awscli \
    kubectl \
    helm \
    curl \
    git \
    make \
    gcc \
    python3 \
    python3-pip

ENTRYPOINT ["/bin/bash"]
