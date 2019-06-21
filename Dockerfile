FROM ubuntu:xenial

ENV TERRAFORM_VERSION=0.11.14

ENV TERRAFORM_HELM_PROVIDER_VERSION=v0.6.0
ENV TERRAFORM_HELM_PROVIDER_URL=https://github.com/mcuadros/terraform-provider-helm/releases/download/${TERRAFORM_HELM_PROVIDER_VERSION}/terraform-provider-helm_${TERRAFORM_HELM_PROVIDER_VERSION}_linux_amd64.tar.gz

ENV KUBECTL_VERSION=v1.15.0

ENV HELM_VERSION=v2.14.1
ENV HELM_FILENAME=helm-${HELM_VERSION}-linux-amd64.tar.gz

RUN apt-get update \
    && apt-get -y install build-essential curl unzip \
        python-dev \
        python-setuptools \
        python-pip \
        apt-transport-https \
        lsb-release \
        git \
        socat \
    && rm -rf /var/lib/apt/lists/*

# Install Google cloud SDK
ENV CLOUD_SDK_VERSION 251.0.0
RUN pip install -U crcmod   && \
    export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y google-cloud-sdk=${CLOUD_SDK_VERSION}-0

# Create non-root user
RUN groupadd -r deployment --gid=999 && useradd --create-home --gid deployment --uid=999 deployment

# Switch to non-root user and setup bin directory
USER deployment

ENV HOME="/home/deployment"
ENV BIN_PATH="${HOME}/bin"
ENV PATH="${BIN_PATH}:${PATH}"

WORKDIR ${HOME}
RUN mkdir ${BIN_PATH}

# Install kubectl

RUN curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl -o ${BIN_PATH}/kubectl \
    && chmod +x ${BIN_PATH}/kubectl

# Install Terraform

RUN cd /tmp \
    && curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip -d ${BIN_PATH} && \
    rm -rf /tmp/*

# Install Terraform Helm provider: https://github.com/mcuadros/terraform-provider-helm#installation

RUN mkdir -p ~/.terraform.d/plugins/ \
    && cd /tmp \
    && curl -LO ${TERRAFORM_HELM_PROVIDER_URL} \
    && tar -xvf terraform-provider-helm*.tar.gz \
    && mv terraform-provider-helm*/terraform-provider-helm ~/.terraform.d/plugins/ \
    && rm -rf /tmp/*

# Install Helm

RUN cd /tmp \
    && curl -LO https://storage.googleapis.com/kubernetes-helm/helm-${HELM_VERSION}-linux-amd64.tar.gz \
    && tar -xvf helm-${HELM_VERSION}-linux-amd64.tar.gz \
    && mv linux-amd64/helm ${BIN_PATH} \
    && rm -rf /tmp/* \
    && helm init --client-only \
    && helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com/ \
    && helm plugin install https://github.com/viglesiasce/helm-gcs.git --version v0.2.0

