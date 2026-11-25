# licenz CLI

CLI tool for license generation, verification, and management. Free to use, closed source.

Built on [licenz-core](https://github.com/matt-cochran-products/licenz) (open source, MIT).

## Installation

### macOS / Linux / WSL

```bash
curl -fsSL https://raw.githubusercontent.com/matt-cochran-products/licenz-cli/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
irm https://raw.githubusercontent.com/matt-cochran-products/licenz-cli/main/install.ps1 | iex
```

### Windows (CMD)

```cmd
curl -fsSL https://raw.githubusercontent.com/matt-cochran-products/licenz-cli/main/install.cmd -o install.cmd && install.cmd && del install.cmd
```

### Manual Installation

1. Download the appropriate binary from [Releases](https://github.com/matt-cochran-products/licenz-cli/releases/latest)
2. Extract the archive
3. Move `licenz` to a directory in your PATH (e.g., `~/.local/bin/`)
4. Make it executable: `chmod +x ~/.local/bin/licenz`

## Commands

```
licenz keygen              Generate key pairs for license signing
licenz generate            Generate a new license
licenz verify              Verify a license with policy enforcement
licenz attest              Show raw security attestation (without policy)
licenz info                Display license information
licenz hardware            Display detected hardware information
licenz support-bundle      Generate a support bundle for troubleshooting

licenz sneakernet request  Create an offline activation request
licenz sneakernet apply    Apply an offline activation response
licenz sneakernet status   Check activation request status

licenz admin unlock request   Generate a challenge code for a locked machine
licenz admin unlock apply     Apply a response code to unlock
licenz admin unlock status    Show current lockout status

licenz server login        Log in to Licenz SaaS
licenz server logout       Log out
licenz server status       Show connection status
```

Run `licenz --help` or `licenz <command> --help` for detailed usage.

## Verification

```bash
licenz --version
licenz --help
```

## Updating

Re-run the install script to update to the latest version.

## Uninstalling

```bash
rm ~/.local/bin/licenz
```

## Related

- [licenz-core](https://github.com/matt-cochran-products/licenz) - Open-source Rust library for offline license verification
- [licenz.dev](https://licenz.dev) - Managed license management platform
