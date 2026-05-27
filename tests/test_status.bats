#!/usr/bin/env bats
# hyprplane-status output tests — no daemon or Hyprland needed

setup() {
  STATUS="$(dirname "$BATS_TEST_FILENAME")/../scripts/hyprplane-status"
  export XDG_RUNTIME_DIR="$BATS_TEST_TMPDIR"
}

@test "outputs inactive JSON when state file missing" {
  run "$STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"class":"hyprplane-inactive"'* ]]
}

@test "inactive output has empty text" {
  run "$STATUS"
  [[ "$output" == *'"text":""'* ]]
}

@test "outputs current plane name in text field" {
  echo '{"planes":["default"],"current":"default","currentIndex":0,"lastSlots":{"default":1},"persistentWorkspaces":[]}' \
    > "$BATS_TEST_TMPDIR/hyprplane.json"
  run "$STATUS"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"text":"default"'* ]]
}

@test "active output uses hyprplane class" {
  echo '{"planes":["default"],"current":"default","currentIndex":0,"lastSlots":{"default":1},"persistentWorkspaces":[]}' \
    > "$BATS_TEST_TMPDIR/hyprplane.json"
  run "$STATUS"
  [[ "$output" == *'"class":"hyprplane"'* ]]
}

@test "tooltip contains all plane names" {
  echo '{"planes":["default","work","research"],"current":"work","currentIndex":1,"lastSlots":{"default":1,"work":2,"research":1},"persistentWorkspaces":[]}' \
    > "$BATS_TEST_TMPDIR/hyprplane.json"
  run "$STATUS"
  [[ "$output" == *"default"* ]]
  [[ "$output" == *"work"* ]]
  [[ "$output" == *"research"* ]]
}

@test "alt field contains plane count" {
  echo '{"planes":["default","work"],"current":"default","currentIndex":0,"lastSlots":{"default":1,"work":1},"persistentWorkspaces":[]}' \
    > "$BATS_TEST_TMPDIR/hyprplane.json"
  run "$STATUS"
  [[ "$output" == *'"alt":"2"'* ]]
}

@test "output is valid JSON" {
  echo '{"planes":["default"],"current":"default","currentIndex":0,"lastSlots":{"default":1},"persistentWorkspaces":[]}' \
    > "$BATS_TEST_TMPDIR/hyprplane.json"
  run "$STATUS"
  [ "$status" -eq 0 ]
  echo "$output" | jq '.' > /dev/null
}
