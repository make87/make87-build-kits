FROM base-image


############################################################################################################

# Install OpenVSCode Server

############################################################################################################

RUN apt-get update \
    && apt-get install -y --no-install-suggests --no-install-recommends \
        git \
        sudo \
        libatomic1 \
        wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/

ARG RELEASE_TAG="openvscode-server-v1.94.2"
ARG RELEASE_ORG="gitpod-io"
ARG OPENVSCODE_SERVER_ROOT="/home/.openvscode-server"
ARG TARGETPLATFORM

RUN if [ -z "${RELEASE_TAG}" ]; then \
        echo "The RELEASE_TAG build arg must be set." >&2 && exit 1; \
    fi \
    && arch=$(echo "${TARGETPLATFORM}" | cut -d/ -f2) \
    && if [ "${arch}" = "amd64" ]; then \
        arch="x64"; \
    elif [ "${arch}" = "arm64" ]; then \
        arch="arm64"; \
    fi \
    && wget https://github.com/${RELEASE_ORG}/openvscode-server/releases/download/${RELEASE_TAG}/${RELEASE_TAG}-linux-${arch}.tar.gz \
    && tar -xzf ${RELEASE_TAG}-linux-${arch}.tar.gz \
    && mv -f ${RELEASE_TAG}-linux-${arch} ${OPENVSCODE_SERVER_ROOT} \
    && cp ${OPENVSCODE_SERVER_ROOT}/bin/remote-cli/openvscode-server ${OPENVSCODE_SERVER_ROOT}/bin/remote-cli/code \
    && rm -f ${RELEASE_TAG}-linux-${arch}.tar.gz


# Give permissions to use the /tmp directory. Required for vsix plugin install
RUN chmod 1777 /tmp


WORKDIR /home/workspace/

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    HOME=/home/workspace \
    EDITOR=code \
    VISUAL=code \
    GIT_EDITOR="code --wait" \
    OPENVSCODE_SERVER_ROOT=${OPENVSCODE_SERVER_ROOT}

RUN ${OPENVSCODE_SERVER_ROOT}/bin/openvscode-server --install-extension amerey.blackplusplus

# Install common Rust extentions
RUN ${OPENVSCODE_SERVER_ROOT}/bin/openvscode-server --install-extension vadimcn.vscode-lldb

COPY custom-remote-settings.json /home/workspace/.openvscode-server/data/Machine/settings.json

# Symlink cargo and rustup to /usr/local/bin
RUN ln -s /usr/local/cargo/bin/rust-analyzer /usr/local/bin/rust-analyzer


# Validate rust-analyzer
RUN rust-analyzer --version || echo "rust-analyzer installation failed"

# Default exposed port if none is specified
EXPOSE 3000

############################################################################################################

# Setup the entrypoint

############################################################################################################

COPY entrypoint-dev.sh /entrypoint-dev.sh
RUN chmod +x /entrypoint-dev.sh


ENTRYPOINT ["/entrypoint-dev.sh", "/home/state/code"]
