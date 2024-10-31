#!/bin/bash

# Initializes the KUBECONFIG file for the cluster with certificates signed with the server's public IP address.
# Without this, kubectl and helm won't be able to talk to the cluster from outside the server
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $(curl http://checkip.amazonaws.com)" sh -