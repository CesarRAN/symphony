# Symphony Dotfiles — Agent Notes

This is an Arch Linux / Hyprland dotfiles repo with a custom theme engine (`symphony`). There is no package manager, build step, or test suite. The codebase is shell scripts and static configs.

## What This Repo Actually Is

- **Target OS**: Arch Linux only (uses `pacman`, AUR helpers `yay`/`paru`).
- **Deployment**: `stow` symlinks `.config/` and `.local/share/` into `$HOME`. See `.stow-local-ignore` for what is *not* deployed (notably: `scripts/`, `themes/`, `install/`, `assets/`, `branding/`, `zsh/`, root `.sh` files).
- **Installer**: `install.sh` → sources `install/{packages,stow,desktop-entries,services}.sh`, then runs `install/themes/install.sh`.
- **Uninstaller**: `uninstall.sh` runs `stow -D .`, restores `~/dotfiles-backup*`, cleans shell PATH, and optionally removes packages.

## The Symphony Theme System

The core custom tooling lives in `install/themes/`. Do not move or rename these scripts without updating the installer PATH logic.

- **`symphony` binary**: `install/themes/symphony` — added to shell PATH during install. The `DOTFILES` and `THEMES_DIR` variables resolve relative to this script's location.
- **Theme state**:
  - `~/.config/symphony/.current-theme` — plain text name of active theme.
  - `~/.config/symphony/current` — symlink to `themes/<name>` in this repo.
- **Hooks**: `install/themes/hooks/*.sh` are numbered scripts run on every `switch`/`reload`/`fix`. Each hook receives `CURRENT_LINK` and `THEMES_DIR` as env vars. Hooks exit 0 silently when their app is not running.
- **Dynamic theme** (`themes/dynamic/`): handled differently. `symphony switch dynamic` calls `$HOME/.config/hypr/scripts/change-theme` (matugen + swww) and does **not** run the usual hooks. The dynamic script then calls `symphony reload` itself.

### Key Commands

```bash
# Switch themes (interactive if no arg)
symphony switch [theme-name]

# Re-run hooks for current theme
symphony reload

# Fix broken symlinks
symphony fix

# Import an external Omarchy theme from GitHub
symphony import <user/repo>

# TUI manager (requires gum, tte, chafa)
symphony tui
```

## Theme Directory Structure

Every theme in `themes/<name>/` must contain at minimum:

```
themes/<name>/
  backgrounds/          # wallpaper images
  wallpaper             # symlink to default background (created by symphony)
  .config/              # per-app color configs (kitty, hypr, waybar, rofi, gtk, btop, cava, ghostty, alacritty, nvim, yazi, rmpc, starship, vesktop, obsidian, spicetify)
  .cache/wal/           # pywal-style colors.json and colors file (used by some hooks)
```

The `symphony-import` system (`install/themes/symphony-import/`) generates all these `.config` files from a single color palette when importing external themes. If you modify a generator, verify it works by re-importing a test theme.

## Important File/Directory Conventions

- **`.stow-local-ignore` is the source of truth** for what gets symlinked to `$HOME`. If you add a new directory at the repo root and want it deployed, you must remove it from this ignore list.
- **Desktop entries**: `install/desktop-entries.sh` copies (not symlinks) `.desktop` files into `~/.local/share/applications`. It also runs `scripts/hide-apps` to create `NoDisplay=true` overrides for system clutter. If `~/.local/share/applications` is a symlink (stow artifact), the installer removes it first.
- **Backups**: `install/stow.sh` moves existing real directories (not symlinks) from `~/.config/` and `~/.local/share/` into `~/dotfiles-backup*` before stowing.
- **Services**: `install/services.sh` enables user systemd services (`mpd`, `mpdscribble`, `bluetooth`) and sets up `gnome-keyring` and `spicetify` with hardcoded paths for multiple Spotify install variants.

## Editing Tips

- **No tests**: verify changes by running the relevant script directly or by running `install.sh` in a throwaway environment.
- **Hooks are idempotent**: they should safely exit 0 when the target app is not running. Keep them lightweight.
- **Spotify theming**: `spicetify` requires a one-time `spicetify backup apply` after Spotify is installed. The installer attempts this automatically but warns if Spotify hasn't been launched yet.
- **Shell PATH**: The installer appends `install/themes/` to `.bashrc`, `.zshrc`, or `fish/config.fish`. The `uninstall.sh` cleans these lines with `sed` matching `[Ss]ymphony` and `install/themes`.
