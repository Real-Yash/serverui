# TODO — installable via package managers for everyone

Goal: `yay -S serverui-bin`, `sudo apt install server-ui` (and later `pacman -S`)
work out of the box from public repos. In-repo tooling is done
(`packaging/`, `docs/packaging.md`); what remains is publishing.

## AUR — `yay -S serverui-bin` (Arch)

- [x] `packaging/aur/serverui-bin/{PKGBUILD,.SRCINFO}` written, pinned hashes
- [x] `makepkg` build proven locally, contents verified
- [ ] Create an AUR account + upload SSH key (https://aur.archlinux.org/register/)
- [ ] Push the package:
  ```bash
  git clone ssh://aur@aur.archlinux.org/serverui-bin.git
  cp packaging/aur/serverui-bin/{PKGBUILD,.SRCINFO} serverui-bin/
  cd serverui-bin && git add PKGBUILD .SRCINFO && git commit -m "0.2.0-1" && git push
  ```
- [ ] Verify from a clean machine: `yay -S serverui-bin` (or `paru -S serverui-bin`)
- [ ] Per release: bump `pkgver`, refresh both `sha256sums`, regen `.SRCINFO`,
      test-build, push (checklist in `docs/packaging.md`)

## Official Arch repos — `sudo pacman -S serverui` (no yay needed)

- [ ] Find a Trusted User to sponsor/adopt the package into `extra`
      (AUR traction first — TUs look at votes/popularity)
- [ ] Alternative: ship a source-built `serverui` package (from `make desktop-build`)
      instead of / alongside `serverui-bin`
- [ ] Long-term alternative: self-hosted `[serverui]` repo via `repo-add`
      (snippet in `docs/packaging.md`)

## APT — `sudo apt install server-ui` (Debian/Ubuntu)

- [x] `packaging/apt/build-repo.sh` (signed repo builder, Docker-only dep)
- [x] Verified end-to-end in Ubuntu 24.04 container (key trusted, install OK)
- [x] `.github/workflows/apt-repo.yml` (release-triggered publish) — committed
      locally, **not yet pushed** (needs a token with `workflow` scope)
- [ ] Generate the real signing key, add `APT_GPG_PRIVATE_KEY` + `APT_GPG_KEY_ID`
      repo secrets (test key used so far was throwaway)
- [ ] Create + push the `apt` branch content once (workflow reuses it after that)
- [ ] Serve it: GitHub Pages from `apt` branch or `https://serverui.dev/apt`,
      then replace the placeholder URL in `docs/packaging.md` user instructions
- [ ] Verify on real Debian + Ubuntu: key install → `apt update` → `apt install server-ui`

## Upstream release-process gaps (affects all of the above)

- [ ] Publish Linux checksums: release `SHA256SUMS` currently covers macOS
      artifacts only — add `.deb` / `.AppImage` (PKGBUILD hashes depend on this)
- [ ] Decide canonical install URLs (`install.serverui.dev`, `serverui.dev/apt`)
      and DNS before printing them in docs/scripts
- [ ] `install.ps1` still needs a real Windows + Docker Desktop run

## Later / optional

- [ ] RPM (Fedora/RHEL/openSUSE) — needs an `.rpm` artifact in releases first
- [ ] Winget / Chocolatey / Scoop entries for Windows one-liners
- [ ] Homebrew cask for macOS (`brew install --cask serverui`)
