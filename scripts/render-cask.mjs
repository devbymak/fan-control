// Writes Fan Control's Homebrew cask for a release, pinned to its version and zip checksum.
// usage: node scripts/render-cask.mjs <cask.rb> <version> <sha256>
import { existsSync, readFileSync, writeFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import { compareVersions } from './next-version.mjs'

/** Must match the helper path in sources/main.swift and the sudo rule in build.sh. */
const HELPER = '/Library/PrivilegedHelperTools/local.fancontrol.helper'

export function renderCask({ version, sha256 }) {
  compareVersions(version, version) // throws unless it's X.Y.Z
  if (!/^[0-9a-f]{64}$/.test(sha256)) throw new Error(`Not a sha256: ${sha256}`)
  return `cask "fan-control" do
  version "${version}"
  sha256 "${sha256}"

  url "https://github.com/devbymak/fan-control/releases/download/v#{version}/FanControl-#{version}.zip"
  name "Fan Control"
  desc "Menu bar temperatures and fan control for Apple silicon Macs"
  homepage "https://github.com/devbymak/fan-control"

  depends_on arch: :arm64
  depends_on macos: :ventura

  app "Fan Control.app"
  binary "#{appdir}/Fan Control.app/Contents/MacOS/fancontrol"

  # Same steps as ./build.sh --install: fan control runs only from a root-owned copy of the app's binary, which
  # must match the installed app, so every install and upgrade replaces it. Asks for your password once.
  postflight_steps do
    # Fan Control is distributed outside Apple's notarization service.
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Fan Control.app"]
    run "/bin/mkdir", args: ["-p", "/Library/PrivilegedHelperTools"], sudo: true
    run "/usr/bin/install",
        args: ["-o", "root", "-g", "wheel", "-m", "755", "{{appdir}}/Fan Control.app/Contents/MacOS/fancontrol",
               "${HELPER}"],
        sudo: true
    # Password-free fan control: lets only you run only this helper, only in the app's two forms. Checked with
    # visudo before installing, since a broken sudoers file stops sudo working. Written in a folder only root can
    # enter, so nothing running as you can change it between check and install.
    run "/bin/sh", args: ["-c", <<~'SH', "sh", "{{user}}"], sudo: true
      set -eu
      case "$1" in ""|*[!A-Za-z0-9._-]*) echo "Unexpected user name: $1" >&2; exit 1 ;; esac
      folder=$(/usr/bin/mktemp -d /private/var/tmp/fancontrol.XXXXXX)
      trap '/bin/rm -rf "$folder"' EXIT
      helper=${HELPER}
      printf '%s ALL=(root) NOPASSWD: /usr/bin/env -i %s --control *, /usr/bin/env -i %s --restore\\n' \\
        "$1" "$helper" "$helper" > "$folder/rule"
      if /usr/sbin/visudo -cqf "$folder/rule"; then
        /usr/bin/install -o root -g wheel -m 440 "$folder/rule" /etc/sudoers.d/fancontrol
      else
        echo "Could not set up password-free fan control; Fan Control will ask for your password each time." >&2
      fi
    SH
  end

  # Quitting hands the fans back to macOS before anything is removed.
  uninstall quit:   "local.fancontrol",
            delete: [
              "/etc/sudoers.d/fancontrol",
              "${HELPER}",
              "/var/db/local.fancontrol.lock",
            ]

  zap trash: "~/Library/Preferences/local.fancontrol.plist"
end
`
}

/** The version a cask is pinned to; null when there's no cask yet. */
export function caskVersion(text) {
  return /^\s*version "(\d+\.\d+\.\d+)"/m.exec(text)?.[1] ?? null
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [file, version, sha256] = process.argv.slice(2)
  const current = existsSync(file) ? caskVersion(readFileSync(file, 'utf8')) : null
  // Re-running an old release's job must not move Homebrew users back.
  if (current && compareVersions(version, current) < 0) throw new Error(`The cask is already at ${current}, newer than ${version}`)
  writeFileSync(file, renderCask({ version, sha256 }))
}
