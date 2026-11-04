#!/bin/sh
set -e
cd "$(dirname "$0")"
mkdir -p build
swiftc -Onone Ring.swift FrequencyShifter.swift Artwork.swift Ambience.swift Tests/main.swift -o build/ringcheck && build/ringcheck
