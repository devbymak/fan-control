#!/bin/zsh
set -eu
cd "$(dirname "$0")"
# The release workflow passes the version; a local build takes the latest release tag.
version="${FAN_CONTROL_VERSION:-$(git describe --tags --abbrev=0 --match 'v[0-9]*.[0-9]*.[0-9]*' 2>/dev/null || echo v0.0.0)}"
version="${version#v}"
if [[ ! "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then echo "Not a version: $version" >&2; exit 1; fi
mkdir -p 'Fan Control.app/Contents/MacOS' 'Fan Control.app/Contents/Resources' .build/app-icon.iconset
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" assets/app-icon.png --out ".build/app-icon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" assets/app-icon.png --out ".build/app-icon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
mkdir -p .build/module-cache
cache_path="$(cd .build/module-cache && pwd -P)"
# iconutil, not a hand-built ICNS: macOS misreads small PNGs stored under the icp4/icp5 types, so 16 and 32 point icons
# (Login Items, list views) showed noise.
iconutil -c icns .build/app-icon.iconset -o 'Fan Control.app/Contents/Resources/app-icon.icns'
xcrun swiftc -target arm64-apple-macosx13.0 -module-cache-path "$cache_path" -swift-version 5 -O -framework AppKit -framework IOKit -framework ServiceManagement -framework UserNotifications -framework Carbon sources/policy.swift sources/graph.swift sources/main.swift -o 'Fan Control.app/Contents/MacOS/fancontrol'
cat > 'Fan Control.app/Contents/Info.plist' <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>fancontrol</string>
<key>CFBundleIdentifier</key><string>local.fancontrol</string>
<key>CFBundleName</key><string>Fan Control</string>
<key>CFBundleDisplayName</key><string>Fan Control</string>
<key>CFBundleIconFile</key><string>app-icon.icns</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>$version</string>
<key>CFBundleShortVersionString</key><string>$version</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>CFBundleURLTypes</key><array><dict>
<key>CFBundleURLName</key><string>local.fancontrol</string>
<key>CFBundleURLSchemes</key><array><string>fancontrol</string></array>
</dict></array>
</dict></plist>
PLIST
# Hardened runtime: no injected libraries or debugger attachment, including in the root helper.
codesign --force --sign - --options runtime 'Fan Control.app'
echo "Built Fan Control.app $version"
if [[ "${1:-}" == "--install" ]]; then
  # Replace only an earlier Fan Control, never another app with the same name. Checked before anything is installed.
  if [[ -e '/Applications/Fan Control.app' && "$(plutil -extract CFBundleIdentifier raw -o - '/Applications/Fan Control.app/Contents/Info.plist' 2>/dev/null || true)" != local.fancontrol ]]; then
    echo '/Applications/Fan Control.app is not Fan Control; leaving it in place.' >&2; exit 1
  fi
  # Fan control runs as root only from this root-owned copy, which apps running as you cannot replace.
  # Installed first, so a cancelled password prompt leaves the running app untouched.
  sudo mkdir -p /Library/PrivilegedHelperTools
  sudo install -o root -g wheel -m 755 'Fan Control.app/Contents/MacOS/fancontrol' /Library/PrivilegedHelperTools/local.fancontrol.helper
  # Password-free fan control: lets only you run only this root-owned helper, only in the app's two forms, without a
  # password. Checked with visudo before installing, since a broken sudoers file stops sudo working. No dot in the
  # file name: sudo skips those.
  # Written straight into a folder only root can enter, so nothing running as you can change it between check and install.
  sudoers="$(sudo mktemp -d /private/var/tmp/fancontrol.XXXXXX)"
  print -r -- "$(id -un) ALL=(root) NOPASSWD: /usr/bin/env -i /Library/PrivilegedHelperTools/local.fancontrol.helper --control *, /usr/bin/env -i /Library/PrivilegedHelperTools/local.fancontrol.helper --restore" \
    | sudo tee "$sudoers/rule" >/dev/null
  if sudo visudo -cqf "$sudoers/rule"; then
    sudo install -o root -g wheel -m 440 "$sudoers/rule" /etc/sudoers.d/fancontrol
  else
    echo 'Could not set up password-free fan control; Fan Control will ask for your password each time.' >&2
  fi
  sudo rm -rf "$sudoers"
  # Quit every running copy first, wherever it was started; it restores automatic cooling before exiting. Matched by
  # bundle ID, like the app's own one-copy check, so a copy still running would also make the new one quit at launch.
  running() { [[ -n "$(lsappinfo find bundleid=local.fancontrol)" ]] }
  # A refused quit request (such as a declined Automation prompt) is caught by the check below.
  if running; then osascript -e 'tell application id "local.fancontrol" to quit' >/dev/null 2>&1 || true; fi
  for _ in {1..50}; do running || break; sleep 0.2; done
  if running; then echo 'Fan Control is still running; quit it, then run ./build.sh --install again.' >&2; exit 1; fi
  rm -rf '/Applications/Fan Control.app'
  ditto 'Fan Control.app' '/Applications/Fan Control.app'
  # Only the installed copy should handle fancontrol:// links and Launch at Login.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$PWD/Fan Control.app" 2>/dev/null || true  # Fails when it was never registered.
  open '/Applications/Fan Control.app'
  echo 'Installed and opened /Applications/Fan Control.app'
fi
