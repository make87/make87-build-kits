ARG VERSION=jazzy
FROM ghcr.io/make87/ros:${VERSION}-ros-base AS build-image

ARG VERSION
ENV ROS_DISTRO=${VERSION}

WORKDIR /app

# Update rosdep (already initialized)
RUN apt update

COPY . ./src

RUN rosdep install --from-paths src --ignore-src --rosdistro $ROS_DISTRO -y

# Build the examples
RUN /bin/bash -c "source /opt/ros/$ROS_DISTRO/setup.bash && colcon build"

# Create a dummy ROS package with a package.xml that leaves room for dependencies
RUN mkdir -p /app/src/make87 \
    && echo "<?xml version=\"1.0\"?><package format=\"3\"><name>make87</name><version>0.1.0</version><description>Dummy package for rosdep</description><maintainer email=\"fake@domain.com\">Fake Maintainer</maintainer><license>Apache 2.0</license>" > /app/src/make87/package.xml

# Aggregate exec_depend and depend dependencies and append them before the closing package tag
RUN find . -name "package.xml" -exec xmllint --xpath "//*[name()='exec_depend' or name()='depend']/text()" {} + | tr ' ' '\n' | sort -u > temp_depends.txt \
    && while read dep; do \
      echo "  <exec_depend>$dep</exec_depend>" >> /app/src/make87/package.xml; \
    done < temp_depends.txt \
    && echo "</package>" >> /app/src/make87/package.xml \
    && rm temp_depends.txt

FROM ghcr.io/make87/ros:${VERSION}-ros-core

# Copy the workspace from the builder
COPY --from=build-image /app/install /app/install

# Check if the source directories exist, and only copy them if they do
RUN if [ -d /app/config ]; then cp -r /app/config /app/config; fi && \
    if [ -d /app/launch ]; then cp -r /app/launch /app/launch; fi

COPY --from=build-image /app/src/make87 /app/src/make87

RUN apt-get update \
    && apt-get install -y \
      python3-rosdep

# Initialize and update rosdep
RUN rosdep init \
    && rosdep update

WORKDIR /app
RUN rosdep install --from-paths src --ignore-src -r -y \
    && rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script into the container
COPY --from=build_kit_files entrypoint.sh /

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

COPY --from=build-image /app/src/ros2_run /app/ros2_run
RUN chmod +x /app/ros2_run

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/app/ros2_run"]
