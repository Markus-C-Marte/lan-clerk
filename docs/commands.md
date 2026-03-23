**Network / Connectivity**
- `ping` — ICMP reachability check (`-c 1 -W 2`)
  - `lan_clerk_lib.sh:9` — `is_reachable()`, primary host check
  - `if ! ping -c 1 -W 2 "$ip" > /dev/null 2>&1; then`
- `nc` — port check via netcat (`-zv`)
  - `lan_clerk_lib.sh:15` — `is_reachable()`, optional port probe
  - `if timeout 2 nc -zv "$ip" "$port" > /dev/null 2>&1; then`
- `timeout` — wraps `nc` with a 2s deadline
  - `lan_clerk_lib.sh:15` — wraps `nc` call in `is_reachable()`
  - `if timeout 2 nc -zv "$ip" "$port" > /dev/null 2>&1; then`

**SSH / Remote**
- `ssh` — key-auth remote execution (BatchMode, no password)
  - `lan_clerk_lib.sh:29` — `has_remote_key()`, tests key auth
  - `ssh -o BatchMode=yes -o PasswordAuthentication=no -o ConnectTimeout=5 "${user}@${ip}" exit > /dev/null 2>&1`
- `powershell` — invoked on remote Windows hosts via SSH (`-EncodedCommand`)
  - `lan_clerk_lib.sh:65` — remote command on Windows inside `get_interfaces()`
  - `ssh ... "${user}@${ip}" "powershell -NoProfile -EncodedCommand ${encoded}"`

**Remote host commands (run over SSH)**
- `uname -s` — OS detection on Unix remotes
  - `lan_clerk_lib.sh:53` — determines Unix vs Windows branch in `get_interfaces()`
  - `os=$(ssh -o BatchMode=yes -o ConnectTimeout=5 "${user}@${ip}" "uname -s" 2>/dev/null)`
- `ip -o -4 addr show` — list IPv4 interfaces on Unix remotes
  - `lan_clerk_lib.sh:74` — Unix branch of `get_interfaces()`
  - `ssh ... "${user}@${ip}" "ip -o -4 addr show"`
- `Get-NetIPAddress` (PowerShell) — list IPv4 interfaces on Windows remotes
  - `lan_clerk_lib.sh:62` — Windows branch of `get_interfaces()`, embedded in `$ps_script`
  - `local ps_script='Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -ne "127.0.0.1"} | ...'`

**Text processing**
- `awk` — parses `ip addr` output, strips loopback, extracts interface/IP
  - `lan_clerk_lib.sh:75` — post-processes Unix SSH output in `get_interfaces()`
  - `awk '$2 != "lo" { split($4,a,"/"); print $2, a[1] }'`
- `iconv` — converts PowerShell script to UTF-16LE for `-EncodedCommand`
  - `lan_clerk_lib.sh:64` — encodes `$ps_script` in Windows branch of `get_interfaces()`
  - `encoded=$(printf '%s' "$ps_script" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)`
- `base64` — encodes the converted PowerShell script
  - `lan_clerk_lib.sh:64` — piped after `iconv` to produce `$encoded`
  - `encoded=$(printf '%s' "$ps_script" | iconv -f UTF-8 -t UTF-16LE | base64 -w 0)`
- `tr` — strips carriage returns from Windows SSH output; fills separator line
  - `lan_clerk_lib.sh:67` — strips `\r` from Windows SSH output
  - `| tr -d '\r'`

**Terminal**
- `tput cols` — gets terminal width for separator line
  - `lan_clerk_lib.sh:105` — used in `select_host()` to size the separator
  - `sep=$(printf '%*s' "$(tput cols 2>/dev/null || echo 40)" '' | tr ' ' '-')`
- `compgen -G` — glob expansion for `*_interfaces.txt` files
  - `lan_clerk_lib.sh:90` — populates `$files` in `select_host()`
  - `mapfile -t files < <(compgen -G "*_interfaces.txt" 2>/dev/null)`

**Bash builtins**
- `select` — interactive numbered menu
  - `lan_clerk.sh:10` — top-level option menu
  - `select opt in "New connection" "Existing connection" "List connections" "Quit"; do`
- `mapfile` — reads lines into an array
  - `lan_clerk_lib.sh:90` — populates `$files` in `select_host()`
  - `mapfile -t files < <(compgen -G "*_interfaces.txt" 2>/dev/null)`
- `read` — reads a single line of user input
  - `lan_clerk.sh:14` — prompts for `user` in "New connection" flow
  - `read -rp "User: " user`
- `case` — pattern-matched branching
  - `lan_clerk.sh:11` — dispatches top-level menu selection
  - `case "$REPLY" in`
- `printf` — formatted output
  - `lan_clerk_lib.sh:105` — builds separator string
  - `sep=$(printf '%*s' "$(tput cols 2>/dev/null || echo 40)" '' | tr ' ' '-')`
