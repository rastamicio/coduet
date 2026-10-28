#!/usr/bin/env bash
# Shows a desktop notice (used by scheduled notices).  notify.sh <message>
source "$(dirname "$0")/common.sh"
notify "$1"
