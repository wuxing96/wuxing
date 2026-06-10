#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
swift build -c release
printf '%s\n' ".build/release/ai-traffic-light"
