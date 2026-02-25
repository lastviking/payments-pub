#!/usr/bin/env bash
set -euo pipefail

if command -v buf >/dev/null 2>&1; then
  echo "Running buf lint..."
  buf lint

  echo "Running buf build..."
  buf build

  echo "Proto validation passed with buf."
  exit 0
fi

if ! command -v protoc >/dev/null 2>&1; then
  echo "Error: neither 'buf' nor 'protoc' is available in PATH." >&2
  echo "Install buf from https://buf.build/docs/cli/installation/" >&2
  exit 1
fi

echo "buf not found; falling back to protoc validation..."
tmp_desc="$(mktemp)"
trap 'rm -f "${tmp_desc}"' EXIT

protoc -I proto --descriptor_set_out="${tmp_desc}" proto/payments/v1/*.proto

echo "Proto validation passed with protoc."
