FROM ghcr.io/make87/ffmpeg:7.1.1 AS build-image

# Install Rust toolchain
RUN apt-get update && apt-get install -y curl && \
    curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

RUN apt-get update \
    && apt install --no-install-suggests --no-install-recommends -y \
    jq \
    build-essential \
    libclang-dev \
    pkg-config\
    cmake \
    nasm \
    libssl-dev \
    libavutil-dev \
    libavformat-dev \
    libavfilter-dev \
    libavdevice-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY Cargo.toml .
COPY src ./src

RUN cargo build --release $CARGO_BUILD_FLAGS

RUN binary_name=$(cargo metadata --format-version=1 --no-deps | \
    jq -r '.packages[].targets[] | select(.kind[] == "bin") | .name') \
    && echo "Binary name: $binary_name" \
    && cp target/release/$binary_name /main

FROM ghcr.io/make87/ffmpeg:7.1.1


# Install the FFmpeg shared libraries only
RUN apt-get update && apt-get install -y \
    libavutil58 \
    libavcodec60 \
    libavformat60 \
    && rm -rf /var/lib/apt/lists/*


WORKDIR /app
COPY --from=build-image /main /app/main
RUN chmod +x /app/main
ENTRYPOINT ["/app/main"]
