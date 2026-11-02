#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if grep -rnE '^\s*import (SwiftUI|UIKit|AppKit)\b' Sources/SampleCore; then
    echo "Rule 1: SampleCore must not import a UI framework." >&2
    exit 1
fi
