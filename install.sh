#!/bin/sh
# One-command installer for zapret-openwrt Discord+YouTube
# Usage: sh <(uclient-fetch -O- https://raw.githubusercontent.com/rikkichy/zapret-openwrt/main/install.sh)

set -e

REPO="rikkichy/zapret-openwrt"
DEST="/tmp/zapret-openwrt"
ARCHIVE="/tmp/zapret-openwrt.tar.gz"
URL="https://github.com/$REPO/archive/refs/heads/main.tar.gz"

# pick the first working download tool
fetch() {
    if command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch -O "$2" "$1"
    elif command -v curl >/dev/null 2>&1; then
        curl -sL -o "$2" "$1"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$2" "$1"
    else
        echo "ERROR: no download tool found (need uclient-fetch, curl, or wget)"
        echo "Run: opkg update && opkg install uclient-fetch"
        exit 1
    fi
}

echo ">> Downloading zapret-openwrt..."
rm -rf "$DEST" "$ARCHIVE"
fetch "$URL" "$ARCHIVE"

echo ">> Extracting..."
rm -rf "$DEST"
mkdir -p "$DEST"
tar -xzf "$ARCHIVE" -C /tmp
rm -f "$ARCHIVE"
# GitHub archives extract to reponame-branch/; move contents up
mv /tmp/zapret-openwrt-main/* "$DEST"/
rm -rf /tmp/zapret-openwrt-main

echo ">> Launching service manager..."
chmod +x "$DEST/service.sh"
exec "$DEST/service.sh"
