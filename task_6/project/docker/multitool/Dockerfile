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
    python3-pip && \
    dnf clean all && \
    pip3 install pytest jinja2-cli

ENTRYPOINT ["/bin/bash"]
