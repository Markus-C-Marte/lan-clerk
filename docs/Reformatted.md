# lan_clerk — Restructure Reference

---

## Why This Was Done

lan_clerk started as a flat collection of files in `~/Desktop/sshport/`. Everything
lived in one directory with no separation between the executable script, the library
it depended on, documentation, and generated data files. That works fine while you're
developing something in isolation, but it creates problems the moment you want to run
it from anywhere, deploy it cleanly, or manage it alongside other tools.

The program was moved into `~/Dotfiles/lan_clerk/` and given a structured layout
because:

- Dotfiles is the correct home for custom tools you maintain long-term
- The structured layout mirrors how installed software is organized on Unix systems,
  making it compatible with deployment tools like GNU Stow
- Separating source code from generated data prevents the program from scattering
  files wherever you happen to run it from

---

## What GNU Stow Is and Why It Matters

GNU Stow is a symlink manager. It takes a package directory (like `lan_clerk/`) and
mirrors its structure into a target directory by creating symlinks for each file. You
do not copy anything — every file stays in your Dotfiles repo. Stow just makes them
appear in the right places so the system can find them.

Stow's default target is the parent of the stow directory. If you run `stow` from
`~/Dotfiles/`, the default target is `~` — which would create `~/bin/` and `~/lib/`
in your home directory. To deploy into `~/.local/` instead, you must pass `-t ~/.local`
explicitly.

Example: when you run `stow -t ~/.local lan_clerk` from inside `~/Dotfiles/`, Stow sees:

```
Dotfiles/lan_clerk/bin/lan_clerk.sh
Dotfiles/lan_clerk/lib/lan_clerk_lib.sh
```

And creates:

```
~/.local/bin/lan_clerk.sh    ->  ~/Dotfiles/lan_clerk/bin/lan_clerk.sh
~/.local/lib/lan_clerk_lib.sh  ->  ~/Dotfiles/lan_clerk/lib/lan_clerk_lib.sh
```

`~/.local/bin/` is typically in your PATH, so after stowing, typing `lan_clerk`
anywhere in the terminal will find and run the script. The actual file never moves —
only a symlink is placed in `~/.local/bin/`.

This is the standard way to deploy personal tools from a Dotfiles repo without
polluting your source tree or manually managing PATH entries.

---

## Before and After: File Placement

### Before (flat layout in ~/Desktop/sshport/)

```
~/Desktop/sshport/
    lan_clerk.sh           <- main script and library mixed in same dir
    lan_clerk_lib.sh
    lenti_interfaces.txt   <- generated data files mixed in with source
    serv_interfaces.txt
    sshd_config            <- reference config with no clear home
    commands.md
    README.md
    psuedo.md
    ... (other docs)
```

Problems:
- No distinction between source files, library files, docs, and generated data
- Running the script from any other directory would fail to find the library
- Generated interface files scattered to whatever directory you ran the script from
- No path for Stow or any other deployment tool to follow

### After (structured layout in ~/Dotfiles/lan_clerk/)

```
~/Dotfiles/lan_clerk/
    bin/
        lan_clerk.sh           <- entry point (the script you run)
    lib/
        lan_clerk_lib.sh       <- library (functions sourced by the main script)
    docs/
        README.md
        commands.md
        psuedo.md
        iface_select_explanation.md
        lan-clerk-test-instructions.md
        sshd_config            <- reference config file (not a script, lives in docs)
```

Generated data (interface records) no longer live in the project at all — they go
to the XDG data directory at runtime (explained below).

### After Stow: symlinks in ~/.local/

```
~/.local/bin/lan_clerk.sh      ->  ~/Dotfiles/lan_clerk/bin/lan_clerk.sh
~/.local/lib/lan_clerk_lib.sh  ->  ~/Dotfiles/lan_clerk/lib/lan_clerk_lib.sh
```

Generated data at runtime:
```
~/.local/share/lan_clerk/
    lenti_interfaces.txt       <- written here by get_interfaces()
    serv_interfaces.txt
```

---

## What Did and Did Not Make It Into the New Layout

| Item | Old location | New location | Notes |
|---|---|---|---|
| Main script | `sshport/lan_clerk.sh` | `bin/lan_clerk.sh` | Entry point |
| Library | `sshport/lan_clerk_lib.sh` | `lib/lan_clerk_lib.sh` | Sourced by bin |
| All docs | `sshport/*.md` | `docs/*.md` | Unchanged content |
| sshd_config | `sshport/sshd_config` (later project root) | `docs/sshd_config` | Reference file only, not a script |
| Generated `.txt` files | `sshport/` (or wherever you ran the script) | `~/.local/share/lan_clerk/` | Runtime data, not source — does NOT live in Dotfiles |
| `share/` directory | Created during restructure | Removed | Originally planned for generated files, replaced by XDG |

The `share/` directory was created during the initial restructure as a home for
generated interface files, but was removed when the decision was made to use the
XDG data directory instead. The distinction is important: `share/` inside a Dotfiles
project is still part of your source repo. Runtime data that changes every time you
use the program does not belong there.

---

## What Changed in the Scripts

Two bugs existed that would have broken the program in the new layout. Both were fixed.

### Bug 1: The library could not be found

The original source line in `bin/lan_clerk.sh` was:

```bash
source "$(dirname "${BASH_SOURCE[0]}")/lan_clerk_lib.sh"
```

`BASH_SOURCE[0]` is the path of the currently running script. `dirname` strips the
filename, leaving just the directory. In the old flat layout, the library was in the
same directory as the script, so this worked. In the new layout the library is in
`lib/`, one level up and over from `bin/`, so this looked for
`bin/lan_clerk_lib.sh` which does not exist.

Fix — compute the real directory and navigate to `../lib/`:

```bash
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
source "${SCRIPT_DIR}/../lib/lan_clerk_lib.sh"
```

`readlink -f` is explained in the next section. `cd ... && pwd` converts the path
to an absolute canonical form.

### Bug 2: Generated files scattered to the working directory

In `lib/lan_clerk_lib.sh`, `get_interfaces()` wrote the interface record like this:

```bash
local outfile="${user}_interfaces.txt"
```

This is a bare filename with no directory prefix, so it writes to wherever your
shell is currently sitting when you run the script. If you ran it from `~/`, the
file appeared in `~/`. If you ran it from `/tmp`, it appeared there.
`select_host()` and `list_connections()` had the same problem — they globbed for
`*_interfaces.txt` in the current directory, so they could only find files if you
ran the script from the same directory every time.

Fix — use `SHARE_DIR` (an absolute path set at the top of the lib):

```bash
local outfile="${SHARE_DIR}/${user}_interfaces.txt"
```

And in the glob functions:
```bash
mapfile -t files < <(compgen -G "${SHARE_DIR}/*_interfaces.txt" 2>/dev/null)
```

---

## The Symlink Problem: Why readlink -f Is Needed

This is the subtlest issue and the most important one to understand when using Stow.

When Stow creates `~/.local/bin/lan_clerk.sh`, that file is a symlink. It points
back to `~/Dotfiles/lan_clerk/bin/lan_clerk.sh`. When you type `lan_clerk` in your
terminal and bash runs it, bash follows the symlink to the real file.

The problem: `BASH_SOURCE[0]` gives you the path of the symlink, not the real file.
So without any special handling:

```
You type:         lan_clerk
Bash runs:        ~/.local/bin/lan_clerk.sh   (the symlink)
BASH_SOURCE[0] =  ~/.local/bin/lan_clerk.sh
dirname gives:    ~/.local/bin/
../lib/ resolves: ~/.local/lib/               (the Stow'd symlink — fine)
../share/ would:  ~/.local/share/             (the system XDG dir — wrong)
```

`readlink -f` resolves a symlink all the way down to the actual file on disk:

```
readlink -f ~/.local/bin/lan_clerk.sh
-> /home/saph/Dotfiles/lan_clerk/bin/lan_clerk.sh
```

So after `readlink -f`, `dirname` gives `~/Dotfiles/lan_clerk/bin/`, and `../lib/`
correctly points into the Dotfiles project. This is why it is used in `SCRIPT_DIR`.

For `SHARE_DIR` (where generated data lives), `readlink -f` is not used — the XDG
path is an absolute location independent of where the script lives, so no resolution
is needed.

---

## XDG Base Directory Variables

XDG (the cross-desktop group) defines a standard set of environment variables that
specify where different categories of user data should be stored. Applications are
expected to respect these rather than hardcoding paths like `~/.myapp/`. This keeps
your home directory predictable and makes it easy to override locations if needed
(e.g., if your home directory is on a small partition and you want data elsewhere).

| Variable | Default if unset | Purpose |
|---|---|---|
| `$XDG_DATA_HOME` | `~/.local/share` | Persistent application data |
| `$XDG_CONFIG_HOME` | `~/.config` | Configuration files |
| `$XDG_CACHE_HOME` | `~/.cache` | Expendable cached data (safe to delete) |
| `$XDG_STATE_HOME` | `~/.local/state` | State that persists but is not config (logs, history) |
| `$XDG_RUNTIME_DIR` | Set by login session (e.g. `/run/user/1000`) | Temporary runtime files (sockets, locks) |

The pattern for using these in scripts is to always provide a fallback in case the
variable is not set in the user's environment:

```bash
"${XDG_DATA_HOME:-$HOME/.local/share}"
```

This means: use `$XDG_DATA_HOME` if it exists and is non-empty, otherwise fall
back to `$HOME/.local/share`. This single line handles both users who have customized
their XDG paths and users who have never heard of XDG.

### What lan_clerk uses

lan_clerk uses `XDG_DATA_HOME` for its generated interface records, because they are
persistent application data (not config, not cache):

```bash
SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/lan_clerk"
mkdir -p "$SHARE_DIR"
```

The `/lan_clerk` suffix creates a subdirectory scoped to this program, so it does
not dump files directly into `~/.local/share/` alongside files from unrelated
applications. `mkdir -p` creates the directory if it does not exist yet, silently
doing nothing if it already does.

---

## Why XDG Over a share/ Directory in Dotfiles

The original plan had generated files going into `share/` inside the project directory.
This was rejected for two reasons.

**1. Runtime data does not belong in a source repo.**
Your Dotfiles repo contains files you authored and want to version control. Interface
records are generated by the program and change as your network changes. They are not
config you wrote. Having them in Dotfiles means git would see them as untracked files,
and if you ever committed them by accident you'd be tracking ephemeral state.

**2. Stow cannot manage files that do not exist yet.**
Stow creates symlinks for files present at the moment you run `stow`. If the program
later generates a new interface file inside `share/`, Stow does not know about it —
no symlink is created for it, and it just sits in the Dotfiles directory without
being accessible via `~/.local/share/`. You would need to re-run `stow` every time
a new host was added. The XDG directory is a real directory the program writes to
directly, with no symlinking involved.

---

## How to Deploy (Stow)

Once the structure is in place:

```bash
cd ~/Dotfiles
stow -t ~/.local lan_clerk
```

The `-t ~/.local` flag sets the target explicitly. Without it, Stow defaults to the
parent of `~/Dotfiles/` (i.e. `~`), creating `~/bin/` and `~/lib/` instead.

This creates:
- `~/.local/bin/lan_clerk.sh`   — symlink, now available in PATH as `lan_clerk`
- `~/.local/lib/lan_clerk_lib.sh` — symlink, found via `../lib/` from the bin

On first run, `mkdir -p "$SHARE_DIR"` in the lib creates `~/.local/share/lan_clerk/`
automatically. No manual setup needed beyond the stow command.

To undo:
```bash
stow -t ~/.local -D lan_clerk
```
This removes the symlinks. Your files in Dotfiles are untouched.
