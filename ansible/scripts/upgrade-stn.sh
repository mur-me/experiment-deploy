#!/bin/bash

PS3="Select the operation: "

select opt in rolling_upgrade force_upgrade quit; do
   case $opt in
      rolling_upgrade)
         read -p "The group (p2ps{0..1}/p2p): " shard
         read -p "The release bucket: " release
         ansible-playbook playbooks/upgrade-node.yml -e "inventory=${shard} stride=1 upgrade=${release}"
         echo "NOTED: the leader won't be upgraded. Please upgrade leader with force_update=true"
         ;;
      force_upgrade)
         read -p "The group (p2ps{0..1}/p2p): " shard
         read -p "The release bucket: " release
         # force upgrade and no consensus check
         ANSIBLE_STRATEGY=free ansible-playbook playbooks/upgrade-node.yml -f 20 -e "inventory=${shard} stride=20 upgrade=${release} force_update=true skip_consensus_check=true"
         ;;
      quit)
         break
         ;;
      *)
         echo "Invalid option: $REPLY"
         ;;
   esac
done