#!/bin/sh

EXIT_SUCCESS=0
EXIT_INVALID_COMMAND=1
EXIT_INVALID_ARGS=2
EXIT_MISSING_VALID_ARG=3
EXIT_NOT_ROOT=4
EXIT_FILE_DOESNOT_EXISTS=5
EXIT_NOT_ENOUGH_ARGS=6

split_vpn_manager=$0
command=$1
shift

root_or_exit() {
    root_or_exit_message=$1

    user_id="$(id -u)"
    if [ "$user_id" -ne 0 ]; then
        echo "$root_or_exit_message"
        exit $EXIT_NOT_ROOT
    fi
}

assert_args() {
    arg_name=$1
    min_args=$2
    args_count=$3

    if [ "$min_args" -gt "$args_count" ]; then
        echo "Not enough args for $arg_name in command $command"
        exit $EXIT_NOT_ENOUGH_ARGS
    fi
}

assert_file() {
    file_desc=$1
    file=$2
    if [ -z "$file" ]; then
        echo "Missing $file_desc file"
        exit $EXIT_MISSING_VALID_ARG
    else
        if [ ! -f "$file" ]; then
            echo "File does not exist: $file"
            exit $EXIT_FILE_DOESNOT_EXISTS
        fi
    fi
}

launch_openvpn() {
    root_or_exit "Need to be root in order to run $command"

    while [ $# -gt 0 ]; do
        arg_name=$1
        shift

        case $arg_name in
            --config)
                assert_args --config 1 $#
                openvpn_config=$1
                ;;
            --auth)
                assert_args --auth 1 $#
                openvpn_auth=$1
                ;;
            --name)
                assert_args --auth 1 $#
                openvpn_name=$1
                ;;
            *)
                echo "Invalid args for command $command: $arg_name"
                exit $EXIT_INVALID_ARGS
                ;;
        esac

        shift
    done

    assert_file "openvpn config" "$openvpn_config"
    assert_file "openvpn auth" "$openvpn_auth"
    if [ -z "$openvpn_name" ]; then echo "Missing vpn name in $command" && exit $EXIT_MISSING_VALID_ARG; fi

    openvpn \
        --auth-nocache --script-security 2 --route-nopull --redirect-gateway \
        --ifconfig-noexec --route-noexec \
        --up "$split_vpn_manager up-netns $openvpn_name" --down "$split_vpn_manager down-netns $openvpn_name" \
        --config "$openvpn_config" \
        --mute-replay-warnings \
        --auth-user-pass "$openvpn_auth"

    exit $EXIT_SUCCESS
}

up_netns() {
    netns_name=$1
    shift

    ip netns add "$netns_name"

    ip netns exec "$netns_name" ip link set dev lo up

    ip link set dev "$1" up netns "$netns_name" mtu "$2"

    ip netns exec "$netns_name" ip addr add dev "$1" \
        "$4/${ifconfig_netmask:-30}" \
        ${ifconfig_broadcast:+broadcast "${ifconfig_broadcast}"}

    if [ -n "$ifconfig_ipv6_local" ]; then
          ip netns exec "$netns_name" ip addr add dev "$1" \
                  "$ifconfig_ipv6_local/112"
    fi

    ip netns exec "$netns_name" ip route add default via "$route_vpn_gateway"

    echo "nameserver 8.8.8.8" | resolvconf -x -a "$1.inet"

    exit $EXIT_SUCCESS
}

down_netns() {
    netns_name=$1
    shift

    ip netns delete "$netns_name"

    exit $EXIT_SUCCESS
}

run() {
    root_or_exit "Need to be too in order to run inside a namespace"

    assert_args "vpn name" 1 $#
    netns_name=$1
    shift

    assert_args "running" 1 $#

    ip netns exec "$netns_name" sudo -u "$SUDO_USER" "$@"

    exit $EXIT_SUCCESS
}

help() {
    echo "Usage:"
    echo "  $0 launch_openvpn --name NETNS_NAME --config CONFIG_FILE --auth AUTH_FILE"
    echo "      starts a vpn connection and create the net namespace"
    echo ""
    echo "  $0 run NETNS_NAME CMD"
    echo "      runs a command in the specified net namespace"
    echo ""

    user_id="$(id -u)"
    if [ "$user_id" -ne 0 ]; then
        echo "NOTE: Always run this script with privileged permissions (currently not)"
    else
        echo "NOTE: Always run this script with privileged permissions"
    fi


}

case "$command" in
    launch_openvpn)
        launch_openvpn "$@";;
    up-netns)
        up_netns "$@";;
    down-netns)
        down_netns "$@";;
    run)
        run "$@";;
    help|--help)
        help;;
    *)
        echo "Invalid command: $command"
        exit $EXIT_INVALID_COMMAND
        ;;
esac

