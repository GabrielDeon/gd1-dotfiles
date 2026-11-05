#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
PLUGIN_ID="gd1.system-market"
SOURCE_DIR="$DOTFILES_DIR/omarchy/plugins/$PLUGIN_ID"
OMARCHY_CONFIG_DIR="${HOME:?HOME não está definido}/.config/omarchy"
PLUGIN_DIR="$OMARCHY_CONFIG_DIR/plugins/$PLUGIN_ID"

for dependency in omarchy python3; do
  command -v "$dependency" >/dev/null || {
    echo "Dependência ausente: $dependency" >&2
    exit 1
  }
done

omarchy plugin validate "$SOURCE_DIR"

echo "Instalando System & Markets no Omarchy shell..."

# Omarchy rejects symlinks inside plugins, so this package is copied rather
# than stowed. Never change the packaged shell files under /usr/share/omarchy.
python3 - "$SOURCE_DIR" "$OMARCHY_CONFIG_DIR" "$PLUGIN_ID" "${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json" <<'PY'
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from datetime import datetime

source = Path(sys.argv[1])
config = Path(sys.argv[2])
plugin_id = sys.argv[3]
target = config / 'plugins' / plugin_id
settings_path = config / 'shell.json'
files = ['manifest.json', 'Dashboard.qml', 'probe.py', 'i18n/en.json', 'i18n/pt-BR.json']

# Parse before changing any existing files. Preserve all other settings and
# the widget's saved preferences, including pricesEnabled.
defaults_path = Path(sys.argv[4])
if settings_path.exists():
    settings = json.loads(settings_path.read_text())
elif defaults_path.is_file():
    settings = json.loads(defaults_path.read_text())
else:
    raise ValueError(f'Configuração padrão do Omarchy ausente: {defaults_path}')
if not isinstance(settings, dict):
    raise ValueError('shell.json must contain an object')
layout = settings.setdefault('bar', {}).setdefault('layout', {})
sections = ('left', 'centerBegin', 'center', 'centerEnd', 'right', 'tray')
for section in sections:
    if section in layout and not isinstance(layout[section], list):
        raise ValueError(f'bar.layout.{section} must be an array')
existing = any(isinstance(entry, dict) and entry.get('id') == plugin_id
               for section in sections for entry in layout.get(section, []))
if not existing:
    right = layout.setdefault('right', [])
    index = next((i for i, entry in enumerate(right)
                  if isinstance(entry, dict) and entry.get('id') == 'omarchy.monitor'), len(right))
    right.insert(index, {'id': plugin_id})
if isinstance(settings.get('disabledPlugins'), list):
    settings['disabledPlugins'] = [item for item in settings['disabledPlugins'] if item != plugin_id]

new_settings = json.dumps(settings, indent=2, ensure_ascii=False) + '\n'
settings_changed = not settings_path.exists() or json.loads(settings_path.read_text()) != settings
plugin_changed = target.is_symlink() or any(
    not (target / name).is_file() or (target / name).is_symlink()
    or (target / name).read_bytes() != (source / name).read_bytes() for name in files)

backup = None
if (plugin_changed and (target.exists() or target.is_symlink())) or (settings_changed and settings_path.exists()):
    config.mkdir(parents=True, exist_ok=True)
    backup = Path(tempfile.mkdtemp(prefix='system-market-' + datetime.now().strftime('%Y%m%d-%H%M%S') + '-', dir=config))
    if plugin_changed and (target.exists() or target.is_symlink()):
        shutil.copytree(target, backup / plugin_id, symlinks=True)
    if settings_path.exists():
        shutil.copy2(settings_path, backup / 'shell.json')
    print(f'Backup: {backup}')

if plugin_changed:
    if target.is_symlink():
        target.unlink()
    for name in files:
        destination = target / name
        # Refuse symlinked intermediate directories instead of following them.
        for parent in (target.parent, target, destination.parent):
            if parent.is_symlink():
                raise ValueError(f'Symlink inesperado: {parent}')
        destination.parent.mkdir(parents=True, exist_ok=True)
        if destination.is_symlink():
            destination.unlink()
        shutil.copy2(source / name, destination)

if settings_changed:
    config.mkdir(parents=True, exist_ok=True)
    # Write through a Stow-managed shell.json link, keeping that link intact.
    destination = settings_path.resolve() if settings_path.is_symlink() else settings_path
    fd, temporary = tempfile.mkstemp(prefix='.shell-', suffix='.json', dir=destination.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(new_settings)
        if destination.exists():
            shutil.copymode(destination, temporary)
        os.replace(temporary, destination)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)

print('Plugin e configuração atualizados.' if plugin_changed or settings_changed else 'Plugin já configurado.')
PY

omarchy plugin validate "$PLUGIN_DIR"

# Setup also works before the graphical session starts. The saved bar entry
# enables the plugin on next login; discovery itself is asynchronous.
if command -v omarchy-shell >/dev/null && omarchy-shell shell ping >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins
  discovered=0
  for ((attempt = 0; attempt < 40; attempt++)); do
    if omarchy plugin list --json | python3 -c \
      'import json,sys; sys.exit(not any(p.get("id") == sys.argv[1] for p in json.load(sys.stdin)))' "$PLUGIN_ID"; then
      discovered=1
      break
    fi
    sleep 0.1
  done
  if (( ! discovered )); then
    echo "Plugin instalado, mas não foi descoberto pelo shell." >&2
    exit 1
  fi
  omarchy plugin enable "$PLUGIN_ID"
  echo "Plugin habilitado. Se o shell mantiver código em cache, execute: omarchy restart shell"
else
  echo "Sem sessão ativa: o plugin será carregado no próximo login."
fi
