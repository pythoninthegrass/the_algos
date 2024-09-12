FROM rust:1.81.0-slim-bookworm AS base

RUN apt-get update && apt-get install --no-install-recommends -y \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN cargo install cargo-chef@^0.1

RUN cargo install sccache@^0.7

ENV RUSTC_WRAPPER=sccache
ENV SCCACHE_DIR=/sccache
ENV SCCACHE_CACHE_SIZE=5G
ENV RUST_LOG=sccache=info

FROM base AS planner

WORKDIR /app

COPY . .

RUN --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
cargo chef prepare --recipe-path recipe.json

FROM base AS builder

# https://doc.rust-lang.org/cargo/reference/profiles.html
# 4 built-in profiles: dev, release, test, and bench
ARG PROFILE=${PROFILE:-release}

WORKDIR /app

COPY --from=planner /app/recipe.json recipe.json

RUN --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo chef cook --release --recipe-path recipe.json

COPY . .

RUN --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo build --profile ${PROFILE}
