# orbit apt repository

A personal apt repository hosting the orbit suite of tools:

| Package | Description | Version |
|---|---|---|
| `optix` | GPU-accelerated terminal emulator (wgpu, split panes, kitty graphics) | 0.1.0-1 |
| `orbiter` | X11 application launcher with system icons | 1.0.3-1 |
| `orbit-status` | Wayland status bar with Lua plugins (Hyprland/Sway) | 1.2-1 |
| `realspeed-cli` | SamKnows-based internet speed test CLI | 1.0.0-1 |

Served over HTTPS via GitHub Pages.

## Install

```sh
# 1. Trust the signing key (so `[trusted=yes]` is not needed)
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://steven66619.github.io/orbit-apt/orbit-archive-keyring.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/orbit-archive-keyring.gpg

# 2. Add the source
echo "deb [signed-by=/etc/apt/keyrings/orbit-archive-keyring.gpg] https://steven66619.github.io/orbit-apt stable main" \
    | sudo tee /etc/apt/sources.list.d/orbit.list

# 3. Update and install
sudo apt update
sudo apt install optix orbiter orbit-status realspeed-cli
```

## Updating the repository

1. Build new `.deb` files in the source projects (`debian/rules binary`).
2. Run `./build-repo.sh <path/to/*.deb>...` from this repo's root.
3. Commit and push to `gh-pages` (Pages must be enabled on this repo, branch `gh-pages`).
