#!/usr/bin/env bats

setup() {
  DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
  export DOTFILES_DIR
}

@test "DC local probes report real installed package and tunnel versions" {
  local fake_home="$BATS_TEST_TMPDIR/home"
  local package_dir="$fake_home/.local/share/ixatu-mcp/node_modules/@wonderwhy-er/desktop-commander"
  mkdir -p "$package_dir" "$fake_home/.local/bin"
  printf '{"version":"0.3.2"}\n' > "$package_dir/package.json"
  cat > "$fake_home/.local/bin/tunnel-client" <<'EOF'
#!/usr/bin/env bash
printf '0.0.21+abc (git sha: abc)\n'
EOF
  chmod +x "$fake_home/.local/bin/tunnel-client"
  run env HOME="$fake_home" bash -c '
    source "$DOTFILES_DIR/scripts/update/lib/dc_local.sh"
    [[ "$(dc_local_version)" == "0.3.2" ]]
    [[ "$(dc_tunnel_version)" == "0.0.21" ]]
    dc_is_stable_version 0.3.3
    ! dc_is_stable_version 0.3.3-rc1
    dc_newer_version 0.3.3 0.3.2
    ! dc_newer_version 0.3.2 0.3.3
  '
  [ "$status" -eq 0 ]
}

@test "DC integration keeps the active service untouched" {
  local script="$DOTFILES_DIR/scripts/update/update-wsl.sh"
  grep -q 'want_section tools.*update_dc_local' "$script"
  grep -q 'dc_snapshot' "$script"
  ! grep -Eq 'systemctl.*(restart|stop).*ixatu-wsl-mcp' "$DOTFILES_DIR/scripts/update/lib/dc_local.sh"
}
