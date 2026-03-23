# Lan Clerk

## Purpose
purpose is to keep track of and acquire known client 
interfaces and addresses, also intended to portt check and status check connections, 
specifically in case ThinkPad undocs removing its access to the local file server, rendering mounted Samba drives unavailable.

## NOTE
Local capture on remote execution. Some data 
requires code to be ran from local on remote and 
stored on local. This requires SSH key and pass 
wordless remote login.

___ 
Methods Required to proceed.
___
- [ ]  [[./is_reachable.sh]] ${1:IP, 2:Port} 
  - will call is_servicing if self is true and $2 exists 
- [ ] is_Servicing ${1:IP 2:Port}
  - checks if specific port is open and listening (use for samba port: 445)
- [ ] has_Remote-Key ${1:USER 2:IP} 
  - `ssh -o passwordAuthentication=no` forces keyauth, fail status indicates lack of key
- [ ] get_Interfaces ${1:USER 2:IP} 
  - requires has_Remote-Key = True

---
More Methods/Procedure Suggestions
___
1. Get interfacees/ Make Record
  - After get interfaces returns data:
    awk it make a file with ifaces and addrs for server
    ( Use This afterwards to)
