<#
PowerShell helper to run post-startup setup on remote host `lara@lara-berry`.

Usage examples:
.
# Default usage: uses ssh keys from agent or default key
.
PS> .\scripts\run-lara-setup.ps1 -Host lara-berry -User lara

# With key and a custom port (e.g., 2222)
PS> .\scripts\run-lara-setup.ps1 -Host 192.168.88.165 -User lara -KeyPath C:\Users\you\.ssh\id_rsa -Port 2222

# Skip podman compose bring-up (if you prefer to bring up containers manually first)
PS> .\scripts\run-lara-setup.ps1 -SkipCompose
#>

param(
    [Parameter(Position=0)]
    [string]$Host = 'lara-berry',

    [Parameter(Position=1)]
    [string]$User = 'lara',

    [string]$KeyPath = '',
    [int]$Port = 22,
    [string]$OutputFile = './lara-setup-output.txt',
    [switch]$SkipCompose,
    [switch]$VerboseMode
)

function BuildRemoteScriptContent {
    param($SkipCompose)

    $script = @'
cd ~/lara-berry || cd /home/lara/lara-berry || cd /opt/lara-berry || pwd
pwd
ls -la
sed -n "1,40p" post-startup-setup.sh || true

# Check Podman and bring up stack except if asked to skip
if ! $SKIP_COMPOSE; then
    if command -v podman >/dev/null 2>&1; then
        if podman compose version >/dev/null 2>&1; then
            podman compose pull || true
            podman compose up -d || true
        elif command -v podman-compose >/dev/null 2>&1; then
            podman-compose pull || true
            podman-compose up -d || true
        else
            echo 'No podman compose plugin available; skipping compose bring-up.'
        fi
    else
        echo 'Podman not installed on host (or not in PATH).'
    fi
fi

# Make the script executable and run it
chmod +x post-startup-setup.sh || true
sudo ./post-startup-setup.sh || ./post-startup-setup.sh || true

# Output ps/podman statuses
if command -v podman >/dev/null 2>&1; then
    podman ps -a || true
    podman pod ps || true
    podman logs -l || true
fi

'@

    # Replace the variable with the boolean literal for the remote shell
    if ($SkipCompose) { $script = $script -replace '\$SKIP_COMPOSE', 'true' } else { $script = $script -replace '\$SKIP_COMPOSE', 'false' }
    return $script
}

# Build the remote script content
$remoteCommands = BuildRemoteScriptContent -SkipCompose:$SkipCompose.IsPresent

# Create a temporary file locally to hold the script for redirection
$tempFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tempFile -Value $remoteCommands -Encoding UTF8

# Prepare ssh command arguments
$sshArgs = @()
if ($Port -ne 22) { $sshArgs += '-p'; $sshArgs += $Port }
if ($KeyPath -ne '') { $sshArgs += '-i'; $sshArgs += $KeyPath }
$sshArgs += "$User@$Host"
$sshArgs += 'bash -s'

# Run the remote script over ssh and capture output
Write-Host "Running remote commands on $User@$Host (port $Port) — output will be saved to $OutputFile"

if ($VerboseMode) { Write-Host "SSH args: $sshArgs" }

try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'ssh'
    $psi.Arguments = ($sshArgs -join ' ')
    # Use redirected standard input from the temporary file
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    $started = $proc.Start()

    if (-not $started) { throw 'Failed to start ssh' }

    # Stream the local temp file content into ssh stdin
    Get-Content -Path $tempFile -Raw | Out-String | % { $proc.StandardInput.Write($_) }
    $proc.StandardInput.Close()

    $stdOut = $proc.StandardOutput.ReadToEnd()
    $stdErr = $proc.StandardError.ReadToEnd()

    $proc.WaitForExit()
    $exitCode = $proc.ExitCode

    # Save combined output
    $combined = "STDOUT:\n$stdOut\nSTDERR:\n$stdErr\nExitCode: $exitCode"
    $combined | Tee-Object -FilePath $OutputFile

    if ($exitCode -ne 0) {
        Write-Error "Remote script exited with code $exitCode. Check the output file: $OutputFile"
    } else {
        Write-Host "Remote setup executed, output saved to $OutputFile"
    }
}
catch {
    Write-Error "Error running SSH command: $_"
    exit 1
}
finally {
    Remove-Item -Path $tempFile -ErrorAction SilentlyContinue
}

Write-Host 'Remote run finished.'
