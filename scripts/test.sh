#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
xcrun swiftc EventParser.swift tests/main.swift -o build/parser-tests
build/parser-tests
