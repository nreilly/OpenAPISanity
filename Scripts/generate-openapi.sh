#!/bin/sh

set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
  echo "Usage: $0 <input.nullfix> <output.json> [sanitizer-package-dir]" >&2
  exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"
SANITIZER_PACKAGE_DIR="${3:-${OPENAPI_SANITIZER_PACKAGE_DIR:-}}"

if [ ! -f "$INPUT_FILE" ]; then
  echo "error: Input file not found: $INPUT_FILE" >&2
  exit 1
fi

if [ -z "$SANITIZER_PACKAGE_DIR" ]; then
  SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
  SANITIZER_PACKAGE_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
fi

if [ ! -f "$SANITIZER_PACKAGE_DIR/Package.swift" ]; then
  echo "error: Sanitizer package not found at: $SANITIZER_PACKAGE_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

swift run \
  --package-path "$SANITIZER_PACKAGE_DIR" \
  openapi-sanitizer \
  "$INPUT_FILE" \
  "$OUTPUT_FILE"
