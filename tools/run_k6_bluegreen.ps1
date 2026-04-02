param(
  [string]$Namespace = "openemr",
  [string]$PromRwUrl = "http://localhost:9090/api/v1/write",
  [string]$BaseUrl = "http://127.0.0.1:30080",
  [int]$MinReplicas = 1,
  [int]$MaxReplicas = 5
)

$ErrorActionPreference = "Stop"
$k6out = "experimental-prometheus-rw=$PromRwUrl"

function Deployment-Exists([string]$name) {
  $result = kubectl get deployment $name -n $Namespace -o name --ignore-not-found
  return -not [string]::IsNullOrWhiteSpace($result)
}

function Set-ServiceColor([string]$color) {
  Write-Host "Switch service to $color" -ForegroundColor Cyan
  $patch = '{"spec":{"selector":{"app":"openemr","version":"' + $color + '"}}}'
  $tmp = [System.IO.Path]::GetTempFileName()
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($tmp, $patch, $utf8NoBom)
  kubectl patch svc openemr -n $Namespace --type merge --patch-file $tmp
  Remove-Item -Force $tmp -ErrorAction SilentlyContinue
}

function Scale-Color([string]$color, [int]$replicas) {
  $dep = "openemr-$color"
  if (-not (Deployment-Exists $dep)) {
    throw "Deployment $dep not found in namespace $Namespace."
  }
  Write-Host "Scale $color to $replicas" -ForegroundColor Cyan
  kubectl scale deployment/$dep -n $Namespace --replicas=$replicas
  kubectl rollout status deployment/$dep -n $Namespace
}

function Scale-Other-To-Zero([string]$color) {
  $other = if ($color -eq "blue") { "green" } else { "blue" }
  $dep = "openemr-$other"
  if (Deployment-Exists $dep) {
    Write-Host "Scale $other to 0" -ForegroundColor DarkGray
    kubectl scale deployment/$dep -n $Namespace --replicas=0
  }
}

function Wait-ServiceEndpoints([int]$timeoutSeconds = 120) {
  $deadline = (Get-Date).AddSeconds($timeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $eps = kubectl get endpoints openemr -n $Namespace -o json | ConvertFrom-Json
    if ($null -ne $eps.subsets -and $eps.subsets.Count -gt 0) {
      return
    }
    Start-Sleep -Seconds 3
  }
  throw "Service openemr has no endpoints after $timeoutSeconds seconds."
}

function Wait-Url([string]$url, [int]$timeoutSeconds = 120) {
  $deadline = (Get-Date).AddSeconds($timeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    try {
      $resp = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 $url
      if ($resp.StatusCode -eq 200) {
        return
      }
    } catch {
      # ignore and retry
    }
    Start-Sleep -Seconds 3
  }
  throw "URL $url not ready after $timeoutSeconds seconds."
}

# Si le script se bloque dans le switch entre le blue et le green, vous pouvez remplacer cette partie par : $colors = @('green)
$colors = @()
if (Deployment-Exists "openemr-blue") { $colors += "blue" }
if (Deployment-Exists "openemr-green") { $colors += "green" }

$replicas = $MinReplicas..$MaxReplicas

foreach ($color in $colors) {
  foreach ($rep in $replicas) {
    Scale-Other-To-Zero $color
    Scale-Color $color $rep
    Set-ServiceColor $color
    Wait-ServiceEndpoints

    $env:K6_URL = $BaseUrl
    Wait-Url "$BaseUrl/interface/login/login.php"

    Write-Host "Run k6 smoke ($color/$rep)" -ForegroundColor Yellow
    k6 run --tag color=$color --tag pods=$rep --tag test=smoke --out $k6out tests/load/smoke-test.js

    Write-Host "Run k6 load ($color/$rep)" -ForegroundColor Yellow
    k6 run --tag color=$color --tag pods=$rep --tag test=load --out $k6out tests/load/load-test.js

    Write-Host "Run k6 stress ($color/$rep)" -ForegroundColor Yellow
    k6 run --tag color=$color --tag pods=$rep --tag test=stress --out $k6out tests/load/stress-test.js
  }
}
