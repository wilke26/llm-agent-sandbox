. "$PSScriptRoot/_Common.ps1"
Assert-DockerAvailable
$containerId = (& docker compose ps --quiet agent).Trim()
if (-not $containerId) { throw 'The sandbox is not running. Run ./scripts/Start.ps1 first.' }

$failures = 0
function Pass([string]$Message) { Write-Host "PASS  $Message" -ForegroundColor Green }
function Show-Warning([string]$Message) { Write-Host "WARN  $Message" -ForegroundColor Yellow }
function Fail([string]$Message) { Write-Host "FAIL  $Message" -ForegroundColor Red; $Script:failures++ }

$configuredUser = (& docker inspect --format '{{.Config.User}}' $containerId).Trim()
& docker compose exec -T agent sh -c 'test "$(id -u)" -ne 0'
if ($configuredUser -and ($configuredUser -notmatch '^(root|0+)(:.*)?$') -and $LASTEXITCODE -eq 0) { Pass 'process runs as non-root' } else { Fail 'process must run as non-root' }

$readOnly = (& docker inspect --format '{{.HostConfig.ReadonlyRootfs}}' $containerId).Trim()
& docker compose exec -T agent sh -c 'touch /etc/agent-sandbox-write-test' *> $null
if (($readOnly -eq 'true') -and $LASTEXITCODE -ne 0) { Pass 'root filesystem is read-only' } else { Fail 'root filesystem must be read-only' }

$memoryValues = (& docker inspect --format '{{.HostConfig.Memory}} {{.HostConfig.MemorySwap}}' $containerId).Trim() -split '\s+'
$memoryLimit = [long]$memoryValues[0]
$memorySwapLimit = [long]$memoryValues[1]
if (($memoryLimit -gt 0) -and ($memorySwapLimit -eq $memoryLimit)) { Pass 'memory and memory-plus-swap limits match (swap disabled)' } else { Fail "memory-plus-swap limit must equal memory limit (Memory=$memoryLimit, MemorySwap=$memorySwapLimit)" }

$cgroupProbe = @'
if [ -e /sys/fs/cgroup/cgroup.controllers ]; then
  test -r /sys/fs/cgroup/memory.swap.max || exit 1
  value="$(cat /sys/fs/cgroup/memory.swap.max)"
  case "${value}" in
    max) ;;
    ""|*[!0-9]*) exit 1 ;;
  esac
  printf "v2:%s\n" "${value}"
  exit 0
fi
for base in /sys/fs/cgroup/memory /sys/fs/cgroup; do
  memory_file="${base}/memory.limit_in_bytes"
  memsw_file="${base}/memory.memsw.limit_in_bytes"
  if [ -r "${memory_file}" ] && [ -r "${memsw_file}" ]; then
    memory_value="$(cat "${memory_file}")"
    memsw_value="$(cat "${memsw_file}")"
    case "${memory_value}:${memsw_value}" in *[!0-9:]*) exit 1 ;; esac
    printf "v1:%s:%s\n" "${memory_value}" "${memsw_value}"
    exit 0
  fi
done
exit 1
'@
$cgroupSwapOutput = & docker compose exec -T agent sh -c $cgroupProbe
$cgroupProbeSucceeded = $LASTEXITCODE -eq 0
$cgroupSwapState = ($cgroupSwapOutput -join '').Trim()
$cgroupParts = $cgroupSwapState -split ':'
if ($cgroupProbeSucceeded -and ($cgroupSwapState -eq 'v2:0')) {
    Pass 'kernel cgroup swap limit disables swap (v2)'
} elseif ($cgroupProbeSucceeded -and ($cgroupSwapState -eq 'v2:max')) {
    Fail 'kernel cgroup swap limit is unlimited (v2)'
} elseif ($cgroupProbeSucceeded -and ($cgroupParts.Count -eq 3) -and ($cgroupParts[0] -eq 'v1') -and ($cgroupParts[1] -match '^[1-9][0-9]*$') -and ($cgroupParts[1] -eq $cgroupParts[2]) -and ($cgroupParts[1] -eq "$memoryLimit")) {
    Pass 'kernel cgroup swap limit disables swap (v1)'
} elseif (-not $cgroupProbeSucceeded) {
    Fail 'kernel cgroup swap accounting is unavailable or unreadable'
} else {
    Fail "kernel cgroup limits do not prove swap is disabled ($cgroupSwapState)"
}

$capEff = (& docker compose exec -T agent sh -c "awk '/CapEff/ {print `$2}' /proc/1/status").Trim()
if ($capEff -match '^0+$') { Pass 'effective Linux capabilities are empty' } else { Fail "effective Linux capabilities must be empty (CapEff=$capEff)" }

$noNewPrivs = (& docker compose exec -T agent sh -c "awk '/NoNewPrivs/ {print `$2}' /proc/1/status").Trim()
if ($noNewPrivs -eq '1') { Pass 'no-new-privileges is active' } else { Fail 'no-new-privileges must be active' }

$securityOptions = (& docker info --format '{{json .SecurityOptions}}') -join ''
if ($securityOptions -match 'seccomp') { Pass 'Docker daemon reports seccomp support' } else { Fail 'Docker daemon must report seccomp support' }
if ($securityOptions -match 'rootless|userns') { Pass 'Docker daemon reports rootless or user-namespace isolation' } else { Show-Warning 'Docker daemon does not report rootless/userns isolation; Docker Desktop may provide a separate VM boundary' }
if ($securityOptions -match 'apparmor|selinux') { Pass 'Docker daemon reports AppArmor or SELinux support' } else { Show-Warning 'Docker daemon does not report AppArmor/SELinux; this protection may be unavailable or reported differently' }

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
