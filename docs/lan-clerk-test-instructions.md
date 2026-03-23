# lan_clerk Test Instructions

## Prerequisites

- Working directory: `~/Desktop/sshport/`
- For remote tests: a reachable host with your SSH key authorized

---

## Local Tests (no remote needed)

### 1. Create a dummy record

```bash
echo -e "eth0 192.168.1.10\nwlan0 192.168.1.11" > testuser_interfaces.txt
```

### 2. Source the lib and test functions directly

```bash
source lan_clerk_lib.sh
```

**list_connections** — should print header and interface entries:
```bash
list_connections
```
Expected output:
```
--- testuser ---
eth0 192.168.1.10
wlan0 192.168.1.11
```

**select_host** — should show `testuser` in a numbered menu:
```bash
select_host
```

**select_iface** — should show `eth0` and `wlan0` in a numbered menu:
```bash
select_iface testuser_interfaces.txt
```

### 3. Full script walkthrough

```bash
bash lan_clerk.sh
```

- Option **3 (List connections)** → verify record prints → menu loops back
- Option **2 (Existing connection)** → pick `testuser` → pick interface → reach action menu
- `q` at any menu → exits cleanly

---

## Remote Tests (SSH target required)

Run these in order — each one gates the next.

### 1. Reachability

```bash
source lan_clerk_lib.sh
is_reachable 192.168.x.x
echo $?    # 0 = reachable, 1 = not reachable
```

### 2. Key auth

```bash
has_remote_key user 192.168.x.x
echo $?    # 0 = key accepted, 1 = failed
```

### 3. Interface scrape

```bash
get_interfaces user 192.168.x.x
cat user_interfaces.txt
```

Expected: one `iface IP` pair per line, no loopback, no CIDR suffix.
If the file is empty, SSH succeeded but the `ip` command output was unexpected — check
manually: `ssh user@192.168.x.x "ip -o -4 addr show"`.

### 4. Full new connection flow

```bash
bash lan_clerk.sh
```

- Option **1 (New connection)** → enter user + IP → `get_interfaces` runs → select interface → reach action menu
- From action menu, test **Check reachable** and **Check Samba (port 445)**

---

## Known Edge Cases

- **Empty record file**: `select_iface` will fail if pointed at an empty file. If `get_interfaces` produces an empty file, fix the SSH/parsing issue before running the full flow.
- **No records present**: Option 2 (Existing connection) will print an error and loop back to the startup menu — expected behavior.
- **Unreachable host**: `get_interfaces` should bail with an error before attempting SSH.
