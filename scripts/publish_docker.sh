#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT_DIR/scripts/docker_buildx_helper.sh"

usage() {
  cat <<'EOF'
Usage: scripts/publish_docker.sh -r <repo> [-v <version>] [-p <platforms>] [--no-push]

Options:
  -r, --repo        Docker Hub repo, e.g. username/nginxpulse
  -v, --version     Version tag (defaults to git describe or timestamp)
  -p, --platforms   Build platforms (default: linux/amd64,linux/arm64)
  --no-push         Build only (no push)

Environment:
  DOCKERHUB_REPO    Same as --repo
  VERSION           Same as --version
  PLATFORMS         Same as --platforms

Notes:
  - If version contains "beta", this script will NOT push the :latest tag.
EOF
}

REPO="${DOCKERHUB_REPO:-}"
VERSION="${VERSION:-}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"
TAG_LATEST=true
PUSH=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --)
      shift
      ;;
    -r|--repo)
      REPO="$2"
      shift 2
      ;;
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    -p|--platforms)
      PLATFORMS="$2"
      shift 2
      ;;
    --no-push)
      PUSH=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$REPO" ]]; then
  echo "Missing repo. Use -r or DOCKERHUB_REPO." >&2
  exit 1
fi

if [[ -z "$VERSION" ]]; then
  if git -C "$ROOT_DIR" describe --tags --exact-match >/dev/null 2>&1; then
    VERSION="$(git -C "$ROOT_DIR" describe --tags --exact-match)"
  else
    VERSION="$(git -C "$ROOT_DIR" describe --tags --abbrev=7 --always 2>/dev/null || date -u +%Y%m%d%H%M%S)"
  fi
fi

version_lower="$(printf '%s' "$VERSION" | tr '[:upper:]' '[:lower:]')"
if [[ "$version_lower" == *beta* ]]; then
  TAG_LATEST=false
fi

BUILD_TIME="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
GIT_COMMIT="$(git -C "$ROOT_DIR" rev-parse --short=7 HEAD 2>/dev/null || echo "unknown")"

TAG_LIST=("$REPO:$VERSION")
if $TAG_LATEST; then
  TAG_LIST+=("$REPO:latest")
fi
TAGS=()
for tag in "${TAG_LIST[@]}"; do
  TAGS+=(-t "$tag")
done

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker CLI not found." >&2
  exit 1
fi

BUILD_ARGS=(
  --build-arg "BUILD_TIME=$BUILD_TIME"
  --build-arg "GIT_COMMIT=$GIT_COMMIT"
  --build-arg "VERSION=$VERSION"
)
MULTI_PLATFORM=false
BUILDX_EXTRA_ARGS=()
if [[ "$PLATFORMS" == *","* ]]; then
  MULTI_PLATFORM=true
fi

echo "Repo:     $REPO"
echo "Version:  $VERSION"
echo "Platforms:$PLATFORMS"
if $TAG_LATEST; then
  echo "Latest:   enabled"
else
  echo "Latest:   disabled (beta version detected)"
fi
echo "Commit:   $GIT_COMMIT"
echo "Time:     $BUILD_TIME"

split_and_push_multiarch() {
  local selected_builder="$1"
  local platform
  local arch_suffix
  local platform_tag
  local pushed_refs=()
  local per_platform_args=()

  if [[ -n "$selected_builder" ]]; then
    per_platform_args+=(--builder "$selected_builder")
  fi

  IFS=',' read -r -a platform_list <<< "$PLATFORMS"
  for platform in "${platform_list[@]}"; do
    platform="${platform//[[:space:]]/}"
    if [[ -z "$platform" ]]; then
      continue
    fi

    arch_suffix="${platform#linux/}"
    platform_tag="$REPO:$VERSION-$arch_suffix"

    docker buildx build \
      "${per_platform_args[@]}" \
      --platform "$platform" \
      --load \
      -t "$platform_tag" \
      "${BUILD_ARGS[@]}" \
      -f "$ROOT_DIR/Dockerfile" \
      "$ROOT_DIR"

    docker push "$platform_tag"
    pushed_refs+=("$platform_tag")
  done

  docker buildx imagetools create -t "$REPO:$VERSION" "${pushed_refs[@]}"
  if $TAG_LATEST; then
    docker buildx imagetools create -t "$REPO:latest" "${pushed_refs[@]}"
  fi
}

if $PUSH; then
  if docker buildx version >/dev/null 2>&1; then
    SELECTED_BUILDER=""
    if $MULTI_PLATFORM; then
      SELECTED_BUILDER="$(ensure_container_buildx_builder "$PLATFORMS")"
      BUILDX_EXTRA_ARGS+=(--builder "$SELECTED_BUILDER")
    fi
    check_docker_hub_connectivity
    check_buildx_registry_access_from_dockerfile "$ROOT_DIR/Dockerfile"
    if $MULTI_PLATFORM; then
      split_and_push_multiarch "$SELECTED_BUILDER"
    else
      docker buildx build \
        "${BUILDX_EXTRA_ARGS[@]}" \
        --platform "$PLATFORMS" \
        --push \
        "${TAGS[@]}" \
        "${BUILD_ARGS[@]}" \
        -f "$ROOT_DIR/Dockerfile" \
        "$ROOT_DIR"
    fi
  else
    if [[ "$PLATFORMS" != "linux/amd64" ]]; then
      echo "Docker buildx is required for multi-arch builds." >&2
      exit 1
    fi
    docker build \
      "${TAGS[@]}" \
      "${BUILD_ARGS[@]}" \
      -f "$ROOT_DIR/Dockerfile" \
      "$ROOT_DIR"
    for tag in "${TAG_LIST[@]}"; do
      docker push "$tag"
    done
  fi
else
  if docker buildx version >/dev/null 2>&1; then
    if $MULTI_PLATFORM; then
      echo "Multi-arch build without push is not supported. Use --push or set -p to a single platform." >&2
      exit 1
    fi
    check_docker_hub_connectivity
    check_buildx_registry_access_from_dockerfile "$ROOT_DIR/Dockerfile"
    docker buildx build \
      "${BUILDX_EXTRA_ARGS[@]}" \
      --platform "$PLATFORMS" \
      --load \
      "${TAGS[@]}" \
      "${BUILD_ARGS[@]}" \
      -f "$ROOT_DIR/Dockerfile" \
      "$ROOT_DIR"
  else
    if [[ "$PLATFORMS" != "linux/amd64" ]]; then
      echo "Docker buildx is required for non-default platform builds." >&2
      exit 1
    fi
    docker build \
      "${TAGS[@]}" \
      "${BUILD_ARGS[@]}" \
      -f "$ROOT_DIR/Dockerfile" \
      "$ROOT_DIR"
  fi
fi
