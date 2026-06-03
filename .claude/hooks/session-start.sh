#!/bin/bash
# SessionStart hook — installs the Swift toolchain so the SwiftPM packages
# (notably Packages/TunerEngine, the UI-free DSP engine) can be built and
# tested in Claude Code on the web (Linux) sessions.
#
# Why this exists: LUMA is a Swift/SwiftUI app, but web sessions run on Linux
# with no Swift toolchain. The DSP engine is plain SwiftPM and — once its few
# Apple-only files are guarded with `#if canImport(...)` — builds on Linux,
# giving a real `swift test` + accuracy-benchmark loop instead of editing blind.
# SwiftUI / Metal / AppKit and the Xcode app build stay macOS/CI-only.
#
# Network policy: this needs `download.swift.org` (the official toolchain CDN)
# in the environment's allowlist. The apt mirrors and swift.org API are already
# reachable. If download.swift.org is blocked, this prints guidance and exits 0
# so the session still starts (re-running once it's allowlisted finishes setup).
set -euo pipefail

# Web (remote) sessions only — local macOS dev already has Xcode's Swift.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

SWIFT_HOME="/opt/swift"
SWIFT_BIN="$SWIFT_HOME/usr/bin"

log() { echo "[swift-setup] $*"; }

if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; else SUDO=""; fi

persist_path() {
  export PATH="$SWIFT_BIN:$PATH"
  # Make swift available to the rest of this (and the agent's) session.
  if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
    if ! grep -qs "$SWIFT_BIN" "$CLAUDE_ENV_FILE" 2>/dev/null; then
      echo "export PATH=\"$SWIFT_BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
    fi
  fi
}

# Idempotent: a prior session (or a cached container layer) already installed it.
if [ -x "$SWIFT_BIN/swift" ]; then
  persist_path
  log "Swift already installed: $("$SWIFT_BIN/swift" --version 2>/dev/null | head -1)"
  exit 0
fi

# 1. Runtime libraries Swift needs (the Ubuntu apt mirrors are allowlisted).
log "Installing OS dependencies via apt…"
export DEBIAN_FRONTEND=noninteractive
# Some containers carry extra third-party PPAs (e.g. deadsnakes, ondrej/php)
# whose host isn't in the allowlist, so their refresh 403s and apt-get update
# returns non-zero. Update tolerantly — the main Ubuntu archive (which has every
# package below) still refreshes — then install from it.
$SUDO apt-get update -qq || log "apt update partial (some third-party repos unreachable) — continuing"
if ! $SUDO apt-get install -y -qq --no-install-recommends \
  binutils git gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-s1 \
  libncurses-dev libpython3-dev libsqlite3-0 libstdc++-13-dev libxml2-dev \
  libz3-dev pkg-config tzdata unzip zlib1g-dev >/dev/null; then
  log "Some OS dependencies may not have installed; continuing anyway."
fi

# 2. Resolve the latest stable release for Ubuntu 24.04 / x86_64 from the
#    swift.org API (so there's no fragile hardcoded version/URL).
log "Resolving latest Swift release…"
if ! SWIFT_META="$(python3 - <<'PY'
import json, re, urllib.request
data = json.load(urllib.request.urlopen(
    "https://www.swift.org/api/v1/install/releases.json", timeout=30))
ok = lambda r: any("24.04" in p.get("name", "") and "x86_64" in p.get("archs", [])
                   for p in r.get("platforms", []))
ver = lambda r: tuple(int(x) for x in re.findall(r"\d+", r["name"]))
r = max((r for r in data if ok(r)), key=ver)
n, t = r["name"], r["tag"]
print(n, t, f"https://download.swift.org/swift-{n}-release/ubuntu2404/{t}/{t}-ubuntu24.04.tar.gz")
PY
)"; then
  log "Could not resolve a Swift release from swift.org; leaving session unconfigured."
  exit 0
fi
read -r SWIFT_VER SWIFT_TAG SWIFT_URL <<<"$SWIFT_META"
log "Latest is Swift ${SWIFT_VER} (${SWIFT_TAG})."

# 3. Download the toolchain. This is the only step that needs
#    download.swift.org in the allowlist — fail soft with guidance if blocked.
TARBALL="/tmp/${SWIFT_TAG}-ubuntu24.04.tar.gz"
log "Downloading ${SWIFT_URL##*/} …"
if ! curl -fsSL --retry 3 --retry-delay 2 -o "$TARBALL" "$SWIFT_URL"; then
  rm -f "$TARBALL"
  cat >&2 <<'MSG'
[swift-setup] ‼️  Could not download the Swift toolchain.
              download.swift.org is not reachable from this environment
              (network policy: "Host not in allowlist").

              Fix: add  download.swift.org  to this environment's network
              allowlist (Claude Code on the web → your environment → network
              policy → custom allowlist / full access), then start a new
              session so this hook can finish.
              Docs: https://code.claude.com/docs/en/claude-code-on-the-web
MSG
  exit 0   # don't block the session; setup resumes once the host is allowlisted
fi

# 4. Best-effort signature verification: a *bad* signature aborts, but a missing
#    gpg/keys/sig only warns (so a locked-down network can't brick the install).
if command -v gpg >/dev/null 2>&1 && curl -fsSL "${SWIFT_URL}.sig" -o "${TARBALL}.sig" 2>/dev/null; then
  if curl -fsSL https://swift.org/keys/all-keys.asc 2>/dev/null | gpg --import - >/dev/null 2>&1; then
    if gpg --verify "${TARBALL}.sig" "$TARBALL" >/dev/null 2>&1; then
      log "Signature verified."
    else
      log "‼️  Signature verification FAILED — aborting."
      rm -f "$TARBALL" "${TARBALL}.sig"
      exit 1
    fi
  else
    log "Could not import Swift signing keys; skipping signature check."
  fi
else
  log "gpg or .sig unavailable; skipping signature check."
fi

# 5. Install into /opt/swift (persisted in the cached container image).
log "Extracting to ${SWIFT_HOME}…"
$SUDO mkdir -p "$SWIFT_HOME"
$SUDO tar -xzf "$TARBALL" --strip-components=1 -C "$SWIFT_HOME"
rm -f "$TARBALL" "${TARBALL}.sig"

persist_path
log "Done: $("$SWIFT_BIN/swift" --version 2>/dev/null | head -1)"
