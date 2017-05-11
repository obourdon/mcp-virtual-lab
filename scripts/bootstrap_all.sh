#!/bin/bash -x

CWD="$(dirname "$(readlink -f "$0")")"

export SALT_OPTS=${SALT_OPTS:-"--state-output=changes --state-verbose=False"}

K8S_BOOTSTRAP=$(salt -C 'I@kubernetes:master' test.ping 1>/dev/null 2>&1 && echo true)
OPENSTACK_BOOTSTRAP=$(salt -C 'I@nova:controller' test.ping 1>/dev/null 2>&1 && echo true)
OPENCONTRAIL_BOOTSTRAP=$(salt -C 'I@opencontrail:control' test.ping 1>/dev/null 2>&1 && echo true)
STACKLIGHTV2_BOOTSTRAP=$(salt -C 'I@prometheus:server' test.ping 1>/dev/null 2>&1 && echo true)

"$CWD"/config_verify.sh
"$CWD"/infra_install.sh
"$CWD"/core_services_install.sh
if [[ "$STACKLIGHTV2_BOOTSTRAP" == "true" ]]; then
    "$CWD"/docker_swarm_install.sh
fi
if [[ "$K8S_BOOTSTRAP" == "true" ]]; then
    "$CWD"/kubernetes_install.sh
fi
if [[ "$OPENSTACK_BOOTSTRAP" == "true" ]]; then
    "$CWD"/openstack_control_install.sh
    "$CWD"/stacklight_infra_install.sh
    if [[ "$OPENCONTRAIL_BOOTSTRAP" == "true" ]]; then
        "$CWD"/opencontrail_control_install.sh
        "$CWD"/opencontrail_compute_install.sh
    else
        "$CWD"/ovs_compute_install.sh
    fi
    "$CWD"/stacklight_monitor_install.sh
fi
if [[ "$STACKLIGHTV2_BOOTSTRAP" == "true" ]]; then
    "$CWD"/stacklightv2_infra_install.sh
fi
