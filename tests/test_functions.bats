#!/usr/bin/env bats
# Pure function tests — sources the daemon up to the BASH_SOURCE guard,
# then calls functions directly with mocked hyprctl and manual state setup.

DAEMON="$BATS_TEST_DIR/../scripts/hyprplane"

setup() {
  export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR"

  # Put mock hyprctl first in PATH
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cp "$(dirname "$BATS_TEST_FILENAME")/helpers/mock_hyprctl" "$BATS_TEST_TMPDIR/bin/hyprctl"
  chmod +x "$BATS_TEST_TMPDIR/bin/hyprctl"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"

  # Source daemon — stops at BASH_SOURCE guard, functions become available
  DAEMON="$(dirname "$BATS_TEST_FILENAME")/../scripts/hyprplane"
  # shellcheck disable=SC1090
  source "$DAEMON"

  # Initialize state (mirrors what the main loop does after arg parsing)
  SLOT_KEYS_RAW="F1,F2,F3"
  MOVE_MODIFIER="SHIFT"
  SLOT_MODIFIER=""
  PERSISTENT_WORKSPACES_RAW=""
  PASSTHROUGH_WORKSPACES_RAW=""
  IFS=',' read -ra SLOT_KEYS      <<< "$SLOT_KEYS_RAW"
  IFS=',' read -ra PASSTHROUGH_WS <<< "$PASSTHROUGH_WORKSPACES_RAW"
  SLOTS="${#SLOT_KEYS[@]}"

  PLANES=("default")
  CURRENT_NAME="default"
  CURRENT_INDEX=0
  declare -gA LAST_SLOTS
  LAST_SLOTS["default"]=1

  STATE_FILE="$BATS_TEST_TMPDIR/hyprplane.json"
  FIFO_PATH="$BATS_TEST_TMPDIR/hyprplane.fifo"
  IN_PASSTHROUGH=0
  LAST_WS_NAME=""
}

# ── plane_base ─────────────────────────────────────────────────────────────────

@test "plane_base(0) = 0" {
  result=$(plane_base 0)
  [ "$result" -eq 0 ]
}

@test "plane_base(1) = 100" {
  result=$(plane_base 1)
  [ "$result" -eq 100 ]
}

@test "plane_base(2) = 200" {
  result=$(plane_base 2)
  [ "$result" -eq 200 ]
}

# ── plane_index ────────────────────────────────────────────────────────────────

@test "plane_index finds default at 0" {
  result=$(plane_index "default")
  [ "$result" -eq 0 ]
}

@test "plane_index returns -1 for unknown plane" {
  result=$(plane_index "nonexistent")
  [ "$result" -eq -1 ]
}

@test "plane_index finds added plane" {
  PLANES=("default" "work")
  result=$(plane_index "work")
  [ "$result" -eq 1 ]
}

# ── write_state ────────────────────────────────────────────────────────────────

@test "write_state creates the state file" {
  write_state
  [ -f "$STATE_FILE" ]
}

@test "write_state current field matches CURRENT_NAME" {
  write_state
  current=$(jq -r '.current' < "$STATE_FILE")
  [ "$current" = "default" ]
}

@test "write_state planes array contains default" {
  write_state
  run jq -e '.planes | contains(["default"])' "$STATE_FILE"
  [ "$status" -eq 0 ]
}

@test "write_state produces valid JSON" {
  write_state
  run jq '.' "$STATE_FILE"
  [ "$status" -eq 0 ]
}

# ── create_plane validation ────────────────────────────────────────────────────

@test "create_plane rejects empty name" {
  create_plane ""
  [ "${#PLANES[@]}" -eq 1 ]
  [ "${PLANES[0]}" = "default" ]
}

@test "create_plane rejects name with colon" {
  create_plane "bad:name"
  [ "${#PLANES[@]}" -eq 1 ]
}

@test "create_plane rejects duplicate name" {
  create_plane "myplane"
  count_before="${#PLANES[@]}"
  create_plane "myplane"
  [ "${#PLANES[@]}" -eq "$count_before" ]
}

# ── rename_plane validation ────────────────────────────────────────────────────

@test "rename_plane cannot rename default" {
  PLANES=("default" "work")
  rename_plane "default" "other"
  [ "${PLANES[0]}" = "default" ]
}

@test "rename_plane rejects empty new name" {
  PLANES=("default" "work")
  CURRENT_NAME="work"
  CURRENT_INDEX=1
  LAST_SLOTS["work"]=1
  rename_plane "work" ""
  [ "${PLANES[1]}" = "work" ]
}

@test "rename_plane rejects colon in new name" {
  PLANES=("default" "work")
  LAST_SLOTS["work"]=1
  rename_plane "work" "bad:name"
  [ "${PLANES[1]}" = "work" ]
}

# ── delete_plane validation ────────────────────────────────────────────────────

@test "delete_plane cannot delete default" {
  delete_plane "default"
  [ "${PLANES[0]}" = "default" ]
}

@test "delete_plane rejects unknown plane" {
  delete_plane "nonexistent"
  [ "${#PLANES[@]}" -eq 1 ]
}

# ── is_passthrough ─────────────────────────────────────────────────────────────

@test "is_passthrough returns true for passthrough workspace" {
  IFS=',' read -ra PASSTHROUGH_WS <<< "gaming,browsers"
  is_passthrough "gaming"
  [ "$?" -eq 0 ]
}

@test "is_passthrough returns false for normal workspace" {
  IFS=',' read -ra PASSTHROUGH_WS <<< "gaming"
  ! is_passthrough "workspace1"
}

@test "is_passthrough returns false when list is empty" {
  PASSTHROUGH_WS=()
  ! is_passthrough "gaming"
}
