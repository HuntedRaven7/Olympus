# Secrets and variables

No secret is required to build an unsealed image. The sealed + signed pipeline
uses the following repository secrets:

| Name | Kind | Purpose |
| ---- | ---- | ------- |
| `SIGNING_SECRET` | secret | cosign private key (PEM). Public key committed as `cosign.pub`. |
| `SECUREBOOT_KEY` | secret | PEM private key used by `bootc container ukify` and `sbsign`. |
| `SECUREBOOT_CERT` | secret | PEM certificate matching `SECUREBOOT_KEY`. |
| `GPG_KEY_DATA` | secret | armored private GPG key that signs the pacman repo built from `packages/`. |
| `GPG_KEY_ID` | variable | fingerprint of `GPG_KEY_DATA` (not secret). |
| `BOOTC_REPO_URL` | variable | optional override for the pacman repo used by Hera. |

## Generating and uploading secrets with `gh`

All commands below run locally. Start by authenticating and selecting this
repository so you can omit `--repo` from the later commands:

```sh
gh auth login
gh repo set-default HuntedRaven7/Olympus
# Or pass --repo HuntedRaven7/Olympus on every command.
```

> Secrets are write-only: `gh secret list` shows names only, never values. Keep
> the private key files safe (or delete them after upload) — they cannot be
> retrieved from GitHub again.

### 1. cosign signing key (`SIGNING_SECRET`)

Generate a key pair with an **empty password** (the signing step does not set
`COSIGN_PASSWORD`; for a passphrase-protected key you would also need to add
that as a secret and pass it to cosign):

```sh
mkdir -p /tmp/olympus-keys && cd /tmp/olympus-keys
COSIGN_PASSWORD="" cosign generate-key-pair       # writes cosign.key + cosign.pub
cp cosign.pub /path/to/Olympus/cosign.pub          # commit the public half
cd /path/to/Olympus && git add cosign.pub

gh secret set SIGNING_SECRET < /tmp/olympus-keys/cosign.key
rm -f /tmp/olympus-keys/cosign.key                 # optional, after verifying CI
```

`cosign.pub` in this repo is the public half that verifiers use.

### 2. Secure Boot key and certificate (`SECUREBOOT_KEY`, `SECUREBOOT_CERT`)

```sh
openssl req -new -x509 -newkey rsa:2048 -nodes \
    -keyout secureboot.key -out secureboot.crt \
    -days 3650 -subj "/CN=Olympus Secure Boot/"

# The DER form is embedded in the image for first-boot MOK enrollment.
openssl x509 -in secureboot.crt -outform DER -out secureboot.der

gh secret set SECUREBOOT_KEY  < secureboot.key
gh secret set SECUREBOOT_CERT < secureboot.crt
rm -f secureboot.key
```

Keep `secureboot.der` only if you need to enroll the key manually; the sealed
build embeds the certificate itself via `03-ukify.sh`.

### 3. Pacman repository GPG key (`GPG_KEY_DATA`, `GPG_KEY_ID`)

Use a temporary GNUPGHOME so this key never mixes with your personal keyring:

```sh
export GNUPGHOME=$(mktemp -d); chmod 700 "$GNUPGHOME"

gpg --batch --yes --pinentry-mode loopback --passphrase '' \
    --quick-generate-key \
    'Olympus (bootc repo key) <olympus@users.noreply.github.com>' \
    rsa4096 sign 0

fpr=$(gpg --list-secret-keys --with-colons | awk -F: '/^fpr/{print $10; exit}')
echo "$fpr"

gpg --armor --export-secret-keys "$fpr" > repo.key   # private: upload as secret
gpg --armor --export "$fpr" > packages/repo.gpg      # public: commit this file

git add packages/repo.gpg
gh secret set GPG_KEY_DATA < repo.key
gh variable set GPG_KEY_ID --body "$fpr"
rm -f repo.key
```

The public key must be committed because consumers import it with
`pacman-key --recv-key "$GPG_KEY_ID"`.

### 4. Optional pacman repo override (`BOOTC_REPO_URL`)

Only needed if you are not using the repository published from `packages/`:

```sh
gh variable set BOOTC_REPO_URL \
  --body 'https://github.com/HuntedRaven7/Olympus/releases/download/$repo'
```

### 5. Verify and trigger a build

```sh
gh secret list        # names only
gh variable list

gh workflow run build-hera.yml --ref main
gh run list --workflow build-hera.yml --limit 5
gh run view --log     # inspect the "sealed"/"signed" lines in the job summary
```

To rotate or remove a value later:

```sh
gh secret set SIGNING_SECRET < new-cosign.key    # overwrite
gh secret delete SIGNING_SECRET
gh variable delete GPG_KEY_ID
```

## Behaviour when secrets are missing

- **Secure Boot**: CI builds the unsealed variant; a note is written to the
  job summary. No sealed image is published.
- **cosign**: the `sign-and-publish` step is skipped and the workflow emits a
  warning. Published images are therefore unsigned until `SIGNING_SECRET` is
  configured — enable the repository rule requiring signatures only after the
  key is in place.
- **pacman repo build**: the `packages/` workflow skips publication; Hera uses
  the URL in `BOOTC_REPO_URL` (default: the upstream arch-bootc-pkgs release).

## Rotation

Generate development keys with `just gen-dev-keys` (writes to `.drift/` which is
git-ignored). For production, generate keys offline, commit only the armored
public halves (`cosign.pub`, `packages/repo.gpg`), and store private halves as
sealed repository secrets.

The public keys currently committed were generated as **development keys**:

- cosign public key: `cosign.pub`
- pacman repo key fingerprint (`GPG_KEY_ID`): `2465D8CB18884D954FBEAAD6EB6C697EC5B5E936`

Replace both before publishing anything you rely on.
