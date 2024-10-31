FROM rust:1.82-alpine AS builder
WORKDIR /app
# Add build dependencies...
RUN apk update && apk add --no-cache build-base
# Copy Cargo.toml and Cargo.lock to cache dependencies
COPY Cargo.toml Cargo.lock ./
# Create a dummy main.rs to allow cargo fetch to proceed
RUN mkdir src
RUN echo "fn main() {}" > src/main.rs
# Pre-fetch dependencies for faster build when src files are changed
RUN cargo fetch
COPY . .
RUN cargo build --release


FROM alpine
WORKDIR /app
COPY --from=builder /app/target/release/show-ip-address .
EXPOSE 8000
CMD ["./show-ip-address"]
