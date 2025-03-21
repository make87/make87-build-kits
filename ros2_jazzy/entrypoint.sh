#!/bin/bash
set -e

# Source the ROS 2 setup scripts
source "/opt/ros/$ROS_DISTRO/setup.bash"
source "/app/install/setup.bash"

# Execute the command passed to the container
source "$@"
