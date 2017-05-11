#!/bin/bash -x
exec > >(tee -i /tmp/"$(basename "$0" .sh)"_"$(date '+%Y-%m-%d_%H-%M-%S')".log) 2>&1

CWD="$(dirname "$(readlink -f "$0")")"

# Import common functions
COMMONS="$CWD"/common_functions.sh
if [ ! -f "$COMMONS" ]; then
    echo "File $COMMONS does not exist"
    exit 1
fi
. "$COMMONS"

INFLUXDB_SERVICE=$(salt $SALT_OPTS -C 'I@influxdb:server' test.ping 1>/dev/null 2>&1 && echo true)

# Configure Telegraf
salt $SALT_OPTS -C 'I@telegraf:agent or I@telegraf:remote_agent' state.sls telegraf

# Configure Prometheus exporters
salt -C 'I@prometheus:exporters' state.sls prometheus

# Configure log_collector
salt $SALT_OPTS -C 'I@heka:log_collector' state.sls heka.log_collector

# Configure Elasticsearch/Kibana services
salt $SALT_OPTS -C 'I@elasticsearch:server' state.sls elasticsearch.server -b 1
salt $SALT_OPTS -C 'I@kibana:server' state.sls kibana.server -b 1
salt $SALT_OPTS -C 'I@elasticsearch:client' state.sls elasticsearch.client
salt $SALT_OPTS -C 'I@kibana:client' state.sls kibana.client

if [[ "$INFLUXDB_SERVICE" == "true" ]]; then
    salt $SALT_OPTS -C 'I@influxdb:server' state.sls influxdb
fi

# Collect grains needed to configure the services
salt $SALT_OPTS -C 'I@salt:minion' state.sls salt.minion.grains
salt $SALT_OPTS -C 'I@salt:minion' saltutil.refresh_modules
salt $SALT_OPTS -C 'I@salt:minion' mine.update
sleep 5

# Generate the configuration for services running in Docker Swarm
salt $SALT_OPTS -C 'I@docker:swarm' state.sls prometheus,heka.remote_collector -b 1

# Kick off the services in Docker Swarm
salt $SALT_OPTS -C 'I@docker:swarm:role:master' state.sls docker
salt $SALT_OPTS -C 'I@docker:swarm' dockerng.ps

# Configure the Grafana dashboards and datasources
stacklight_vip=$(get_param_value stacklight_monitor_address)
wait_for_http_service "http://${stacklight_vip}:15013/"
salt $SALT_OPTS -C 'I@grafana:client' state.sls grafana.client
