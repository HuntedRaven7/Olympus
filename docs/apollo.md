# Apollo

Apollo is the workstation image: Hera plus a minimal Wayland desktop built
around [MangoWC](https://github.com/DreamMaoMao/mango) and
[Quickshell](https://quickshell.org/).

## Included

- `mangowm-git` (provides the `mango` binary) and `quickshell-git` from the AUR
- `greetd` + `tuigreet` for login, `seatd` for seat management
- `xdg-desktop-portal` (+ `xdg-desktop-portal-gtk`), `dbus`, `pipewire`,
  `wireplumber`, `pipewire-pulse`, `alsa-lib`, `libva-mesa-driver`,
  `mesa`
- fonts (`noto-fonts`, `noto-fonts-emoji`), `gtk3`, `qt6-base`, `qt6-wayland`
- `xdg-utils`, `xwayland`, `wl-clipboard`, `polkit`

## Quickshell configuration

**Intentionally absent.** Apollo installs the `quickshell` binary and provides
a single system-level launch hook (`/usr/lib/systemd/user/quickshell.service`)
that runs `quickshell` with no arguments. Your personal QML config will be
ported into `images/apollo/config/usr/share/apollo/quickshell/` later.

A minimal `mangowm` config is included only to bind the `quickshell` launch;
it contains no theming or keybindings.

## Build & run

```sh
just build apollo
just test-boot apollo
```
