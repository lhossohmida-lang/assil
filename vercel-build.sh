#!/usr/bin/env bash
set -euo pipefail

FLUTTER_ROOT="$PWD/.vercel-flutter/flutter"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  echo "Flutter SDK was not installed by vercel-install.sh" >&2
  exit 1
fi

"$FLUTTER_ROOT/bin/flutter" build web --release
