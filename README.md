# hyprplane

Adds a plane layer above Hyprland workspaces. Switch between planes and each one has its own set of desktop slots — your existing windows stay exactly where they are on the other plane.

The default plane is always there. Create more at runtime; they're gone when your session ends.

## How it works

Each plane owns a block of Hyprland workspace IDs (`plane_index × 100 + slot`). Switching planes rebinds your slot keys to point at the new block. Static/persistent workspaces (like `gaming`) are excluded from all plane slot ranges.

## Install

### Nix flake

```nix
# flake.nix
inputs.hyprplane.url = "github:benashby/hyprplane";
```

```nix
# home.nix
imports = [ inputs.hyprplane.homeModules.default ];

programs.hyprplane = {
  enable = true;

  # Default target is hyprland-session.target. If you use UWSM (start-hyprland),
  # set this to graphical-session.target instead:
  # systemd.target = "graphical-session.target";

  settings = {
    # slot.keys and slot.moveModifier are required — no defaults are assumed
    slot.keys         = [ "F1" "F2" "F3" "F4" "F5" "F6" "F7" "F8" "F9" "F10" "F11" "F12" ];
    slot.modifier     = "";      # empty = no modifier
    slot.moveModifier = "SHIFT"; # use "NONE" to disable move-to-slot bindings

    persistentWorkspaces  = [ "gaming" "browsers" "chat" ];
    passthroughWorkspaces = [ "gaming" ];
  };
};
```

### Without Nix

```bash
make PREFIX=~/.local install
```

Then start the daemon. `--slot-keys` and `--move-modifier` are required:

```bash
hyprplane \
  --slot-keys "F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,F11,F12" \
  --move-modifier "SHIFT" \
  --persistent-workspaces "gaming,browsers" \
  --passthrough-workspaces "gaming" &
```

`--slots` defaults to the number of keys provided. `--slot-modifier` defaults to no modifier. Use `--move-modifier NONE` to disable move-to-slot bindings.

## Launcher

hyprplane ships no launcher. The interface is a FIFO at `$XDG_RUNTIME_DIR/hyprplane.fifo` — write a command line to it, the daemon acts on it synchronously. Current state is always available in `$XDG_RUNTIME_DIR/hyprplane.json`. Any tool that can read a file and write a line to a FIFO can be a launcher.

See [docs/fifo-protocol.md](docs/fifo-protocol.md) for the full command reference.

### Example rofi launcher

Bind this script to a key (e.g. `Super+W`). It reads current state, builds a menu, and writes a command back to hyprplane.

```bash
#!/usr/bin/env bash

# ── read current state from hyprplane ────────────────────────────────────────
# hyprplane writes this file after every state change.
# No IPC needed — just read the file.
STATE=$(cat "$XDG_RUNTIME_DIR/hyprplane.json")
CURRENT=$(echo "$STATE" | jq -r '.current')       # name of the active plane
PLANES=$(echo "$STATE"  | jq -r '.planes[]')       # all plane names, one per line

# ── build the menu ────────────────────────────────────────────────────────────
# Mark the current plane with ★ so the user knows where they are.
# Other planes get two leading spaces — the case statement below uses this
# prefix to detect "switch to this plane" selections.
OPTIONS=$(printf '%s\n' "$PLANES" | while read -r p; do
  [[ "$p" == "$CURRENT" ]] && echo "★ $p" || echo "  $p"
done)
OPTIONS="$OPTIONS
＋ new plane"

CHOSEN=$(echo "$OPTIONS" | rofi -dmenu -p "plane")

# ── dispatch to hyprplane via FIFO ────────────────────────────────────────────
# Writing to the FIFO sends a command directly to the daemon.
# The daemon processes it and updates the state file before the next read.
case "$CHOSEN" in
  "★ "*)
    # Selected the current plane — nothing to do.
    ;;
  "  "*)
    # Strip the two-space prefix to recover the plain plane name, then switch.
    # The daemon rebinds all slot keys to that plane's workspace ID range.
    echo "switch:${CHOSEN#  }" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
    ;;
  "＋ new plane")
    # Ask for a name, then tell hyprplane to create it.
    # The daemon allocates the next 100-block of workspace IDs, renames them
    # so they display as 1–N in waybar, and switches to the new plane.
    NAME=$(echo "" | rofi -dmenu -p "plane name")
    [[ -n "$NAME" ]] && echo "create:$NAME" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
    ;;
esac
```

To add rename and delete, extend the menu and add cases:

```bash
OPTIONS="$OPTIONS
✏ rename current
✕ delete current"

# ... in the case statement:
  "✏ rename current")
    NEW=$(echo "$CURRENT" | rofi -dmenu -p "rename to")
    [[ -n "$NEW" && "$NEW" != "$CURRENT" ]] && echo "rename:${CURRENT}:${NEW}" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
    ;;
  "✕ delete current")
    # default plane cannot be deleted — the daemon enforces this and logs an error
    echo "delete:${CURRENT}" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
    ;;
```

## Waybar

`hyprplane-status` is a small script that reads `$XDG_RUNTIME_DIR/hyprplane.json` and prints a JSON object for waybar. **It must be in your PATH** — waybar runs it as a subprocess and will silently show nothing if it can't find it.

- **Nix (HM module):** `programs.hyprplane.enable = true` adds the package to `home.packages` automatically. Both `hyprplane` and `hyprplane-status` land in your profile PATH.
- **Without Nix:** `make PREFIX=~/.local install` puts both in `~/.local/bin/`. Make sure that's on your PATH before waybar starts.

`hyprplane-status` outputs a JSON object that waybar's `custom/` module understands via `return-type: "json"`:

```json
{ "text": "default", "tooltip": "default · work · research", "class": "hyprplane", "alt": "3" }
```

- **text** — current plane name, displayed in the bar
- **tooltip** — all planes joined with ` · `, shown on hover
- **class** — CSS class applied to the element (`hyprplane` when running, `hyprplane-inactive` when daemon is not running)
- **alt** — plane count; available as `{alt}` in your `format` string if you want it

### Module config

```json
"custom/hyprplane": {
  "exec": "hyprplane-status",
  "interval": 2,
  "return-type": "json",
  "format": "  {}",
  "tooltip": true,
  "on-click": "hypr-your-launcher"
}
```

`on-click` runs a shell command when you left-click the widget. Point it at whatever script drives your FIFO launcher. The script reads `hyprplane.json` for current state and writes commands to `hyprplane.fifo` — clicking the widget is just a trigger to open that script.

If you want instant updates instead of polling every 2 seconds, use a signal:

```json
"custom/hyprplane": {
  "exec": "hyprplane-status",
  "signal": 8,
  "return-type": "json",
  "format": "  {}",
  "on-click": "hypr-your-launcher"
}
```

Then have your launcher send `pkill -RTMIN+8 waybar` after writing to the FIFO. Waybar re-runs `hyprplane-status` immediately on that signal, so the bar updates the moment you switch planes rather than waiting for the next poll.

### Styling

```css
#custom-hyprplane {
  color: @text;
  padding: 0 8px;
}

#custom-hyprplane.hyprplane-inactive {
  color: @surface2;
}
```

## License

MIT
