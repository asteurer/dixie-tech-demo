#!/bin/bash

set -e # Exit the script on error

docker_image=$1

# Spin up a temporary Postgres instance for sqlx
docker run --name sqlx-db \
	-d \
	-p 5432:5432 \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=postgres \
    -v ./docker_compose/database:/docker-entrypoint-initdb.d/ \
    postgres

sleep 2

# Create the required sqlx files
cd rust_web_server
DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres cargo sqlx prepare
cd ..

docker stop sqlx-db
docker rm sqlx-db

docker build ./rust_web_server -t $docker_image