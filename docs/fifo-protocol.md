# FIFO Protocol

hyprplane exposes a command interface via a named FIFO at:

```
$XDG_RUNTIME_DIR/hyprplane.fifo
```

Write a single UTF-8 line to send a command. The daemon processes it synchronously and updates `$XDG_RUNTIME_DIR/hyprplane.json` before reading the next command.

## Commands

| Command | Effect |
|---------|--------|
| `switch:<name>` | Switch to an existing plane |
| `create:<name>` | Create a new plane and switch to it |
| `rename:<old>:<new>` | Rename a plane (`default` cannot be renamed) |
| `delete:<name>` | Delete a plane, moving its windows to `default` (`default` cannot be deleted) |

Plane names cannot be empty or contain `:`.

## Examples

```bash
echo "switch:work"      > "$XDG_RUNTIME_DIR/hyprplane.fifo"
echo "create:research"  > "$XDG_RUNTIME_DIR/hyprplane.fifo"
echo "rename:work:job"  > "$XDG_RUNTIME_DIR/hyprplane.fifo"
echo "delete:research"  > "$XDG_RUNTIME_DIR/hyprplane.fifo"
```

## State file

After any command, the daemon writes:

```json
{
  "planes": ["default", "work"],
  "current": "work",
  "currentIndex": 1,
  "lastSlots": { "default": 3, "work": 1 },
  "persistentWorkspaces": ["gaming", "browsers"]
}
```

Location: `$XDG_RUNTIME_DIR/hyprplane.json`

Read this file directly from your launcher to render current state. There is no request/response — read the file, write a command, read again.

## Building a launcher

Any tool that can write a line to a FIFO works. A few common patterns:

### Shell

```bash
# one-shot dispatch
echo "switch:work" > "$XDG_RUNTIME_DIR/hyprplane.fifo"

# read state, then dispatch
CURRENT=$(jq -r '.current' < "$XDG_RUNTIME_DIR/hyprplane.json")
echo "rename:${CURRENT}:job" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
```

### Python

```python
import os, json, pathlib

fifo = pathlib.Path(os.environ["XDG_RUNTIME_DIR"]) / "hyprplane.fifo"
state_file = pathlib.Path(os.environ["XDG_RUNTIME_DIR"]) / "hyprplane.json"

def send(cmd: str):
    fifo.open("w").write(cmd + "\n")

def state():
    return json.loads(state_file.read_text())

send("create:work")
send(f"rename:{state()['current']}:job")
```

### Waybar on-click

```json
"custom/hyprplane": {
  "exec": "hyprplane-status",
  "interval": 2,
  "return-type": "json",
  "on-click": "your-launcher-script",
  "on-right-click": "bash -c 'echo create:$(date +%H%M) > $XDG_RUNTIME_DIR/hyprplane.fifo'"
}
```

### wofi (minimal example)

```bash
#!/usr/bin/env bash
PLANES=$(jq -r '.planes[]' < "$XDG_RUNTIME_DIR/hyprplane.json")
CHOSEN=$(echo "$PLANES" | wofi --dmenu --prompt "plane")
[[ -n "$CHOSEN" ]] && echo "switch:$CHOSEN" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
```

See the README for a fuller rofi example that includes create/rename/delete.
