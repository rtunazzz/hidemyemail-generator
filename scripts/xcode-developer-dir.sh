#!/usr/bin/env bash
set -euo pipefail

# HME-Gen-icon.icon is an Icon Composer document, which only actool from Xcode 26
# onwards can compile. The macOS runner images ship Xcode 26 but keep
# /Applications/Xcode.app pointed at 16.4, so resolve a qualifying Xcode instead
# of trusting the default symlink.
MIN_XCODE_MAJOR=26

if [[ -n "${DEVELOPER_DIR:-}" ]]; then
  echo "$DEVELOPER_DIR"
  exit 0
fi

shopt -s nullglob
for app in /Applications/Xcode.app /Applications/Xcode-beta.app /Applications/Xcode_*.app; do
  [[ -d "$app/Contents/Developer" ]] || continue
  major="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$app/Contents/version.plist" 2>/dev/null | cut -d. -f1)"
  if [[ "${major:-0}" -ge "$MIN_XCODE_MAJOR" ]]; then
    echo "$app/Contents/Developer"
    exit 0
  fi
done

echo "Xcode $MIN_XCODE_MAJOR or newer is required to compile HME-Gen-icon.icon; none found in /Applications." >&2
exit 1
