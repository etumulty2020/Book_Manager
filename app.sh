#!/bin/bash
# Application entry point.

# Full path to this folder, so the app runs from any directory
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$APP_DIR/ui/main_menu.sh"
