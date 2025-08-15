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

# --- we have to explicitly "forward" the container env vars to SSHd otherwise remote IDEs won't be able to use them ---
mkdir -p /etc/environment.d
: > /etc/environment.d/00-docker-env.conf
: > /etc/profile.d/00-docker-env.sh

deny_re='^(SSH_.*|PWD|OLDPWD|_=|PROMPT_COMMAND|BASH_ENV|ENV|LD_PRELOAD)$'

while IFS= read -r -d '' kv; do
  name=${kv%%=*}; val=${kv#*=}
  [ -z "$name" ] && continue
  [[ "$name" =~ $deny_re ]] && continue

  esc_env=$(printf '%s' "$val" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  printf '%s="%s"\n' "$name" "$esc_env" >> /etc/environment.d/00-docker-env.conf

  esc_sh=${val//\'/\'\"\'\"\'}
  printf 'export %s=%s\n' "$name" "'$esc_sh'" >> /etc/profile.d/00-docker-env.sh
done < /proc/1/environ

chmod 600 /etc/environment.d/00-docker-env.conf /etc/profile.d/00-docker-env.sh

# ----------------------------------------------------




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
