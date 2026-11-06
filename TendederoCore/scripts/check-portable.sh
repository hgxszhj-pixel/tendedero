#!/bin/bash
# The core must not use anything that only macOS has, or it cannot be built
# for another system. This fails when it finds one.
#
# Usage: bash TendederoCore/scripts/check-portable.sh
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

# Imports that only exist on macOS, and the few APIs that only work there.
forbidden='^import +(AppKit|Cocoa|Carbon|Quartz|QuartzCore|ServiceManagement|os|AVFoundation|AVKit|SwiftUI|UniformTypeIdentifiers)$|NSSearchPathDirectory|SearchPathDirectory|FileManager\.(desktop|picture|downloads)Directory|CFPreferences|NSStatusItem|kMDItem|CGWindowList|NSWorkspace'

hits=$(grep -Ern --include='*.swift' "$forbidden" Sources/ 2>/dev/null || true)
if [ -n "$hits" ]; then
    echo "portable: the core uses macOS-only things:"
    echo "$hits"
    exit 1
fi

# A package that says which platforms it is for is saying it is not for
# others, so the core must not say that.
if grep -Eq '^\s*platforms\s*:' Package.swift; then
    echo "portable: the core package restricts its platforms:"
    grep -En '^\s*platforms\s*:' Package.swift
    exit 1
fi

echo "portable: the core uses no macOS-only things"
