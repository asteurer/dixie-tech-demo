#!/bin/bash
script_dir=increment-count/test

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
