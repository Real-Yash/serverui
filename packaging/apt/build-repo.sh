#!/usr/bin/env bash
#
# Build a signed APT repository from ServerUI .deb files.
#
# Everything runs inside a debian container, so the only host requirement
# is Docker. GPG signing uses a private key you provide (never committed).
#
# Usage:
#   ./build-repo.sh --deb-dir /path/to/debs --out-dir /path/to/repo \
#       --key-file /path/to/private.asc --key-id CONTACT@EXAMPLE.COM \
#       [--codename stable] [--origin ServerUI]
#
# Result in --out-dir (upload this whole directory to static hosting,
# e.g. https://serverui.dev/apt or a GitHub Pages branch):
#   dists/stable/main/binary-amd64/{Packages,Packages.gz,*.deb via pool/}
#   dists/stable/{Release,InRelease,Release.gpg}
#   serverui.gpg                     # public key users install to /usr/share/keyrings
#
# Users then run:
#   curl -fsSL https://serverui.dev/apt/serverui.gpg \
#     | sudo tee /usr/share/keyrings/serverui.gpg > /dev/null
#   echo "deb [signed-by=/usr/share/keyrings/serverui.gpg] https://serverui.dev/apt stable main" \
#     | sudo tee /etc/apt/sources.list.d/serverui.list
#   sudo apt update && sudo apt install server-ui
#
set -euo pipefail

DEB_DIR=""
OUT_DIR=""
KEY_FILE=""
KEY_ID=""
CODENAME="stable"
ORIGIN="ServerUI"

usage() {
  sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --deb-dir)  DEB_DIR="$2"; shift 2 ;;
    --out-dir)  OUT_DIR="$2"; shift 2 ;;
    --key-file) KEY_FILE="$2"; shift 2 ;;
    --key-id)   KEY_ID="$2"; shift 2 ;;
    --codename) CODENAME="$2"; shift 2 ;;
    --origin)   ORIGIN="$2"; shift 2 ;;
    -h|--help) usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

for var in DEB_DIR OUT_DIR KEY_FILE KEY_ID; do
  [ -n "${!var}" ] || { echo "Missing required --$(echo "$var" | tr 'A-Z_' 'a-z-')" >&2; exit 1; }
done
[ -d "$DEB_DIR" ] || { echo "Not a directory: $DEB_DIR" >&2; exit 1; }
[ -f "$KEY_FILE" ] || { echo "Not a file: $KEY_FILE" >&2; exit 1; }
ls "$DEB_DIR"/*.deb >/dev/null 2>&1 || { echo "No .deb files in $DEB_DIR" >&2; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker is required." >&2; exit 1; }

DEB_ABS="$(cd "$DEB_DIR" && pwd)"
OUT_ABS="$(mkdir -p "$OUT_DIR" && cd "$OUT_DIR" && pwd)"
KEY_ABS="$(cd "$(dirname "$KEY_FILE")" && pwd)/$(basename "$KEY_FILE")"

docker run --rm \
  -v "$DEB_ABS:/debs:ro" \
  -v "$OUT_ABS:/out" \
  -v "$KEY_ABS:/key/private.asc:ro" \
  -e KEY_ID="$KEY_ID" -e CODENAME="$CODENAME" -e ORIGIN="$ORIGIN" \
  -e OWNER="$(id -u):$(id -g)" \
  debian:stable-slim bash -c '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq dpkg-dev gnupg > /dev/null
gpg --batch --import /key/private.asc

REPO=/out
POOL="$REPO/pool"
BINDIR="$REPO/dists/$CODENAME/main/binary-amd64"
mkdir -p "$POOL" "$BINDIR"
cp /debs/*.deb "$POOL/"

cd "$REPO"
# NOTE: no --arch flag — dpkg-scanpackages --arch wrongly drops this .deb
# on some dpkg versions. Single-arch repo: apt filters by the binary-amd64
# path, and the control file carries Architecture: amd64.
dpkg-scanpackages pool /dev/null > "$BINDIR/Packages"
gzip -kf "$BINDIR/Packages"

# Minimal Release file covering what apt needs.
{
  echo "Origin: $ORIGIN"
  echo "Codename: $CODENAME"
  echo "Architectures: amd64"
  echo "Components: main"
  echo "Date: $(date -Ru)"
  for algo in MD5Sum SHA1 SHA256; do
    echo "$algo:"
    # Paths in Release are relative to the dists/<codename>/ directory
    # that contains the Release file itself — NOT repo-rooted.
    for f in main/binary-amd64/Packages main/binary-amd64/Packages.gz; do
      case "$algo" in
        MD5Sum) sum="$(md5sum "dists/$CODENAME/$f" | cut -d" " -f1)" ;;
        SHA1)   sum="$(sha1sum "dists/$CODENAME/$f" | cut -d" " -f1)" ;;
        SHA256) sum="$(sha256sum "dists/$CODENAME/$f" | cut -d" " -f1)" ;;
      esac
      size="$(stat -c%s "dists/$CODENAME/$f")"
      printf " %s %16s %s\n" "$sum" "$size" "$f"
    done
  done
} > "dists/$CODENAME/Release"

# InRelease must be clearsigned (--clearsign); Release.gpg is the detached twin.
gpg --batch --yes --pinentry-mode loopback --local-user "$KEY_ID" \
  --clearsign -o "dists/$CODENAME/InRelease" "dists/$CODENAME/Release"
gpg --batch --yes --pinentry-mode loopback --local-user "$KEY_ID" \
  -abs -o "dists/$CODENAME/Release.gpg" "dists/$CODENAME/Release"
gpg --batch --armor --export "$KEY_ID" > "$REPO/serverui.gpg"
chown -R "$OWNER" "$REPO"   # container runs as root; hand files back to the caller
echo "APT repo built in $REPO"
'

echo "Done. Upload $OUT_ABS to static hosting; users follow the instructions in this script header."
