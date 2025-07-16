FROM base-image

############################################################################################################

# Install SSH Server

############################################################################################################

RUN apt-get update \
    && apt-get install -y --no-install-suggests --no-install-recommends \
      openssh-server \
      git \
      sudo \
      libatomic1 \
      wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# SSH setup
RUN mkdir -p /var/run/sshd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh

# Ensure SSH uses the authorized_keys file for authentication
RUN sed -i '/^AuthorizedKeysFile /d' /etc/ssh/sshd_config && \
    echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "ChallengeResponseAuthentication no" >> /etc/ssh/sshd_config && \
    echo "UsePAM no" >> /etc/ssh/sshd_config && \
    echo "AuthorizedKeysFile /root/.ssh/authorized_keys" >> /etc/ssh/sshd_config

EXPOSE 22

COPY entrypoint-dev.sh /entrypoint-dev.sh
RUN chmod +x /entrypoint-dev.sh


ENTRYPOINT ["/entrypoint-dev.sh", "/home/state/code"]
