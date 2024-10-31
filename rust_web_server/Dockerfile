# Build stage
FROM rust:1.82-alpine AS builder

WORKDIR /app

# Add build dependencies
RUN apk update && apk add --no-cache build-base musl-dev openssl-dev pkgconfig

# Build and cache the dependencies
COPY Cargo.toml Cargo.lock ./
# Tricking docker into caching the compiled cargo dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs
RUN cargo fetch
RUN RUSTFLAGS="-C target-feature=-crt-static" cargo build --release

# Copy the actual code files and build the application
COPY . .
# Update the file date
RUN touch src/main.rs
RUN RUSTFLAGS="-C target-feature=-crt-static" cargo build --release

# Final stage
FROM alpine

# Add runtime dependencies
RUN apk add --no-cache libssl3 libcrypto3 libgcc

WORKDIR /app

COPY --from=builder /app/target/release/rust-demo .

EXPOSE 8080

CMD ["./rust-demo"]