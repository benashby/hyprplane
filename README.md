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
  settings = {
    slotsPerPlane         = 12;
    persistentWorkspaces  = [ "gaming" "browsers" "chat" ];
    passthroughWorkspaces = [ "gaming" ];
    slot.keys             = [ "F1" "F2" "F3" "F4" "F5" "F6" "F7" "F8" "F9" "F10" "F11" "F12" ];
    slot.modifier         = "";
    slot.moveModifier     = "SHIFT";
  };
};
```

### Without Nix

```bash
make PREFIX=~/.local install
```

Then start the daemon:

```bash
hyprplane \
  --slots 12 \
  --slot-keys "F1,F2,F3,F4,F5,F6,F7,F8,F9,F10,F11,F12" \
  --slot-modifier "" \
  --move-modifier "SHIFT" \
  --persistent-workspaces "gaming,browsers" \
  --passthrough-workspaces "gaming" &
```

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
  "★ "*|"  "*)
    NAME="${CHOSEN#[★ ]*}"
    NAME="${NAME#  }"
    [[ "$NAME" != "$CURRENT" ]] && echo "switch:$NAME" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
    ;;
  "＋ new plane")
    NAME=$(echo "" | rofi -dmenu -p "plane name")
    [[ -n "$NAME" ]] && echo "create:$NAME" > "$XDG_RUNTIME_DIR/hyprplane.fifo"
    ;;
esac
```

## Waybar

Use `hyprplane-status` as a `custom/` module:

```json
"custom/hyprplane": {
  "exec": "hyprplane-status",
  "interval": 2,
  "return-type": "json",
  "on-click": "your-launcher-script"
}
```

## License

MIT
