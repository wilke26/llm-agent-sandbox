$ErrorActionPreference = 'Stop'
$Script:RepoDir = Split-Path -Parent $PSScriptRoot
Set-Location $Script:RepoDir

function Assert-DockerAvailable {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker is not installed or not on PATH.'
    }
    & docker compose version *> $null
    if ($LASTEXITCODE -ne 0) { throw "Docker Compose v2 ('docker compose') is required." }
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) { throw 'The Docker daemon is not available.' }
}

function Initialize-Repository {
    if (-not (Test-Path '.env')) {
        Copy-Item '.env.example' '.env'
        $isLinux = [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Linux)
        $idCommand = Get-Command id -ErrorAction SilentlyContinue
        if ($isLinux -and $idCommand) {
            $hostUid = (& id -u).Trim()
            $hostGid = (& id -g).Trim()
            if (($hostUid -match '^\d+$') -and ([int]$hostUid -ge 1000) -and ($hostGid -match '^\d+$')) {
                $envContent = Get-Content '.env'
                $envContent = $envContent -replace '^AGENT_UID=.*$', "AGENT_UID=$hostUid"
                $envContent = $envContent -replace '^AGENT_GID=.*$', "AGENT_GID=$hostGid"
                Set-Content -Path '.env' -Value $envContent -Encoding utf8
                Write-Host "Mapped the container user to host UID:GID ${hostUid}:${hostGid}."
            }
        }
        Write-Host 'Created .env from .env.example; review it before sensitive workloads.'
    }
    New-Item -ItemType Directory -Force 'workspace' | Out-Null
}
