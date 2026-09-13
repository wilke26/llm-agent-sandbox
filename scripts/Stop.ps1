. "$PSScriptRoot/_Common.ps1"
Assert-DockerAvailable
& docker compose down --remove-orphans
if ($LASTEXITCODE -ne 0) { throw 'Failed to stop the sandbox.' }
Write-Host 'Sandbox container and isolated network removed; workspace files were retained.'
