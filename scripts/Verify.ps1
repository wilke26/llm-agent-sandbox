. "$PSScriptRoot/_Common.ps1"
Assert-DockerAvailable
$containerId = (& docker compose ps --quiet agent).Trim()
if (-not $containerId) { throw 'The sandbox is not running. Run ./scripts/Start.ps1 first.' }

$failures = 0
function Pass([string]$Message) { Write-Host "PASS  $Message" -ForegroundColor Green }
function Fail([string]$Message) { Write-Host "FAIL  $Message" -ForegroundColor Red; $Script:failures++ }

$configuredUser = (& docker inspect --format '{{.Config.User}}' $containerId).Trim()
& docker compose exec -T agent sh -c 'test "$(id -u)" -ne 0'
if (($configuredUser -notmatch '^0(?::|$)') -and $LASTEXITCODE -eq 0) { Pass 'process runs as non-root' } else { Fail 'process must run as non-root' }

$readOnly = (& docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' $containerId).Trim()
& docker compose exec -T agent sh -c 'touch /etc/agent-sandbox-write-test' *> $null
if (($readOnly -eq 'true') -and $LASTEXITCODE -ne 0) { Pass 'root filesystem is read-only' } else { Fail 'root filesystem must be read-only' }

$capEff = (& docker compose exec -T agent sh -c "awk '/CapEff/ {print `$2}' /proc/1/status").Trim()
if ($capEff -match '^0+$') { Pass 'effective Linux capabilities are empty' } else { Fail "effective Linux capabilities must be empty (CapEff=$capEff)" }

$noNewPrivs = (& docker compose exec -T agent sh -c "awk '/NoNewPrivs/ {print `$2}' /proc/1/status").Trim()
if ($noNewPrivs -eq '1') { Pass 'no-new-privileges is active' } else { Fail 'no-new-privileges must be active' }

$securityOptions = (& docker info --format '{{json .SecurityOptions}}') -join ''
if ($securityOptions -match 'seccomp') { Pass 'Docker daemon reports seccomp support' } else { Fail 'Docker daemon must report seccomp support' }

[string[]]$networkIds = @(& docker inspect --format '{{range .NetworkSettings.Networks}}{{println .NetworkID}}{{end}}' $containerId) | Where-Object { $_ } | ForEach-Object { $_.Trim() }
$allInternal = $true
foreach ($networkId in $networkIds) {
    if ((& docker network inspect --format '{{.Internal}}' $networkId).Trim() -ne 'true') { $allInternal = $false }
}
if (($networkIds.Count -eq 1) -and $allInternal) { Pass 'the only attached network is internal' } else { Fail 'agent must have exactly one internal network' }

& docker compose exec -T agent curl --fail --silent --show-error --max-time 5 https://example.com *> $null
if ($LASTEXITCODE -ne 0) { Pass 'ordinary outbound HTTPS is blocked' } else { Fail 'outbound HTTPS unexpectedly succeeded' }

[string[]]$mounts = @(& docker inspect --format '{{range .Mounts}}{{println .Destination}}{{end}}' $containerId) | Where-Object { $_ }
if (($mounts.Count -eq 1) -and ($mounts[0].Trim() -eq '/workspace')) { Pass 'workspace is the only bind/volume mount' } else { Fail "unexpected bind/volume mount destinations: $($mounts -join ', ')" }

$marker = ".sandbox-write-test-$([guid]::NewGuid().ToString('N'))"
& docker compose exec -T agent sh -c "touch '/workspace/$marker' && rm '/workspace/$marker'"
if ($LASTEXITCODE -eq 0) { Pass 'workspace is writable' } else { Fail 'workspace must be writable' }

if ($failures -gt 0) { throw "Isolation verification failed: $failures check(s)." }
Write-Host "`nIsolation verification passed." -ForegroundColor Green
