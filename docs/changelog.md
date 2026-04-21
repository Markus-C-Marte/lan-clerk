# Changelog

## 2026-04-21

### Docs cleanup
Removed superfluous documentation files:
- `commands.md` — per-command index with stale line references, derivable from the code
- `iface_select_explanation.md` — generic bash tutorial, not project-specific
- `psuedo.md` — early planning pseudocode, superseded by implementation
- `old_notes.txt` — raw scratch notes from development

Added `.gitignore` to track remaining borderline docs (`implementation-plan.md`, `Reformatted.md`, `lan-clerk-test-instructions.md`) without committing them.

## 2026-04-20

### Project restructure
Reorganized codebase into standard layout:
- `bin/lan_clerk` — executable entry point
- `lib/lan_clerk_lib.sh` — shared library functions
- `docs/` — documentation (changelog, notes, configuration examples)

All existing functionality preserved. 
Changes to bin/lan_clerk and lib/lan_clerk_lib.sh are pending commit.

## 2026-03-23

### SSH action
Added "SSH" option to the action menu. 
After selecting a host and interface, 
you can now open an interactive SSH session directly. 
The connection is gated behind reachability and subnet checks before attempting.

### Subnet-aware connectivity checks
All reachability actions (SSH, ping, Samba probe) 
now verify that the local machine has an interface 
on the same subnet as the target IP before attempting a check. 
This prevents false negatives when testing across network boundaries 
(e.g. pinging a Tailscale IP from a LAN interface).

Uses CIDR-based matching: local interfaces are read via `ip -o -4 addr show`, and both local and remote IPs are compared using their subnet masks. If no local interface shares a subnet with the target, the action is skipped with a warning.

**New functions in `lan_clerk_lib.sh`:**
- `ip_to_int(ip)` -- converts dotted-quad IP to 32-bit integer
- `cidr_mask(prefix)` -- converts CIDR prefix length to bitmask `same_subnet(remote_ip)` -- returns 0 if any local interface shares a subnet with the given IP
