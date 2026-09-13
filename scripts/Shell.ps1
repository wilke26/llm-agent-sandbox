. "$PSScriptRoot/_Common.ps1"
Assert-DockerAvailable
$containerId = (& docker compose ps --quiet agent).Trim()
if (-not $containerId) { throw 'The sandbox is not running. Run ./scripts/Start.ps1 first.' }
& docker compose exec agent bash
if ($LASTEXITCODE -ne 0) { throw 'The sandbox shell exited with an error.' }
