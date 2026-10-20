#!/bin/bash
set -e

TERRAFORM_DIR="$(dirname "$0")/../terraform"
ANSIBLE_DIR="$(dirname "$0")/../ansible"

CONSUL_SERVER_IP=$(terraform -chdir="${TERRAFORM_DIR}" output -raw consul_server_public_ip)
CONSUL_SERVER_PRIVATE_IP=$(terraform -chdir="${TERRAFORM_DIR}" output -raw consul_server_private_ip)
BACKEND_IPS=$(terraform -chdir="${TERRAFORM_DIR}" output -json backend_public_ips | jq -r '.[]')
LB_IP=$(terraform -chdir="${TERRAFORM_DIR}" output -raw lb_public_ip)

cat > "${ANSIBLE_DIR}/inventory.ini" << EOF
[consul_server]
${CONSUL_SERVER_IP}

[backends]
$(echo "${BACKEND_IPS}")

[load_balancer]
${LB_IP}

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_ed25519_con
consul_server_private_ip=${CONSUL_SERVER_PRIVATE_IP}
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
EOF

echo "Inventory writtern to ${ANSIBLE_DIR}/inventory.ini"