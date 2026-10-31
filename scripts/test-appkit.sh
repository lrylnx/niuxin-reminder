#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/appkit-tests
sed '/^let app = NSApplication.shared$/,$d' main.swift > build/appkit-tests/main.swift
cat tests/appkit.swift >> build/appkit-tests/main.swift
xcrun swiftc build/appkit-tests/main.swift EventParser.swift PendingReminders.swift -framework AppKit -o build/appkit-tests/run
build/appkit-tests/run
