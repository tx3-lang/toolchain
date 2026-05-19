FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    curl \
    git \
    golang-go \
    libssl-dev \
    nodejs \
    npm \
    pkg-config \
    python-is-python3 \
    python3 \
    python3-pip \
    python3-venv \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

ENV RUSTUP_HOME=/opt/rust/rustup \
    CARGO_HOME=/opt/rust/cargo \
    PATH=/opt/rust/cargo/bin:${PATH} \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN mkdir -p /opt/rust && \
    curl https://sh.rustup.rs -sSf | bash -s -- -y --profile minimal --default-toolchain stable && \
    chmod -R a+rX /opt/rust

WORKDIR /workspace

CMD ["bash"]
