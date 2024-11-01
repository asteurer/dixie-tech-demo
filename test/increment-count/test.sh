#!/bin/bash
script_dir=test/increment-count

# Create db instance against which to test the sqlx code
docker run --name sqlx-db \
	-d \
	-p 5432:5432 \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=postgres \
    -v $(pwd)/$script_dir/database/schema.sql:/docker-entrypoint-initdb.d/schema.sql \
    postgres

# Validate sqlx code in src
cd increment-count && \
  DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres cargo sqlx prepare && \
    cd ..

docker stop sqlx-db
docker rm sqlx-db

docker build ../../increment-count -t ghcr.io/asteurer/dixie-tech-demo-increment-count

cat <<EOF | docker compose -f - up -d
services:
  postgres:
    image: postgres
    container_name: test-increment-count-postgres
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    volumes:
      - ./$script_dir/database:/docker-entrypoint-initdb.d
    ports:
      - "5432:5432"
    networks:
      - test_network
  db-client:
    image: increment-count
    container_name: test-increment-count-client
    environment:
      DATABASE_URL: "postgres://postgres:postgres@test-increment-count-postgres:5432/postgres?sslmode=disable"
    ports:
      - "8080:8000"
    depends_on:
      - postgres
    networks:
      - test_network
networks:
  test_network:
    driver: bridge
