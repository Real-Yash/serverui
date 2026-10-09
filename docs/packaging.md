# Linux packaging: AUR, pacman, and APT

How ServerUI desktop reaches Linux users without manual downloads — and how
maintainers publish new versions.

## For users

### Arch Linux / yay (recommended on Arch)

Once the package is published to AUR:

```bash
yay -S serverui-bin
```

This installs the official release binary, desktop entry, icons, and license,
pulling in `webkit2gtk-4.1`, `gtk3`, `openssl`, and `hicolor-icon-theme`.
`yay` handles AUR updates like any other package (`yay -Syu`).

### Plain pacman (custom repo)

`pacman` alone cannot see AUR. If a maintainer hosts a custom repo, add it to
`/etc/pacman.conf`:

```ini
[serverui]
SigLevel = Optional TrustAll
Server = https://serverui.dev/arch/$arch
```

then `sudo pacman -Sy serverui-bin`. (No official Arch repo yet — that needs a
Trusted User sponsor; AUR is the supported path.)

### Debian / Ubuntu (APT)

Once the repo is published:

```bash
curl -fsSL https://serverui.dev/apt/serverui.gpg \
  | sudo tee /usr/share/keyrings/serverui.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/serverui.gpg] https://serverui.dev/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/serverui.list
sudo apt update && sudo apt install server-ui
```

One-off install without a repo (works today):

```bash
sudo apt install ./ServerUI-<version>-amd64.deb
```

### Fedora / RHEL / openSUSE

No native package yet (no RPM in the release matrix). Track the release issue;
meanwhile the `.AppImage` runs anywhere with FUSE (`libfuse2` on older
distros, `fuse3`+ on new ones).

## For maintainers

### Publish to AUR

Prerequisites: an [AUR account](https://aur.archlinux.org/register/) with an
SSH key uploaded.

```bash
# From a release tag, bump packaging/aur/serverui-bin/PKGBUILD:
#   pkgver=<new version>, both sha256sums (verify the .deb extracts cleanly:
#   bsdtar -tf ServerUI-<ver>-amd64.deb > /dev/null)
cd packaging/aur/serverui-bin
makepkg --printsrcinfo > .SRCINFO
makepkg -sf --noconfirm   # proves package() works; then delete the artifacts

# Push to AUR (first time: git clone ssh://aur@aur.archlinux.org/serverui-bin.git)
cp PKGBUILD .SRCINFO /path/to/serverui-bin/
cd /path/to/serverui-bin
git add PKGBUILD .SRCINFO
git commit -m "0.2.0-1" && git push
```

Version-bump checklist: `pkgver` + `pkgrel=1`, both `sha256sums`, regenerate
`.SRCINFO`, test-build with `makepkg`. Never ship `SKIP` hashes.

### Publish the APT repo

One-time setup:

1. Create a signing key (no passphrase — it lives in CI secrets):
   `gpg --batch --passphrase '' --quick-generate-key "contact@skyrekon.com" rsa3072 sign 2y`
2. Add repo secrets `APT_GPG_PRIVATE_KEY` (armored private key) and
   `APT_GPG_KEY_ID` (email/ID).
3. Create an empty `apt` branch and serve it (GitHub Pages from branch, or sync
   it to `https://serverui.dev/apt`).

After that, every GitHub Release (or manual `apt-repo.yml` dispatch with a tag)
rebuilds the signed repo automatically via `packaging/apt/build-repo.sh`. The script
needs only Docker, so it also runs locally:

```bash
packaging/apt/build-repo.sh --deb-dir ./debs --out-dir ./repo \
  --key-file /path/to/private.asc --key-id contact@skyrekon.com
```

Verified end-to-end (Ubuntu 24.04 container): `apt update` trusts the key,
`apt install server-ui` resolves deps and installs `0.2.0`.

### Why not official Arch repos / PPA?

- Arch `extra` needs a Trusted User to adopt the package — request one once
  `serverui-bin` has AUR traction, or ship a `-git`/source `serverui` package.
- A Ubuntu PPA is redundant with the APT repo above and would split signing
  infrastructure; revisit if users ask for it.
