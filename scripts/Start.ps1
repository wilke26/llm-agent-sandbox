. "$PSScriptRoot/_Common.ps1"
Assert-DockerAvailable
Initialize-Repository
$agentImage = (& docker compose config --images | Select-Object -First 1)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($agentImage)) {
    throw 'Docker Compose did not resolve an image for the agent service.'
}
$agentImage = $agentImage.Trim()

& docker image inspect $agentImage *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Using existing agent image: $agentImage"
    & docker compose up --detach --no-build --remove-orphans agent
} else {
    Write-Host "Agent image $agentImage is not present; building the Dockerfile fallback."
    & docker compose up --detach --build --remove-orphans agent
}
if ($LASTEXITCODE -ne 0) { throw 'Failed to start the sandbox.' }
Write-Host 'Sandbox started. Run ./scripts/Verify.ps1 before use.'
