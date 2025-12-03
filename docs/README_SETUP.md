# Lara-Berry Remote Setup Runner (PowerShell)

This repository contains a PowerShell script `scripts/run-lara-setup.ps1` to automate running the post-startup setup on the remote host `lara@lara-berry`.

Purpose
- Automate SSH connection to `lara@lara-berry`
- Optionally bring up the Podman compose stack
- Run `post-startup-setup.sh` on the host
- Save all stdout/stderr to `lara-setup-output.txt` locally for debugging and inspection

Usage
1. From PowerShell on your Windows machine (in the repo root):
```powershell
# Default (uses default ssh agent/key or asks for password)
.
PS> .\scripts\run-lara-setup.ps1 -Host lara-berry -User lara

# With specific key and port
PS> .\scripts\run-lara-setup.ps1 -Host 192.168.88.165 -User lara -KeyPath C:\Users\You\.ssh\id_rsa -Port 2222

# Skip compose bring-up
PS> .\scripts\run-lara-setup.ps1 -SkipCompose
```

2. The script will save the output to `lara-setup-output.txt` by default (in the repo root). Paste that output here if you want help diagnosing failures.

Notes
- The script uses `ssh` that is available in Windows 10/11 by default. If using an older Windows, install OpenSSH client.
- If your `lara` user requires a password for sudo or for SSH, the script will prompt for the password interactively.
- The script is designed to be safe: it will attempt to run `podman compose` only if `docker-compose.yml` or `docker-compose.yaml` is present.

Security
- The script does not transmit any credentials beyond your SSH key or password entered in your terminal. Keep your SSH private key secure.

Support
- Paste `lara-setup-output.txt` here if you want me to analyze the results and update the setup script accordingly.

