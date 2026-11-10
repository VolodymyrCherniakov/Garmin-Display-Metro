#!/bin/sh
set -eu

metro_tools_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
metro_sdk_config="${HOME}/.Garmin/ConnectIQ/current-sdk.cfg"

if [ ! -r "$metro_sdk_config" ]; then
    printf '%s\n' "Cannot find the selected Connect IQ SDK: $metro_sdk_config" >&2
    exit 1
fi
metro_sdk_dir=$(tr -d '\r\n' < "$metro_sdk_config")
if [ ! -x "$metro_sdk_dir/bin/connectiq" ]; then
    printf '%s\n' "Cannot find connectiq in the selected SDK: $metro_sdk_dir" >&2
    exit 1
fi

# Keep the font workaround local to the simulator process and its children.
export FONTCONFIG_FILE="$metro_tools_dir/simulator-fonts.conf"
export GDK_BACKEND=x11
exec "$metro_sdk_dir/bin/connectiq" "$@"
