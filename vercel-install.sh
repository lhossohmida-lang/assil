#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.44.4"
FLUTTER_ROOT="$PWD/.vercel-flutter/flutter"
ARCHIVE_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [ ! -x "$FLUTTER_ROOT/bin/flutter" ]; then
  rm -rf "$PWD/.vercel-flutter"
  mkdir -p "$PWD/.vercel-flutter"
  curl --fail --location --silent --show-error "$ARCHIVE_URL" \
    | tar -xJ -C "$PWD/.vercel-flutter"
fi

"$FLUTTER_ROOT/bin/flutter" config --no-analytics
"$FLUTTER_ROOT/bin/flutter" pub get
