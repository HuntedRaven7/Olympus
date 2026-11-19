# Sealed composefs images

Hera follows the sealed image pattern from
[tartaria-dev/tartaria](https://github.com/tartaria-dev/tartaria). The important
detail is that **we do not call `mkcomposefs`/`veritysetup` ourselves**: the
composefs-capable `bootc` binary does it inside two subcommands.

## The four build stages

1. **`base`** — a normal bootc rootfs. `00-base.sh` relocates pacman state,
   initialises the keyring, adds the bootc package repo, and installs packages.
   `01-packages.sh` installs the OS. `02-finalize.sh` builds the initramfs and
   lays out the bootc directories. `bootc container lint` runs at the end.
2. **`split-kernel`** — `bootc container split-kernel-and-rootfs --rootfs / --output /kernel`
   pulls the kernel/initramfs out of the rootfs.
3. **`chunkah`** — `chunkah build --skip-special-files --max-layers 128 --prune /ostree
   --prune /sysroot/ostree --output oci:/src/out` re-chunks the rootfs into
   stable OCI layers (the `projectbluefin/actions` `chunka` approach).
4. **`sealed-finalize`** — `bootc container ukify --rootfs /target --kernel-dir
   /kernel/<kver> -- --signtool sbsign --secureboot-private-key ... --secureboot-certificate ...`
   generates composefs, adds dm-verity, assembles the UKI and signs it. The
   signed systemd-boot loader and shim/MOK manager are copied into `/boot/EFI`.

## Runtime configuration

`images/hera/config/usr/lib/ostree/prepare-root.conf`:

```ini
[composefs]
enabled = yes

[sysroot]
readonly = true
```

Kernel args in `images/hera/config/usr/lib/bootc/kargs.d/`:

- `rw` — the sysroot is read-only, but the writable overlay still needs `rw`
- `apparmor=1 lsm=landlock,lockdown,yama,integrity,apparmor` (only when sealing)
- `splash quiet`

dracut config (`30-bootcrew-*.conf`) uses `hostonly=no`, `add_dracutmodules+="
ostree bootc "`, `--reproducible --zstd`.

## Keys

| Secret | Used for |
| ------ | -------- |
| `SECUREBOOT_KEY` / `SECUREBOOT_CERT` | sign the UKI and systemd-boot; the DER cert is embedded for first-boot MOK enrollment |
| `SIGNING_SECRET` | cosign private key (must produce **legacy** `.sig` tags for bootc compatibility) |
| `GPG_KEY_DATA` / `GPG_KEY_ID` | sign the copied pacman repository built from `packages/` |

Generate development keys with `just gen-dev-keys`. Never commit private keys
or the generated `repo.gpg` private half — only the armored public key belongs
in `packages/repo.gpg`.

## Limitations

- Sealed images cannot be rebased with `bootc switch`; install them from the
  generated ISO/disk image.
- Secure Boot must be in Setup Mode on first boot so the MOK/DB key can be
  enrolled (see `mok-enroll.service`).
- CI skips sealing when secrets are absent. The resulting image is still
  composefs-capable but is **not** cryptographically sealed.
