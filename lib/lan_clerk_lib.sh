#!/usr/bin/env bash

SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/lan_clerk"
mkdir -p "$SHARE_DIR"

ip_to_int() {
    local IFS='.'
    read -r a b c d <<< "$1"
    echo $(( (a << 24) + (b << 16) + (c << 8) + d ))
}

cidr_mask() {
    echo $(( 0xFFFFFFFF << (32 - $1) & 0xFFFFFFFF ))
}

same_subnet() {
    local remote_ip="$1"
    local remote_int
    remote_int=$(ip_to_int "$remote_ip")

    while IFS= read -r line; do
        local cidr
        cidr=$(awk '{print $4}' <<< "$line")
        local local_ip="${cidr%/*}"
        local prefix="${cidr#*/}"
        local local_int mask
        local_int=$(ip_to_int "$local_ip")
        mask=$(cidr_mask "$prefix")
        if (( (local_int & mask) == (remote_int & mask) )); then
            return 0
        fi
    done < <(ip -o -4 addr show | grep -v ' lo ')
    return 1
}

is_reachable() {
    # $1=IP  $2=port
    local ip="$1"
    local port="$2"

    # Ping IP                        # start fail
    if ! ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then
        return 1
    fi

    # Port provided
    if [[ -n "$port" ]]; then
        if timeout 2 nc -zv "$ip" "$port" > /dev/null 2>&1; then
            return 0  # passes before timeout
        else
            return 1  # port issue
        fi
    fi

    # no port provided, ping succeeded
    return 0
}

has_remote_key() {
    # $1=user  $2=ip
    # BatchMode=yes disables interactive prompts so a missing key fails immediately
    # rather than hanging on a password prompt.
    # PasswordAuthentication=no forces key-only auth; any failure means no key.
    # The remote command is just `exit` — success means key auth worked.
    local user="$1"
    local ip="$2"
    ssh -o BatchMode=yes \
        -o PasswordAuthentication=no \
        -o ConnectTimeout=5 \
        "${user}@${ip}" exit > /dev/null 2>&1
}

get_interfaces() {
    local user="$1"
    local ip="$2"
    local outfile="${SHARE_DIR}/${user}_interfaces.txt"

    if ! is_reachable "$ip"; then
        echo "get_interfaces: ${ip} is not reachable" >&2
        return 1
    fi

    if ! has_remote_key "$user" "$ip"; then
        echo "get_interfaces: key auth failed for ${user}@${ip}" >&2
        return 1
    fi

    # Detect OS: uname -s returns "Linux"/"Darwin" etc. on Unix; on Windows it's
    # not available, so the command fails silently and os comes back empty.
    local os
    os=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${ip}" "uname -s" 2>/dev/null)

    if [[ -z "$os" ]]; then
        # Windows host: uname unavailable.
        # Get-NetIPAddress lists IPv4 interfaces; filter loopback and format as
        # "InterfaceName IP" per line. Spaces in interface names are replaced with
        # underscores so downstream parsing (select_iface) works correctly.
        # The script is base64-encoded UTF-16LE and passed via -EncodedCommand to
        # avoid the quoting nightmare of passing PowerShell through bash -> SSH -> cmd.exe.
        local ps_script='Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -ne "127.0.0.1"} | ForEach-Object {($_.InterfaceAlias -replace " ","_") + " " + $_.IPAddress}'
        local encoded
        encoded=$(printf '%s' "$ps_script" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)
        ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${ip}" \
            "powershell -NoProfile -EncodedCommand ${encoded}" \
        | tr -d '\r' \
        > "$outfile"
    else
        # Unix host: use ip(8) to list IPv4 addresses, strip loopback.
        ssh -o BatchMode=yes \
            -o ConnectTimeout=5 \
            "${user}@${ip}" \
            "ip -o -4 addr show" \
        | awk '$2 != "lo" { split($4,a,"/"); print $2, a[1] }' \
        > "$outfile"
    fi
}

select_host() {
    clear >/dev/tty
    echo "Select host:" >/dev/tty
    # Declare two empty arrays: files will hold raw filenames, names will hold display labels
    local -a files names

    # compgen -G expands a glob and prints each match on its own line.
    # mapfile -t reads those lines into the files array (-t strips the trailing newline from each).
    # Process substitution < <(...) feeds compgen's stdout as a file for mapfile to read.
    # 2>/dev/null silences the error compgen emits when the glob matches nothing.
    mapfile -t files < <(compgen -G "${SHARE_DIR}/*_interfaces.txt" 2>/dev/null)

    # ${#files[@]} is the length of the array. If zero, no records exist — bail out.
    if [[ ${#files[@]} -eq 0 ]]; then
        echo "select_host: no interface records found" >&2
        return 1
    fi

    # Build the display names by stripping the _interfaces.txt suffix from each filename.
    # ${f%_interfaces.txt} uses % to remove the shortest match of the pattern from the right.
    for f in "${files[@]}"; do
        names+=("$(basename "${f%_interfaces.txt}")")
    done

    local sep
    sep=$(printf '%*s' "$(tput cols 2>/dev/null || echo 40)" '' | tr ' ' '-')

    echo >/dev/tty
    # PS3 is the prompt string the select builtin prints before each input prompt.
    local PS3="${sep}"$'\n'"Select host (q to quit): "
    local name COLUMNS=1
    # select builds a numbered menu from names[]. On each iteration:
    #   $name  = the matched element, or empty if input didn't match a number
    #   $REPLY = the raw string the user typed
    select name in "${names[@]}"; do
        case "$REPLY" in
            q) return 1 ;;
            *)
                if [[ -n "$name" ]]; then
                    # Valid pick — reconstruct the filename and print it to stdout
                    # so the caller can capture it with $()
                    echo "${name}_interfaces.txt"
                    return 0
                else
                    # $name is empty — $REPLY wasn't a valid menu number
                    # No return/break, so select loops and reprints the menu
                    echo "Invalid entry." >&2
                fi
                ;;
        esac
    done
}

list_connections() {
    # Prints all saved interface records to stdout, one host at a time.
    local -a files
    mapfile -t files < <(compgen -G "${SHARE_DIR}/*_interfaces.txt" 2>/dev/null)

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "No records found." >&2
        return 1
    fi

    for f in "${files[@]}"; do
        echo "--- $(basename "${f%_interfaces.txt}") ---"
        cat "$f"
    done
}

select_iface() {
    # $1=interfaces file (format: "ifacename ip" per line)
    # Pings each interface, shows up/down status, and returns the chosen IP on stdout.
    clear >/dev/tty
    local file="$1"
    local -a ifaces ips

    # IFS= prevents leading/trailing whitespace being stripped.
    # || [[ -n "$line" ]] handles files that don't end with a newline.
    # %% * strips everything from the first space rightward (interface name).
    # ##*  strips everything up to and including the last space (IP address).
    while IFS= read -r line || [[ -n "$line" ]]; do
        ifaces+=("${line%% *}")
        ips+=("${line##* }")
    done < "$file"

    echo "Pinging interfaces..." >&2
    local -a labels
    local i status
    for i in "${!ifaces[@]}"; do
        is_reachable "${ips[$i]}" && status="up" || status="down"
        labels+=("${ifaces[$i]} (${ips[$i]}) [${status}]")
    done

    local sep
    sep=$(printf '%*s' "$(tput cols 2>/dev/null || echo 40)" '' | tr ' ' '-')

    echo >/dev/tty
    local PS3="${sep}"$'\n'"Select interface (q to quit): "
    local iface COLUMNS=1
    select iface in "${labels[@]}"; do
        case "$REPLY" in
            q) return 1 ;;
            *)
                if [[ -n "$iface" ]]; then
                    # select's REPLY is 1-based; arrays are 0-based.
                    local idx=$(( REPLY - 1 ))
                    echo "${ips[$idx]}"
                    return 0
                else
                    echo "Invalid entry." >&2
                fi
                ;;
        esac
    done
}
