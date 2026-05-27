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

Any tool that can write a line to a FIFO works: shell scripts, rofi custom modes, wofi scripts, anyrun plugins, Python, etc. See the README for an example rofi shell script.
