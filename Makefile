# 	Run checks on the src/ files to ensure they are using sqlx correctly
increment-count-sqlx-prepare:
	@docker run --name sqlx-db \
	-d \
	-p 5432:5432 \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=postgres \
    -e POSTGRES_DB=postgres \
    -v $$(pwd)/increment-count/test/database/schema.sql:/docker-entrypoint-initdb.d/schema.sql \
    postgres

	@cd increment-count && DATABASE_URL=postgres://postgres:postgres@localhost:5432/postgres cargo sqlx prepare
	@docker stop sqlx-db && docker rm sqlx-db

# Sets up the increment-count
increment-count-build: increment-count-sqlx-prepare
	docker build ./increment-count -t increment-count

increment-count-test: increment-count-build
	./increment-count/test/test.sh