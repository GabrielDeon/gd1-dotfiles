#!/usr/bin/env bash

set -euo pipefail

PIPELINE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(dirname -- "$PIPELINE_DIR")"

bash "$SCRIPTS_DIR/units/install-brave.sh"
bash "$SCRIPTS_DIR/units/install-stow.sh"
bash "$SCRIPTS_DIR/units/install-yazi.sh"
bash "$SCRIPTS_DIR/pipeline/configure-hypr.sh"
bash "$SCRIPTS_DIR/units/install-steam.sh"
