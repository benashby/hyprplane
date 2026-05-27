#!/usr/bin/env bats
# CLI argument validation — tests that exit immediately (no Hyprland needed)

setup() {
  DAEMON="$(dirname "$BATS_TEST_FILENAME")/../scripts/hyprplane"
}

@test "--slot-keys is required" {
  run "$DAEMON" --move-modifier SHIFT
  [ "$status" -eq 1 ]
  [[ "$output" == *"--slot-keys is required"* ]]
}

@test "--slot-keys error message shows example" {
  run "$DAEMON" --move-modifier SHIFT
  [[ "$output" == *"F1,F2,F3"* ]]
}

@test "--move-modifier is required" {
  run "$DAEMON" --slot-keys "F1,F2,F3"
  [ "$status" -eq 1 ]
  [[ "$output" == *"--move-modifier is required"* ]]
}

@test "--move-modifier error mentions NONE option" {
  run "$DAEMON" --slot-keys "F1,F2,F3"
  [[ "$output" == *"NONE"* ]]
}

@test "unknown argument exits with error" {
  run "$DAEMON" --slot-keys "F1" --move-modifier SHIFT --bogus-flag
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown argument"* ]]
}

@test "unknown argument names the bad flag" {
  run "$DAEMON" --slot-keys "F1" --move-modifier SHIFT --bogus-flag
  [[ "$output" == *"--bogus-flag"* ]]
}
