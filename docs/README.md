# lan-clerk

Bash SSH connection manager for LAN hosts. Discovers remote interfaces, checks reachability, and probes Samba availability. Works on Linux and Windows remotes.

## Requirements

- Passwordless SSH key auth on the remote host
- `nc` (netcat) for port checks
- `iconv` and `base64` for Windows remote support

## Usage

```bash
bash lan_clerk.sh
```

On first run, use **New connection** to enter a username and IP. `lan-clerk` will verify the host is reachable, confirm key auth works, scrape the remote's network interfaces, and save a record locally. On subsequent runs, use **Existing connection** to load a saved record.

After selecting a host and interface, you can:

- Check if the IP is reachable (ICMP ping)
- Check if Samba is available on port 445
- Refresh the interface record from the remote

## How it works

`lan_clerk.sh` is the entry point. All logic lives in `lan_clerk_lib.sh`.

| Function | What it does |
|---|---|
| `is_reachable` | Pings a host; optionally probes a port with `nc` |
| `has_remote_key` | Tests key auth via `ssh -o BatchMode=yes` — fails fast if no key |
| `get_interfaces` | SSHes in, detects OS (Unix vs Windows), scrapes IPv4 interfaces, saves to `<user>_interfaces.txt` |
| `select_host` | Interactive menu to pick a saved interface record |
| `select_iface` | Pings each interface, shows up/down status, returns the chosen IP |
| `list_connections` | Prints all saved records |

Windows hosts are detected by the absence of `uname`. Interface data is retrieved via PowerShell `Get-NetIPAddress`, base64-encoded to avoid SSH/shell quoting issues.

## Records

Interface records are saved as `<username>_interfaces.txt` in the working directory. Each line is `ifacename ip`. These files are gitignored — they contain your local network topology.

## Testing

See [lan-clerk-test-instructions.md](lan-clerk-test-instructions.md) for local (no remote needed) and remote test procedures.
