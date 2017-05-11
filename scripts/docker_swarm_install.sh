#!/bin/bash -x
exec > >(tee -i /tmp/"$(basename "$0" .sh)"_"$(date '+%Y-%m-%d_%H-%M-%S')".log) 2>&1

# Configure base Docker service
salt $SALT_OPTS -C 'I@docker:swarm' state.sls docker.host
# Configure the Swarm master node
salt $SALT_OPTS -C 'I@docker:swarm:role:master' state.sls docker.swarm
# Send grains to mine for the Swarm slave nodes
salt $SALT_OPTS -C 'I@docker:swarm' state.sls salt.minion.grains
salt $SALT_OPTS -C 'I@docker:swarm' mine.update
salt $SALT_OPTS -C 'I@docker:swarm' saltutil.refresh_modules
sleep 5
# Rerun Swarm state on master node to properly push Swarm tokens into grains
salt -C 'I@docker:swarm:role:master' state.sls docker.swarm
# Configure Swarm slave nodes
salt $SALT_OPTS -C 'I@docker:swarm:role:manager' state.sls docker.swarm -b 1

# List registered Docker Swarm nodes
salt $SALT_OPTS -C 'I@docker:swarm:role:master' cmd.run 'docker node ls'
