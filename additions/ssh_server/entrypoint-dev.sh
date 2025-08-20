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

# helper: clone into $TARGET_DIR (create parent dirs if needed)
clone_into_target() {
  mkdir -p "$(dirname "$TARGET_DIR")"
  if [ -n "${GIT_BRANCH:-}" ]; then
    git clone --branch "$GIT_BRANCH" --single-branch "$GIT_URL" "$TARGET_DIR"
  else
    git clone "$GIT_URL" "$TARGET_DIR"
  fi
}

if [ -n "${GIT_URL:-}" ]; then
  if [ ! -d "$TARGET_DIR" ]; then
    # doesn't exist -> clone
    clone_into_target
    cd "$TARGET_DIR"
  elif [ -z "$(ls -A "$TARGET_DIR" 2>/dev/null)" ]; then
    # exists and empty -> clone into it
    clone_into_target
    cd "$TARGET_DIR"
  elif [ -d "$TARGET_DIR/.git" ]; then
    # exists, not empty, is a git repo -> continue
    cd "$TARGET_DIR"
    # avoid "dubious ownership" when volumes are mounted
    git config --global --add safe.directory "$TARGET_DIR" || true

    git remote set-url origin "$GIT_URL"
    git fetch --all --prune

    if [ -n "${GIT_BRANCH:-}" ]; then
      # checkout branch (create if only remote exists)
      if git show-ref --verify --quiet "refs/heads/$GIT_BRANCH"; then
        git checkout "$GIT_BRANCH"
      else
        git checkout -B "$GIT_BRANCH" "origin/$GIT_BRANCH" 2>/dev/null || git checkout -B "$GIT_BRANCH"
      fi
      git pull --ff-only origin "$GIT_BRANCH" || echo "Note: pull failed (no upstream yet?)"
    fi
  else
    echo "Error: $TARGET_DIR exists and is not empty, but is not a Git repo." >&2
    exit 1
  fi
fi

tail -f /dev/null
