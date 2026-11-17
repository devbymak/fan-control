<div align="center">

# Fan Control: Mac fan curves and temperature monitor

**A free, open-source menu bar app for Apple silicon Macs.**
See CPU, GPU, battery and SSD temperatures at a glance, and take control of your fans when macOS waits too long.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-black?logo=apple)
![Apple silicon M1–M5](https://img.shields.io/badge/Apple%20silicon-M1%E2%80%93M5-blue)
![Swift](https://img.shields.io/badge/Swift-native-orange?logo=swift&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

</div>

<p align="center">
  <img src="assets/cover.png" alt="Fan Control on a Mac: CPU temperature and fan speed stacked in the menu bar, the popover with CPU, GPU, battery and SSD temperatures, 10-minute temperature and fan graphs, the Off, Curve and Fixed switch and a draggable fan curve set to Balanced, and the Settings window's Appearance page, next to a list of features">
</p>

## Why Fan Control?

macOS keeps the fans quiet until your Mac is already hot. That's fine for email, but during a long export, build or game your MacBook Pro can throttle before the fans catch up. Fan Control lets you cool it down earlier, and hands control back to macOS when you're done.

- 🌡️ **Live temperatures in the menu bar.** CPU, GPU, battery and SSD readings and fan RPM, side by side or stacked, colored green, yellow or red. The popover adds power draw and thermal pressure.
- 📈 **10-minute history graphs** of temperature and fan speed, right in the popover.
- 🌀 **Custom fan curve.** Drag four temperature → RPM points right in the popover, or start from the System, Balanced or Performance preset. Fan Control only speeds the fans up, never below the speed macOS was running when Curve took over, and enforces a safe minimum.
- 🎚️ **Fixed speed.** Hold the fans at a speed you pick with a slider, within limits you set.
- 🚀 **One-key Max.** Full fan speed from the right-click menu, or <kbd>⌃</kbd><kbd>⌥</kbd><kbd>M</kbd> from any app.
- ⚡ **Automation.** Switch to Curve or Max when you plug in, and turn fan control off on battery. Also works with Shortcuts, `fancontrol://` links and a command-line tool.
- 🛡️ **Safety first.** Fans go back to macOS automatic control on quit, sleep, a crash, overheating or a sensor failure.
- 🔒 **Private and lightweight.** Native Swift and SwiftUI with no dependencies, no network access, no analytics and no logs.

## Fan modes

| Mode | What it does |
| --- | --- |
| **Off** | macOS controls the fans, as usual. |
| **Curve** | Your temperature → RPM curve, used only when it wants more cooling than macOS. |
| **Fixed** | A speed you pick with the slider, within the limits in Settings → Fans. |
| **Max** | Fans at full speed until you choose another mode. Start it from the right-click menu or <kbd>⌃</kbd><kbd>⌥</kbd><kbd>M</kbd>; it shows in the popover's switch while it runs. |

Off, Curve and Fixed sit in the popover's switch. The mode you pick stays on until you choose Off, and starts again when Fan Control opens.

## Install

You need an Apple silicon Mac (M1 to M5) and macOS 13 or later. Install with [Homebrew](https://brew.sh):

```sh
brew tap devbymak/tap
brew trust devbymak/tap
brew install --cask fan-control
```

Homebrew asks you to trust taps from outside Homebrew before it installs from them. Fan Control isn't notarized by Apple (that needs a paid developer account), so the cask clears macOS's download warning for you. It also asks for your password once, to install the fan-control helper and its sudo rule described below. `brew upgrade` keeps the app and helper in step.

To build from source instead, you also need the Xcode Command Line Tools (`xcode-select --install`):

```sh
git clone https://github.com/devbymak/fan-control.git
cd fan-control
./build.sh --install
```

This builds the app, installs a small root-owned fan-control helper, and copies Fan Control to `/Applications`. It asks for your password once, to install the helper and a sudo rule (`/etc/sudoers.d/fancontrol`) that lets your account start only that helper without a password. After that, Fan Control switches modes without asking and starts the mode you last picked when it opens.

**Supported Macs:** Apple silicon Macs with fans, including two-fan 14" and 16" MacBook Pro models (both fans move together). On a fanless MacBook Air, Fan Control shows temperatures only. Run `fancontrol status` to see the chip, fans and sensors it found.

<details>
<summary><b>Shortcuts, links and command line</b></summary>

Turn on Settings → Automation → Shortcuts, links, and command line first. It's off by default because any app or web page can open a link. Fan Control still asks for confirmation before it starts cooling or sets a fixed speed.

- **Shortcuts:** add an *Open URLs* action with `fancontrol://off`, `fancontrol://curve`, `fancontrol://max` or `fancontrol://fixed?rpm=3000`.
- **Terminal:** installed with Homebrew, `fancontrol` is already on your PATH. Built from source, link it first:

  ```sh
  ln -s /Applications/Fan Control.app/Contents/MacOS/fancontrol /usr/local/bin/fancontrol
  fancontrol status        # read-only readings
  fancontrol max           # or off, curve, fixed 3000
  ```

</details>

<details>
<summary><b>Uninstall</b></summary>

Installed with Homebrew: `brew uninstall --cask fan-control` removes the app, the helper and the sudo rule (add `--zap` to remove your settings too).

Built from source: choose Off, quit Fan Control, delete the app, then run:

```sh
sudo rm -f /Library/PrivilegedHelperTools/local.fancontrol.helper /var/db/local.fancontrol.lock /etc/sudoers.d/fancontrol
```

</details>

## Safety

> [!WARNING]
> Fan Control is experimental. It uses Apple's undocumented SMC interface, and fan control has not been verified on every Mac. Use it at your own risk.

<details>
<summary><b>How Fan Control keeps your Mac safe</b></summary>

- **Curve** never runs below a safe minimum for the current temperature (the fans' minimum up to 80°C, a quarter of their range at 90°C, half at 95°C). Apple silicon routinely runs above 90°C under load while macOS keeps the fans quiet, so Curve lets you place points up to 99°C. It switches to full speed at 100°C CPU/GPU, a 45°C battery, a 70°C SSD or high thermal pressure, and hands the fans back to macOS once macOS's own speed is enough. It follows a smoothed temperature so the fans don't hunt, but the safe minimum and cutoffs use the raw readings. While Curve holds the fans, macOS's live choice can't be read, so Curve won't follow a rise macOS would make for sensors Fan Control doesn't watch; the safe minimum and these cutoffs cover that.
- **Fixed** never runs below its own safe minimum (the fans' minimum up to 65°C, a quarter of their range at 72°C, half at 78°C): when your Mac warms up, the helper raises the speed you picked to it. It only starts below 75°C, never goes under 1000 RPM, and turns fan control off at 80°C, a hot battery or SSD, high thermal pressure or a sensor failure.
- **Max** has no cutoff because it never lowers fan speed.
- **Watchdogs:** the root helper hands the fans back to macOS if the app stops responding for 10 seconds, and a separate watchdog does the same if the helper itself stalls for 15 seconds.
- **Least privilege:** only a root-owned helper runs as root, never the app bundle, and the app checks that helper before starting it. The sudo rule covers only that helper, so any app running as you can start it without a password, but only within the limits above. Apple's thermal services are never disabled.

These are conservative software limits, not certified safety limits. If automatic control can't be restored, restart your Mac. Don't run other fan-control apps at the same time.

</details>

## FAQ

**Is Fan Control free?** Yes. It's open source under the MIT license.

**Does it work on M4 and M5 Macs?** Yes, M1 through M5 are supported. A newer chip still shows temperatures and offers Off and Max until its sensors are added.

**Will it drain my battery?** Fan Control is a small native app that reads sensors once a second. The helper runs only while you use Curve, Fixed or Max, and you can turn fan control off on battery.

## Credits

Sensor-key reference: [Stats](https://github.com/exelban/stats/blob/master/Modules/Sensors/values.swift).

## License

MIT. See [license](license).
