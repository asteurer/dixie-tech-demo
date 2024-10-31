#!/bin/bash

domain=$1
script_dir=infra
ip_addr=$(terraform -chdir=$script_dir output --json | jq -r '.master_node_ip.value')

# Retrieve the KUBECONFIG file from the server, alter it, then place it in the ~/.kube directory
ssh \
	-o StrictHostKeyChecking=no \
	-o UserKnownHostsFile=/dev/null \
	ubuntu@$ip_addr \
	'sudo cat /etc/rancher/k3s/k3s.yaml' | IP_ADDR=$ip_addr DOMAIN=$domain python3 ./$script_dir/kubecfg_edit.py > ~/.kube/$domain.config