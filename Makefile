domain := asteurer.cc
op_vault := asteurer.cc
aws_region := us-west-2

compose-up:
	@docker compose -f docker_compose/compose.yaml up -d

compose-down:
	@docker compose -f docker_compose/compose.yaml down

go-build:
	@docker build ./go_web_server -t ghcr.io/asteurer/dixie-tech-demo

rust-build:
	@./rust_web_server/build.sh ghcr.io/asteurer/dixie-tech-demo

docker-push:
	@docker login ghcr.io && docker push ghcr.io/asteurer/dixie-tech-demo

tf-apply:
	@./infra/apply.sh $(domain) $(op_vault) $(aws_region)

tf-destroy:
	@./infra/destroy.sh $(domain) $(op_vault) $(aws_region)

k3s-init:
	@ssh \
		-o StrictHostKeyChecking=no \
		-o UserKnownHostsFile=/dev/null \
		ubuntu@$(domain) \
		'sudo bash -s' < ./infra/k3s_init.sh

	@sleep 60

	@./infra/kubecfg_store.sh $(domain)

helm-deploy:
	@helm upgrade --install demo ./helm_charts/demo --values ./helm_charts/demo/values.yaml

helm-rm:
	@helm uninstall demo

test:
	@URL=http://$(domain) go run ./load_generator/main.go

get:
	@curl asteurer.cc:30080

post:
	@curl --request POST --data-binary "lllll" asteurer.cc:30080

delete:
	@curl --request DELETE asteurer.cc:30080
