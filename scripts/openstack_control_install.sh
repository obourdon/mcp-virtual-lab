#!/bin/bash -x
exec > >(tee -i /tmp/"$(basename "$0" .sh)"_"$(date '+%Y-%m-%d_%H-%M-%S')".log) 2>&1

# setup keystone service
salt $SALT_OPTS -C 'I@keystone:server' state.sls keystone.server -b 1
# populate keystone services/tenants/admins
salt $SALT_OPTS -C 'I@keystone:client' state.sls keystone.client
# salt-minion should be restarted in case keystone.client has changed the Salt configuration
salt $SALT_OPTS -C 'I@keystone:client' --async service.restart salt-minion; sleep 5
salt $SALT_OPTS -C 'I@keystone:server' cmd.run ". /root/keystonerc; openstack service list"

# Install glance
salt $SALT_OPTS -C 'I@glance:server' state.sls glance -b 1
# Update fernet tokens before doing request on keystone server. Otherwise
# you will get an error like:
# "No encryption keys found; run keystone-manage fernet_setup to bootstrap one"
salt $SALT_OPTS -C 'I@keystone:server' state.sls keystone.server
salt $SALT_OPTS -C 'I@keystone:server' cmd.run ". /root/keystonerc; glance image-list"

# Install nova service
salt $SALT_OPTS -C 'I@nova:controller' state.sls nova -b 1
salt $SALT_OPTS -C 'I@keystone:server' cmd.run ". /root/keystonerc; nova service-list"

# Install cinder service
salt $SALT_OPTS -C 'I@cinder:controller' state.sls cinder -b 1
salt $SALT_OPTS -C 'I@keystone:server' cmd.run ". /root/keystonerc; cinder list"

# Install neutron service
salt $SALT_OPTS -C 'I@neutron:server' state.sls neutron -b 1
salt $SALT_OPTS -C 'I@neutron:gateway' state.sls neutron
salt $SALT_OPTS -C 'I@keystone:server' cmd.run ". /root/keystonerc; neutron agent-list"

# Install heat service
salt $SALT_OPTS -C 'I@heat:server' state.sls heat -b 1
salt $SALT_OPTS -C 'I@keystone:server' cmd.run ". /root/keystonerc; heat resource-type-list"

# Install horizon dashboard
salt $SALT_OPTS -C 'I@horizon:server' state.sls horizon
salt $SALT_OPTS -C 'I@nginx:server' state.sls nginx

# Install ceilometer services
#salt $SALT_OPTS -C 'I@ceilometer:server' state.sls ceilometer -b 1

# Install aodh services
#salt $SALT_OPTS -C 'I@aodh:server' state.sls aodh -b 1

# Create the Nova resources (if any)
salt $SALT_OPTS -C 'I@nova:client' state.sls nova
