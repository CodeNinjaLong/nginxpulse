#!/usr/bin/env bash
set -euo pipefail

buildx_available() {
  docker buildx version >/dev/null 2>&1
}

current_buildx_driver() {
  docker buildx inspect 2>/dev/null | awk -F': ' '/^Driver:/ {print $2; exit}'
}

builder_exists() {
  local builder_name="$1"
  docker buildx inspect "$builder_name" >/dev/null 2>&1
}

ensure_container_buildx_builder() {
  local builder_name="${1:-nginxpulse-container-builder}"
  local driver

  if ! buildx_available; then
    echo "Docker buildx is required but not available." >&2
    return 1
  fi

  driver="$(current_buildx_driver || true)"
  if [[ "$driver" == "docker-container" ]]; then
    docker buildx inspect --bootstrap >/dev/null
    return 0
  fi

  if builder_exists "$builder_name"; then
    docker buildx use "$builder_name" >/dev/null
  else
    docker buildx create --name "$builder_name" --driver docker-container --use >/dev/null
  fi

  docker buildx inspect --bootstrap >/dev/null
}
