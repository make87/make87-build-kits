FROM ghcr.io/make87/cuda:12.4.1-cudnn-runtime-ubuntu22.04 AS build-image

RUN apt-get update \
    && apt-get install -y \
      build-essential \
      cmake \
      curl \
      jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app

COPY Cargo.toml .
COPY src ./src

# Install dependencies for examples
RUN cargo build --release

# Extract the binary name using cargo metadata and jq
# and copy the binary to /binary
RUN binary_name=$(cargo metadata --format-version=1 --no-deps | \
    jq -r '.packages[].targets[] | select(.kind[] == "bin") | .name') \
    && echo "Binary name: $binary_name" \
    && cp target/release/$binary_name /main

FROM ghcr.io/make87/cuda:12.4.1-cudnn-runtime-ubuntu22.04

WORKDIR /app

# Copy the workspace from the builders
COPY --from=build-image /main /app/main

CMD ["/app/main"]
