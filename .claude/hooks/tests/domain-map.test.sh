#!/bin/bash
# Tests for lib/domain-map.sh get_domains() cross-cutting resolution.
# Run:  bash .claude/hooks/tests/domain-map.test.sh
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/lib/domain-map.sh"
PASS=0; FAIL=0
want() { # want <path> <domain>
  if get_domains "$1" | grep -qx "$2"; then PASS=$((PASS+1)); printf '  ok   %s -> %s\n' "$1" "$2"
  else FAIL=$((FAIL+1)); printf '  FAIL %s -> %s (got: %s)\n' "$1" "$2" "$(get_domains "$1" | tr '\n' ',')"; fi
}
deny() { # deny <path> <domain>
  if get_domains "$1" | grep -qx "$2"; then FAIL=$((FAIL+1)); printf '  FAIL %s should NOT map to %s\n' "$1" "$2"
  else PASS=$((PASS+1)); printf '  ok   %s !-> %s\n' "$1" "$2"; fi
}
want "/r/App/Account/KeychainStore.swift"        security
want "/r/App/Account/KeychainStore.swift"        swiftui
want "/r/App/Networking/LumaAPI.swift"           security
want "/r/App/Info.plist"                         security
want "/r/App/LUMA.entitlements"                  security
want "/r/App/PrivacyInfo.xcprivacy"              security
want "/r/Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StateLine.swift" accessibility
want "/r/Packages/LumaDesignSystem/Sources/LumaDesignSystem/Components/StateLine.swift" design-system
want "/r/Packages/LumaDesignSystem/Sources/LumaDesignSystem/Strobe/AuroraStrobe.swift"  accessibility
want "/r/App/LiveTunerScreen.swift"              accessibility
deny "/r/Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift" security
deny "/r/Packages/TunerEngine/Sources/TunerEngine/DSP/PitchDetector.swift" accessibility
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
