# Split VPN Manager

Simple script to manage vpn inside net namespaces and run programs inside of them.

> Currently only supports openvpn, but wireguard and openconnect are in my plans.

## Usage

```
Usage:
  ./split-vpn-manager.sh launch_openvpn --name NETNS_NAME --config CONFIG_FILE --auth AUTH_FILE
      starts a vpn connection and create the net namespace

  ./split-vpn-manager.sh run NETNS_NAME CMD
      runs a command in the specified net namespace

NOTE: Always run this script with privileged permissions (currently not)
```

## Exit codes

```
EXIT_SUCCESS=0
EXIT_INVALID_COMMAND=1
EXIT_INVALID_ARGS=2
EXIT_MISSING_VALID_ARG=3
EXIT_NOT_ROOT=4
EXIT_FILE_DOESNOT_EXISTS=5
EXIT_NOT_ENOUGH_ARGS=6
```

