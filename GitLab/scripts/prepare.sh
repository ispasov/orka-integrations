#!/bin/bash

currentDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source ${currentDir}/base.sh

set -eo pipefail

token=$(curl -sd '{"email":'\"$CUSTOM_ENV_ORKA_USER\"', "password":'\"$CUSTOM_ENV_ORKA_PASSWORD\"'}' -H "Content-Type: application/json" -X POST $CUSTOM_ENV_ORKA_ENDPOINT/token | jq -r '.token')

node_data=""
if [ ! -z $CUSTOM_ENV_ORKA_NODE ]; then
    node_data=", \"orka_node_name\":\"$CUSTOM_ENV_ORKA_NODE\""
fi

body=$(echo '{"orka_vm_name":'\"$CUSTOM_ENV_ORKA_VM_NAME\" $node_data'}')
vm_info=$(curl -sd "$body" -H "Content-Type: application/json" -H "Authorization: Bearer $token" -X POST $CUSTOM_ENV_ORKA_ENDPOINT/resources/vm/deploy)

errors=$(echo $vm_info | jq -r '.errors[]?.message')
if [ "$errors" ]; then
    echo "VM deploy failed with: $errors"
    exit "$SYSTEM_FAILURE_EXIT_CODE"
fi

vm_id=$(echo $vm_info | jq -r '.vm_id')
echo "$vm_id" > $BUILD_ID

vm_ip=$(echo $vm_info | jq -r '.ip')
vm_ssh_port=$(echo $vm_info | jq -r '.ssh_port')
echo "$vm_ip;$vm_ssh_port" > $CONNECTION_INFO_ID

echo "Waiting for sshd to be available"
for i in $(seq 1 30); do
    if ssh -i /root/.ssh/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null $CUSTOM_ENV_ORKA_VM_USER@$vm_ip -p $vm_ssh_port "echo ok" >/dev/null 2>/dev/null; then
        break
    fi

    if [ "$i" == "30" ]; then
        echo 'Waited 30 seconds for sshd to start, exiting...'
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi

    sleep 1s
done
