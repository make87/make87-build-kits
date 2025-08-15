#!/bin/bash
set -euo pipefail

# Give permissions to use the /tmp directory. Required for pip package installs
sudo chmod 1777 /tmp

# Create make87 keys
ssh-keygen -t ed25519 -C "app@make87.com" -f "/root/.ssh/id_ed25519" -N ""

# copy over the mounted authorized_keys file to the root user's .ssh directory
if [ -f "/root/.ssh/authorized_keys_src" ]; then
  cp /root/.ssh/authorized_keys_src /root/.ssh/authorized_keys
  chown root:root /root/.ssh/authorized_keys
  chmod 600 /root/.ssh/authorized_keys
fi

# === Import a safe subset of PID1 env for SSH sessions ===
allow_re='^(PATH|LANG|LC_|TZ|HOME|TERM|COLORTERM|http_proxy|https_proxy|no_proxy|SSL_CERT_FILE|SSL_CERT_DIR|\
MAKE87_.*|RUST.*|CARGO.*|PYTHON.*|PIP.*|VIRTUAL_ENV|CONDA.*|NODE.*|NPM.*|PNPM_HOME|YARN_.*|GOPATH|GOROOT|JAVA_HOME|\
MAVEN_HOME|GRADLE_HOME|PKG_CONFIG_PATH|LD_LIBRARY_PATH|LIBRARY_PATH|CMAKE_PREFIX_PATH|CC|CXX)$'

mkdir -p /etc/environment.d
: > /etc/environment.d/00-docker-env.conf
: > /etc/profile.d/00-docker-env.sh

# iterate null-separated env entries from PID 1
tr '\0' '\n' < /proc/1/environ | while IFS= read -r kv; do
  name=${kv%%=*}
  val=${kv#*=}

  # skip empties and obviously unsafe
  [ -z "$name" ] && continue
  case "$name" in
    # blacklist a few you *never* want to inject
    SSH_*|PWD|OLDPWD|_=|PROMPT_COMMAND|BASH_ENV|ENV) continue ;;
  esac

  # allow broad, tool-friendly set
  if echo "$name" | grep -Eq "$allow_re"; then
    # quote for /etc/environment.d (double-quote, escape \ and ")
    esc_env=$(printf '%s' "$val" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
    printf '%s="%s"\n' "$name" "$esc_env" >> /etc/environment.d/00-docker-env.conf

    # quote for shell export (single-quote with safe escaping)
    esc_sh=${val//\'/\'\"\'\"\'}
    printf 'export %s=%s\n' "$name" "'$esc_sh'" >> /etc/profile.d/00-docker-env.sh
  fi
done

chmod 600 /etc/environment.d/00-docker-env.conf /etc/profile.d/00-docker-env.sh
# ==========================================================



# Start the SSH service
sudo service ssh start

# Set up Git config
git config --global user.email "make87"
git config --global user.name "user"

# Clone repository if GIT_URL is provided
TARGET_DIR="/home/state/code"

if [ -n "$GIT_URL" ]; then
    # Check if the target directory exists
    if [ ! -d "$TARGET_DIR" ]; then
        # Clone the repository if the directory does not exist
        git clone "$GIT_URL" "$TARGET_DIR"
        cd "$TARGET_DIR"

        # Checkout the specified branch if provided
        if [ -n "$GIT_BRANCH" ]; then
            git checkout "$GIT_BRANCH"
        fi
    else
        # Change to the target directory
        cd "$TARGET_DIR"

        # Ensure the correct remote URL is set with credentials
        git remote set-url origin "$GIT_URL"

        # Check if the specified branch is provided and switch if needed
        if [ -n "$GIT_BRANCH" ]; then
            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            if [ "$CURRENT_BRANCH" != "$GIT_BRANCH" ]; then
                # Stage and commit any changes in the current branch
                git add .
                git commit -m "Saving changes before switching branch" || echo "No changes to commit"

                # Push committed changes using the URL with credentials
                git push origin "$CURRENT_BRANCH" || echo "Failed to push changes"

                # Switch to the target branch
                git checkout "$GIT_BRANCH"
            fi
        fi

        # Pull the latest changes using the URL with credentials
        git pull origin "$GIT_BRANCH" || echo "Failed to pull latest changes"
    fi
fi

tail -f /dev/null
