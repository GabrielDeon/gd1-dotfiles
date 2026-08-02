#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
HYPR_CONFIG_DIR="$HOME/.config/hypr"

echo "Removendo configurações antigas do Hyprland..."

rm -f \
  "$HYPR_CONFIG_DIR/hypridle.conf" \
  "$HYPR_CONFIG_DIR/input.conf" \
  "$HYPR_CONFIG_DIR/monitors.conf"

echo "Aplicando configurações com GNU Stow..."

cd "$DOTFILES_DIR"
stow --restow hyprland

echo "Recarregando o Hyprland..."

hyprctl reload

echo "Configuração do Hyprland concluída."
