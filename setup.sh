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
# Make the bundled Linux adb executable. Git and some unzip tools drop the
# execute bit, which would make every adb call fail with "permission denied".
# ------------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/platform-tools/adb" ]; then
    chmod +x "$SCRIPT_DIR/platform-tools/adb" || true
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

echo
line
echo "COMPLETED: Node.js, Appium and UiAutomator2 are ready."
echo
echo "Open a new terminal (or run 'source ~/.profile') so ANDROID_HOME"
echo "takes effect in your shell."
line
