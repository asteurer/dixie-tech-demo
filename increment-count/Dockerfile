# Build stage
FROM rust:1.82-alpine AS builder
WORKDIR /app

# Add build dependencies
RUN apk update && apk add --no-cache build-base musl-dev openssl-dev pkgconfig

# Copy Cargo.toml and Cargo.lock to cache dependencies
COPY Cargo.toml Cargo.lock ./

# Create a dummy main.rs to allow cargo fetch to proceed
RUN mkdir src && echo "fn main() {}" > src/main.rs

# Pre-fetch dependencies for faster build when src files are changed
RUN cargo fetch

COPY . .

# Disables static linking of C runtime, allowing musl to dynamically link against OpenSSL
RUN RUSTFLAGS="-C target-feature=-crt-static" cargo build --release

# Final stage
FROM alpine

# Add runtime dependencies
RUN apk add --no-cache libssl3 libcrypto3 libgcc

WORKDIR /app

COPY --from=builder /app/target/release/increment-count .

EXPOSE 8000

CMD ["./increment-count"]
