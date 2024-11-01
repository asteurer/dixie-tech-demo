increment-count-test:
	@./test/increment-count/test.sh

increment-count-rm:
	@docker stop $$(docker ps | awk '/test-increment-count/ {print $$1}')
	@docker rm -v test-increment-count-postgres test-increment-count-client

increment-count-docker:
	@docker login && \
		docker build ./increment-count -t ghcr.io/asteurer/dixie-tech-demo-increment-count && \
			docker push ghcr.io/asteurer/dixie-tech-demo-increment-count

k3s-deploy:
	@helm upgrade --install dixie-tech-demo ./helm_charts/demo --values ./helm_charts/demo/values.yaml
