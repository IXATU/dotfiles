#!/usr/bin/env bats

setup() {
  DOTFILES_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
}

@test "classic lightest background and full paths survive sourcing" {
  run zsh -fc 'source "$1/powerlevel10k/p10k.zsh"; [[ $POWERLEVEL9K_BACKGROUND == 240 && $POWERLEVEL9K_DIR_BACKGROUND == 240 && $POWERLEVEL9K_VCS_CLEAN_BACKGROUND == 240 && -z $POWERLEVEL9K_SHORTEN_STRATEGY && $POWERLEVEL9K_SHORTEN_DIR_LENGTH == 0 ]]' zsh "$DOTFILES_DIR"
  [ "$status" -eq 0 ]
}

@test "custom prompt segments stay enabled" {
  run zsh -fc 'source "$1/powerlevel10k/p10k.zsh"; [[ ${(j:,:)POWERLEVEL9K_LEFT_PROMPT_ELEMENTS} == os_icon,dir,github_owner,upstream_owner,vcs,python_uv,git_author ]]' zsh "$DOTFILES_DIR"
  [ "$status" -eq 0 ]
}

@test "docker aliases are lazy and use safe prune commands" {
  run zsh -fc 'docker() { print -u2 "DOCKER CALLED AT STARTUP"; return 99; }; source "$1/aliases"; [[ "$(alias drm)" == *"docker container prune"* && "$(alias dri)" == *"docker image prune"* ]]' zsh "$DOTFILES_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"DOCKER CALLED AT STARTUP"* ]]
}
