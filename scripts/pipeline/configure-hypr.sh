#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
USER_HOME="${HOME:?HOME não está definido}"
HYPR_CONFIG_DIR="$USER_HOME/.config/hypr"
HYPR_PACKAGE_DIR="$DOTFILES_DIR/hyprland"
BACKUP_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

backup_if_present() {
  local path="$1"

  if [[ -e "$path" || -L "$path" ]]; then
    local backup_base="${path}.bak.${BACKUP_TIMESTAMP}"
    local backup="$backup_base"
    local sequence=1

    while [[ -e "$backup" || -L "$backup" ]]; do
      backup="${backup_base}.${sequence}"
      ((sequence += 1))
    done

    echo "Preservando $path em $backup"
    mv -- "$path" "$backup"
  fi
}

prepare_stow_target() {
  local relative_path="$1"
  local source="$HYPR_PACKAGE_DIR/$relative_path"
  local target="$USER_HOME/$relative_path"

  if [[ ! -e "$source" ]]; then
    echo "Arquivo ausente no pacote Stow: $source" >&2
    exit 1
  fi

  if [[ -L "$target" ]] &&
    [[ "$(readlink -f -- "$target")" == "$(readlink -f -- "$source")" ]]; then
    return
  fi

  backup_if_present "$target"
}

echo "Validando configurações Lua do Hyprland..."

luac -p \
  "$HYPR_PACKAGE_DIR/.config/hypr/input.lua" \
  "$HYPR_PACKAGE_DIR/.config/hypr/monitors.lua"

echo "Preparando substituição segura das configurações do Hyprland..."

prepare_stow_target ".config/hypr/hypridle.conf"
prepare_stow_target ".config/hypr/input.lua"
prepare_stow_target ".config/hypr/monitors.lua"

# Preserve legacy configuration files left by the pre-Lua setup. They are no
# longer loaded by Omarchy, but keeping a backup avoids discarding local edits.
backup_if_present "$HYPR_CONFIG_DIR/input.conf"
backup_if_present "$HYPR_CONFIG_DIR/monitors.conf"

echo "Aplicando configurações com GNU Stow..."

stow --restow --dir="$DOTFILES_DIR" --target="$USER_HOME" hyprland

echo "Recarregando o Hyprland..."

hyprctl reload

echo "Verificando erros de configuração..."

CONFIG_ERRORS="$(hyprctl configerrors)"
if [[ -n "${CONFIG_ERRORS//[[:space:]]/}" ]]; then
  printf '%s\n' "$CONFIG_ERRORS" >&2
  exit 1
fi

echo "Configuração do Hyprland concluída."
