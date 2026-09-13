. "$PSScriptRoot/_Common.ps1"
Assert-DockerAvailable
Initialize-Repository
& docker compose up --detach --build --remove-orphans agent
if ($LASTEXITCODE -ne 0) { throw 'Failed to start the sandbox.' }
Write-Host 'Sandbox started. Run ./scripts/Verify.ps1 before use.'
