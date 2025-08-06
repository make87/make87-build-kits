# use debian trixie for ffmpeg 7 libs during build phase
FROM ghcr.io/make87/rust:1-trixie AS build-image
ARG CARGO_BUILD_FLAGS=""
ENV CARGO_BUILD_FLAGS=${CARGO_BUILD_FLAGS}

RUN apt-get update \
    && apt install --no-install-suggests --no-install-recommends -y \
    jq \
    build-essential \
    cmake \
    nasm \
    libavutil-dev \
    libavformat-dev \
    libavfilter-dev \
    libavdevice-dev \
    libclang-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Cargo.toml .
COPY src ./src

RUN sh -c "cargo build --release $CARGO_BUILD_FLAGS"

# Extract the binary name using cargo metadata and jq
# and copy the binary to /binary
RUN binary_name=$(cargo metadata --format-version=1 --no-deps | \
    jq -r '.packages[].targets[] | select(.kind[] == "bin") | .name') \
    && echo "Binary name: $binary_name" \
    && cp target/release/$binary_name /main

FROM ghcr.io/make87/ffmpeg:7.1.1

WORKDIR /app

# Copy the workspace from the builders
COPY --from=build-image /main /app/main

RUN chmod +x /app/main

ENTRYPOINT ["/app/main"]
