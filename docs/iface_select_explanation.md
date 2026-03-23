# iface_select.sh — Code Explanation

## The `while IFS= read -r line` line

`read` reads one line from stdin and stores it in a variable. Three things are happening on that one line:

- `IFS=` — temporarily sets the Internal Field Separator to empty. Normally `read` strips leading/trailing whitespace; setting `IFS=` to nothing prevents that, preserving the line exactly as it appears in the file.
- `-r` — raw mode. Without it, backslashes in the file get interpreted as escape characters. `-r` treats them as literal characters.
- `|| [[ -n "$line" ]]` — handles the edge case where the last line of the file has no trailing newline. `read` returns a non-zero exit code at EOF, which would normally end the loop — but if there's still content in `$line`, this catches it and runs the loop body one final time.

---

## The string slicing (parameter expansion)

Given a line like: `eth0 192.168.1.5`

```bash
${line%% *}
```
`%%` means "strip the longest match of the pattern from the **right** end of the string". The pattern is ` *` — a space followed by anything. So it strips from the first space to the end, leaving just `eth0`.

```bash
${line##* }
```
`##` means "strip the longest match of the pattern from the **left** end of the string". The pattern is `* ` — anything followed by a space. So it strips from the start up through the last space, leaving just `192.168.1.5`.

---

## Visual summary

```
line = "eth0 192.168.1.5"
         ^    ^
         |    |
${line%% *}   strips everything from first space rightward  → eth0
${line##* }   strips everything up through last space       → 192.168.1.5
```

`%` and `%%` work from the right. `#` and `##` work from the left. Single (`%`, `#`) matches the shortest pattern; double (`%%`, `##`) matches the longest.
