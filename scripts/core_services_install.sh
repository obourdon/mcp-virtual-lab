#!/bin/bash -x
exec > >(tee -i /tmp/"$(basename "$0" .sh)"_"$(date '+%Y-%m-%d_%H-%M-%S')".log) 2>&1

RABBITMQ_SERVICE=$(salt -C 'I@rabbitmq:server' test.ping 1>/dev/null 2>&1 && echo true)
GALERA_SERVICE=$(salt -C 'I@galera:master or I@galera:slave' test.ping 1>/dev/null 2>&1 && echo true)
MEMCACHED_SERVICE=$(salt -C 'I@memcached:server' test.ping 1>/dev/null 2>&1 && echo true)
NGINX_SERVICE=$(salt -C 'I@nginx:server' test.ping 1>/dev/null 2>&1 && echo true)

# Install keepaliveds
salt $SALT_OPTS -C 'I@keepalived:cluster' state.sls keepalived -b 1
# Check the VIPs
salt $SALT_OPTS -C 'I@keepalived:cluster' cmd.run "ip a | grep 172.16.10.2"

# Install gluster services
salt $SALT_OPTS -C 'I@glusterfs:server' state.sls glusterfs.server.service
salt $SALT_OPTS -C 'I@glusterfs:server' state.sls glusterfs.server.setup -b 1
# Check the gluster status
salt $SALT_OPTS -C 'I@glusterfs:server' cmd.run "gluster peer status; gluster volume status" -b 1
# Configure gluster clients
salt $SALT_OPTS -C 'I@glusterfs:client' state.sls glusterfs.client

if [[ "$RABBITMQ_SERVICE" == "true" ]]; then
    # Install rabbitmq
    salt $SALT_OPTS -C 'I@rabbitmq:server' state.sls rabbitmq
    # Check the rabbitmq status
    salt $SALT_OPTS -C 'I@rabbitmq:server' cmd.run "rabbitmqctl cluster_status"
fi

if [[ "$GALERA_SERVICE" == "true" ]]; then
    # Install galera
    salt $SALT_OPTS -C 'I@galera:master' state.sls galera
    salt $SALT_OPTS -C 'I@galera:slave' state.sls galera
    # Check galera status
    salt $SALT_OPTS -C 'I@galera:master' mysql.status | grep -A1 wsrep_cluster_size
    salt $SALT_OPTS -C 'I@galera:slave' mysql.status | grep -A1 wsrep_cluster_size
fi

# Install haproxy
salt $SALT_OPTS -C 'I@haproxy:proxy' state.sls haproxy
salt $SALT_OPTS -C 'I@haproxy:proxy' service.status haproxy
salt $SALT_OPTS -I 'haproxy:proxy' service.restart rsyslog

if [[ "$MEMCACHED_SERVICE" == "true" ]]; then
    # Install memcached
    salt $SALT_OPTS -C 'I@memcached:server' state.sls memcached
fi

if [[ "$NGINX_SERVICE" == "true" ]]; then
    # Install memcached
    salt $SALT_OPTS -C 'I@nginx:server' state.sls nginx
fi
