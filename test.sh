#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p build
swiftc -Onone Ring.swift Tests/main.swift -o build/ringcheck && build/ringcheck
