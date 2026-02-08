#!/bin/bash
RELAY_PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

load_env() {
	if [[ ! -f "$RELAY_PROJECT_DIR/.env" ]]; then
		echo "Error: .env file not found in $RELAY_PROJECT_DIR"
		return 1
	fi
	source "$RELAY_PROJECT_DIR/.env"
	return 0
}

parse_relay_entries() {
	RELAY_ENTRIES=()
	for key in $(printf '%s\n' "${!RELAY_@}" | grep -E '^RELAY_[0-9]+$' | sort -V); do
		value="${!key}"
		IFS=',' read -r in_port out_port out_host <<< "$value"
		if [[ -n "$in_port" && -n "$out_port" && -n "$out_host" ]]; then
			RELAY_ENTRIES+=("$in_port:$out_port:$out_host")
		fi
	done
}

check_target() {
	local host="$1"
	local port="$2"
	local timeout="${3:-5}"
	if timeout "$timeout" bash -c "echo -n '' > /dev/tcp/$host/$port" 2>/dev/null; then
		return 0
	else
		return 1
	fi
}
