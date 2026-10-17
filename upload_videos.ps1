# upload_videos.ps1 -- upload every mp4 in this repo as a Roblox VIDEO asset via the
# Open Cloud Assets API, then write the returned ids into AssetIds.lua.
#
# costs 2,000 robux per video. requires a 13+ id-verified account and an API key
# with the "Add assets" permission (see create.roblox.com/docs/cloud/auth/api-keys).
#
# safe to re-run: slots that already have an id in AssetIds.lua are skipped, so an
# interrupted batch never double-spends. moderation takes hours, re-run it later.
#
# usage:
#   .\upload_videos.ps1 -ApiKey <key> -Username <roblox name>
#   .\upload_videos.ps1 -ApiKey <key> -UserId <numeric id>
#   .\upload_videos.ps1 -ApiKey <key> -Username <name> -Limit 1      # prove it on one clip
#   .\upload_videos.ps1 -ApiKey <key> -Username <name> -WhatIf       # list, upload nothing
#   .\upload_videos.ps1 -ApiKey <key> -Username <name> -Force        # skip the spend prompt
#   .\upload_videos.ps1 -ApiKey <key> -Username <name> -Reupload     # ignore existing ids

param(
    [Parameter(Mandatory = $true)][string]$ApiKey,
    [string]$UserId = "",
    [string]$Username = "",
    [string]$RepoDir = "",
    [int]$Limit = 0,
    [switch]$WhatIf,
    [switch]$Force,
    [switch]$Reupload
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# System.Net.Http is not loaded by default on Windows PowerShell 5.1
try {
    Add-Type -AssemblyName System.Net.Http -ErrorAction Stop
} catch {
    Write-Warning "could not load System.Net.Http: $($_.Exception.Message)"
}

# $PSScriptRoot is empty when this default is evaluated under `powershell -File`,
# so resolve the repo folder here instead.
if (-not $RepoDir) { $RepoDir = $PSScriptRoot }
if (-not $RepoDir) { $RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $RepoDir) { $RepoDir = (Get-Location).Path }

$createUrl = "https://apis.roblox.com/assets/v1/assets"
$opUrl = "https://apis.roblox.com/assets/v1/operations/"
$costPer = 2000

# read ids back out of AssetIds.lua, keeping commented slots as $null placeholders
# so a previously failed upload does not shift every later id out of slot.
function Get-ExistingIds {
    param([string]$Path)
    $out = @()
    if (-not (Test-Path $Path)) { return $out }
    $inside = $false
    foreach ($line in (Get-Content $Path)) {
        if ($line -match 'return\s*\{') { $inside = $true; continue }
        if (-not $inside) { continue }
        if ($line -match '^\s*\}') { break }
        if ($line -match '^\s*--') { $out += $null; continue }
        if ($line -match '^\s*(\d+)\s*,') { $out += $matches[1]; continue }
        $out += $null
    }
    return $out
}

if (-not $UserId) {
    if (-not $Username) {
        throw "pass either -UserId <number> or -Username <roblox name>"
    }
    Write-Host "[upload] resolving user id for '$Username' ..."
    $lookup = Invoke-RestMethod -Method Post -Uri "https://users.roblox.com/v1/usernames/users" `
        -ContentType "application/json" `
        -Body (@{ usernames = @($Username); excludeBannedUsers = $false } | ConvertTo-Json -Compress)
    if (-not $lookup.data -or @($lookup.data).Count -eq 0) {
        throw "no roblox user named '$Username'"
    }
    $UserId = [string]@($lookup.data)[0].id
    Write-Host "[upload] $Username = user id $UserId"
}

$files = @(Get-ChildItem -Path $RepoDir -Filter *.mp4 | Sort-Object Name)
if ($files.Count -eq 0) { throw "no .mp4 files found in $RepoDir" }

$existing = @(Get-ExistingIds -Path (Join-Path $RepoDir "AssetIds.lua"))
Write-Host ("[upload] {0} clip(s), {1} id(s) already in AssetIds.lua" -f $files.Count, @($existing | Where-Object { $_ }).Count)

# build the work list in slot order (slot = position in FILES order in Gui.lua)
$work = @()
for ($i = 0; $i -lt $files.Count; $i++) {
    $have = ""
    if (-not $Reupload -and $i -lt $existing.Count -and $existing[$i]) { $have = [string]$existing[$i] }
    $work += [pscustomobject]@{ Slot = ($i + 1); File = $files[$i]; Existing = $have }
}
if ($Limit -gt 0) { $work = @($work | Where-Object { $_.Slot -le $Limit }) }

$todo = @($work | Where-Object { -not $_.Existing })
$skipped = @($work | Where-Object { $_.Existing })
$total = $todo.Count * $costPer

Write-Host ("[upload] to upload: {0} clip(s), estimated cost {1:N0} robux" -f $todo.Count, $total)
if ($skipped.Count -gt 0) {
    foreach ($s in $skipped) { Write-Host ("  already done, slot {0} = {1} -> {2}" -f $s.Slot, $s.Existing, $s.File.Name) }
}

if ($WhatIf) {
    foreach ($t in $todo) { Write-Host ("  would upload slot {0}: {1} ({2:N1} MB)" -f $t.Slot, $t.File.Name, ($t.File.Length / 1MB)) }
    return
}

if ($todo.Count -eq 0) { Write-Host "[upload] nothing to do"; return }

if (-not $Force) {
    $answer = Read-Host ("about to spend {0:N0} robux on {1} upload(s). type 'yes' to continue" -f $total, $todo.Count)
    if ($answer -ne "yes") { Write-Host "[upload] aborted"; return }
}

function New-MultipartRequest {
    param([string]$Json, [string]$FilePath, [string]$ContentType)
    $client = New-Object System.Net.Http.HttpClient
    $client.Timeout = [TimeSpan]::FromMinutes(30)
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $jsonContent = New-Object System.Net.Http.StringContent($Json, [Text.Encoding]::UTF8, "application/json")
    $content.Add($jsonContent, "request")
    $stream = [IO.File]::OpenRead($FilePath)
    $fileContent = New-Object System.Net.Http.StreamContent($stream)
    $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse($ContentType)
    $content.Add($fileContent, "fileContent", [IO.Path]::GetFileName($FilePath))
    return @{ Client = $client; Content = $content; Stream = $stream }
}

# slot -> id, seeded with everything already paid for
$slotIds = New-Object object[] $files.Count
for ($i = 0; $i -lt $files.Count; $i++) {
    if ($i -lt $existing.Count -and $existing[$i]) { $slotIds[$i] = $existing[$i] }
}

$done = 0
$uploadedOk = 0
foreach ($t in $todo) {
    $done++
    $slot = $t.Slot
    $f = $t.File
    $display = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $request = @{
        assetType       = "Video"
        displayName     = $display
        description     = "tt clip $slot"
        creationContext = @{ creator = @{ userId = [string]$UserId } }
    } | ConvertTo-Json -Compress -Depth 5

    Write-Host ("[upload] {0}/{1} slot {2} {3} ({4:N1} MB) ..." -f $done, $todo.Count, $slot, $f.Name, ($f.Length / 1MB))

    $mp = $null
    try {
        $mp = New-MultipartRequest -Json $request -FilePath $f.FullName -ContentType "video/mp4"
        $mp.Client.DefaultRequestHeaders.Add("x-api-key", $ApiKey)
        $resp = $mp.Client.PostAsync($createUrl, $mp.Content).GetAwaiter().GetResult()
        $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        if (-not $resp.IsSuccessStatusCode) {
            $code = [int]$resp.StatusCode
            Write-Warning ("  rejected ({0}): {1}" -f $code, $body)
            if ($code -eq 401 -or $code -eq 403) {
                Write-Warning "  the api key is not allowed to create assets, stopping -- every clip would fail the same way"
                Write-Warning "  fix: creator dashboard -> this api key -> add the Assets system with write (Add assets) permission"
                Write-Warning "  also check the key's IP allowlist is empty or includes your current ip"
                break
            }
            continue
        }
        $op = ($body | ConvertFrom-Json).path
        $opId = ($op -split "/")[-1]
        Write-Host ("  operation {0}, waiting on moderation ..." -f $opId)

        $assetId = $null
        for ($try = 0; $try -lt 120; $try++) {
            Start-Sleep -Seconds 5
            $hc = New-Object System.Net.Http.HttpClient
            try {
                $hc.DefaultRequestHeaders.Add("x-api-key", $ApiKey)
                $opBody = $hc.GetStringAsync($opUrl + $opId).GetAwaiter().GetResult()
            } finally { $hc.Dispose() }
            $decoded = $opBody | ConvertFrom-Json
            if ($decoded.done) {
                if ($decoded.response.assetId) {
                    $assetId = [string]$decoded.response.assetId
                    $state = $null
                    if ($decoded.response.moderationResult) { $state = $decoded.response.moderationResult.moderationState }
                    Write-Host ("  asset id {0} ({1})" -f $assetId, $state)
                } else {
                    Write-Warning ("  failed: {0}" -f $opBody)
                }
                break
            }
        }
        if (-not $assetId) { Write-Warning "  no asset id returned yet (still processing)" }
        if ($assetId) { $uploadedOk++ }
        $slotIds[$slot - 1] = $assetId
    } catch {
        Write-Warning ("  error: {0}" -f $_.Exception.Message)
    } finally {
        if ($mp) { $mp.Content.Dispose(); $mp.Client.Dispose(); $mp.Stream.Dispose() }
    }
}

$lines = @(
    "-- language: Luau, file: AssetIds.lua, target: Roblox",
    "-- generated by upload_videos.ps1 -- one video asset id per clip, slot order matches FILES in Gui.lua",
    "return {"
)
for ($i = 0; $i -lt $slotIds.Count; $i++) {
    if ($slotIds[$i]) {
        $lines += ("    {0}," -f $slotIds[$i])
    } else {
        $lines += ("    -- {0}, -- upload failed or skipped" -f ($i + 1))
    }
}
$lines += "}"
$target = Join-Path $RepoDir "AssetIds.lua"
$lines | Set-Content -Path $target -Encoding ASCII
Write-Host ("[upload] wrote {0}" -f $target)

$filled = @($slotIds | Where-Object { $_ }).Count
Write-Host ("[upload] done: {0}/{1} slots have ids ({2:N0} robux spent this run)" -f $filled, $slotIds.Count, ($uploadedOk * $costPer))

if ($filled -lt $slotIds.Count) {
    Write-Host "[upload] some slots are still empty -- re-run this script after moderation finishes"
}

Write-Host "[upload] next:"
Write-Host "  git -C `"$RepoDir`" add AssetIds.lua"
Write-Host "  git -C `"$RepoDir`" commit -m `"Add uploaded video asset ids`""
Write-Host "  git -C `"$RepoDir`" push origin main"
