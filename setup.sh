#!/usr/bin/env bash
# ==============================================================================
# Linux equivalent of setup.cmd. Installs everything the NUnit tests in
# UnitTest1.cs need: Node.js, the Appium server, and the UiAutomator2 driver,
# then points ANDROID_HOME at the bundled platform-tools.
#
# The automation binary itself needs NONE of this - it drives phones through the
# adb in this folder and never talks to Appium. Only the tests do. Note the two
# cannot share a phone: Android gives the screen-reading connection to one
# program at a time, so an Appium session takes it from the automation binary.
# Stop the automation binary before running the tests, and stop the Appium
# server before running it again.
#
# Run with:   ./setup.sh      (do NOT run as root - npm -g installs into your
#                              user prefix; installing Node is the only step that
#                              may prompt for sudo).
# ==============================================================================
set -euo pipefail

# Absolute path of the folder this script lives in - contains platform-tools/adb.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

line() { printf '============================================\n'; }

# ------------------------------------------------------------------------------
# adb. Windows and x86-64 Linux builds bundle their own platform-tools and use
# it, which is what keeps every operator box on one known adb version. An aarch64
# build bundles none, because Google publishes no arm64 Linux platform-tools - so
# on a Raspberry Pi the distro's adb is installed and used instead.
#
# The bundle is chmod'ed first: git and some unzip tools drop the execute bit,
# which would make every adb call fail with "permission denied". The whole folder
# is covered, not just adb - fastboot and the rest are binaries too, and adb
# loads lib64/libc++.so from beside itself.
#
# Then it is run. "adb version" neither starts a server nor touches a device, and
# running it is the only test that catches all three ways a bundle goes wrong at
# once: wrong architecture, missing shared library, lost execute bit.
# ------------------------------------------------------------------------------
line
echo "Checking adb..."
line
BUNDLED_ADB="$SCRIPT_DIR/platform-tools/adb"
USE_BUNDLED_ADB=0

if [ -f "$BUNDLED_ADB" ]; then
    chmod -R u+rwX,go+rX "$SCRIPT_DIR/platform-tools" || true
    chmod +x "$BUNDLED_ADB" || true
    if "$BUNDLED_ADB" version >/dev/null 2>&1; then
        USE_BUNDLED_ADB=1
        echo "Using the bundled adb ($("$BUNDLED_ADB" version | head -1))."
    else
        echo "The bundled adb will not run on this machine ($(uname -m))."
        echo "Falling back to the adb installed on the system."
    fi
else
    echo "This build bundles no adb ($(uname -m)); a system adb is required."
fi

if [ "$USE_BUNDLED_ADB" -eq 0 ]; then
    if command -v adb >/dev/null 2>&1; then
        echo "adb is already installed ($(adb version | head -1)). Skipping."
    else
        echo "adb not found. Attempting to install..."
        if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y android-tools-adb
        elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y android-tools
        elif command -v pacman  >/dev/null 2>&1; then sudo pacman -Sy --noconfirm android-tools
        elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y android-tools
        else
            line
            echo "ERROR: no supported package manager found (apt/dnf/pacman/zypper)."
            echo "Install adb by hand (it is the 'android-tools-adb' or 'android-tools'"
            echo "package on most distros) then re-run."
            line
            exit 1
        fi
        command -v adb >/dev/null 2>&1 || { echo "ERROR: adb install did not succeed."; exit 1; }
        echo "adb installed ($(adb version | head -1))."
    fi
fi

# ------------------------------------------------------------------------------
# Node.js. Install through whichever package manager the distro ships if node is
# missing; otherwise tell the user where to get it rather than guessing.
# ------------------------------------------------------------------------------
line
echo "Checking Node.js..."
line
if command -v node >/dev/null 2>&1; then
    echo "Node.js is already installed ($(node -v)). Skipping."
else
    echo "Node.js not found. Attempting to install..."
    if   command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y nodejs npm
    elif command -v dnf     >/dev/null 2>&1; then sudo dnf install -y nodejs npm
    elif command -v pacman  >/dev/null 2>&1; then sudo pacman -Sy --noconfirm nodejs npm
    elif command -v zypper  >/dev/null 2>&1; then sudo zypper install -y nodejs npm
    else
        line
        echo "ERROR: no supported package manager found (apt/dnf/pacman/zypper)."
        echo "Install Node.js 18+ by hand from https://nodejs.org/ then re-run."
        line
        exit 1
    fi
    command -v node >/dev/null 2>&1 || { echo "ERROR: Node.js install did not succeed."; exit 1; }
    echo "Node.js installed ($(node -v))."
fi

# ------------------------------------------------------------------------------
# Appium. "appium -v" prints a version and exits 0 when installed.
# ------------------------------------------------------------------------------
echo
line
echo "Checking Appium..."
line
if appium -v >/dev/null 2>&1; then
    echo "Appium is already installed ($(appium -v)). Skipping."
else
    echo "Appium not found. Installing (npm install -g appium)..."
    npm install -g appium
fi

# ------------------------------------------------------------------------------
# UiAutomator2 driver. Present in the installed-driver list only if installed.
# ------------------------------------------------------------------------------
echo
line
echo "Checking UiAutomator2 driver..."
line
if appium driver list --installed 2>&1 | grep -qi uiautomator2; then
    echo "UiAutomator2 driver is already installed. Skipping."
else
    echo "UiAutomator2 driver not found. Installing..."
    appium driver install uiautomator2
fi

# ------------------------------------------------------------------------------
# ANDROID_HOME. Point it (and ANDROID_SDK_ROOT) at this folder so Appium's
# uiautomator2 driver finds platform-tools/adb. Persist it in the user's shell
# profile, and export it for the current shell too. Written once - a marker
# comment stops repeat runs from stacking duplicate lines.
# ------------------------------------------------------------------------------
echo
line
echo "Setting ANDROID_HOME..."
line
PROFILE="${HOME}/.profile"
MARKER="# added by automation setup.sh"

# ANDROID_HOME names an SDK root - the folder *containing* platform-tools - so it
# can only be set when there is a bundled platform-tools to point at. With a
# system adb there is no SDK tree, and pointing ANDROID_HOME at this folder would
# send Appium looking for platform-tools/adb here and finding nothing. Unset, it
# falls through to PATH, where the installed adb already is.
if [ "$USE_BUNDLED_ADB" -eq 1 ]; then
    if ! grep -qF "$MARKER" "$PROFILE" 2>/dev/null; then
        {
            echo ""
            echo "$MARKER"
            echo "export ANDROID_HOME=\"$SCRIPT_DIR\""
            echo "export ANDROID_SDK_ROOT=\"$SCRIPT_DIR\""
        } >> "$PROFILE"
        echo "ANDROID_HOME written to $PROFILE"
    else
        echo "ANDROID_HOME already present in $PROFILE. Skipping."
    fi
    export ANDROID_HOME="$SCRIPT_DIR"
    export ANDROID_SDK_ROOT="$SCRIPT_DIR"
    echo "ANDROID_HOME set to:"
    echo "  $SCRIPT_DIR"
else
    echo "adb comes from the system here, not from this folder, so there is no"
    echo "SDK root to point ANDROID_HOME at. Leaving it unset - Appium and the"
    echo "automation both fall back to the adb on PATH:"
    echo "  $(command -v adb)"
    if grep -qF "$MARKER" "$PROFILE" 2>/dev/null; then
        echo
        echo "NOTE: $PROFILE still exports ANDROID_HOME from an earlier run of this"
        echo "script. Remove the block marked '$MARKER' or it will point Appium at"
        echo "a platform-tools folder that does not exist here."
    fi
fi

echo
line
echo "COMPLETED: adb, Node.js, Appium and UiAutomator2 are ready."
echo
echo "Open a new terminal (or run 'source ~/.profile') so ANDROID_HOME"
echo "takes effect in your shell."
line
