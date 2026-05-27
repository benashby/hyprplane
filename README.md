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

hyprplane ships no launcher — use whatever you want. Commands go to the FIFO at `$XDG_RUNTIME_DIR/hyprplane.fifo`. See [docs/fifo-protocol.md](docs/fifo-protocol.md) for the full spec.

Example rofi launcher (shell script):

```bash
#!/usr/bin/env bash
STATE=$(cat "$XDG_RUNTIME_DIR/hyprplane.json")
CURRENT=$(echo "$STATE" | jq -r '.current')
PLANES=$(echo "$STATE"  | jq -r '.planes[]')

OPTIONS=$(printf '%s\n' "$PLANES" | while read -r p; do
  [[ "$p" == "$CURRENT" ]] && echo "★ $p" || echo "  $p"
done)
OPTIONS="$OPTIONS
＋ new plane"

CHOSEN=$(echo "$OPTIONS" | rofi -dmenu -p "plane")

case "$CHOSEN" in
  "★ "*) ;;  # already current, do nothing
  "  "*)
    echo "switch:${CHOSEN#  }" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
    ;;
  "＋ new plane")
    NAME=$(echo "" | rofi -dmenu -p "plane name")
    [[ -n "$NAME" ]] && echo "create:$NAME" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
    ;;
esac
```

## Waybar

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
