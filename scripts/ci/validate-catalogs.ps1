$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$CatalogDir = Join-Path $Root "catalog"
$Failed = $false

function Fail($Message) {
    Write-Host "FAILED: $Message" -ForegroundColor Red
    $script:Failed = $true
}

Write-Host "Validating JSON catalogs..." -ForegroundColor Cyan

$JsonFiles = Get-ChildItem $CatalogDir -Filter *.json
foreach ($File in $JsonFiles) {
    try {
        $null = Get-Content $File.FullName -Raw | ConvertFrom-Json
        Write-Host "JSON OK: $($File.Name)" -ForegroundColor Green
    } catch {
        Fail "$($File.Name): $($_.Exception.Message)"
    }
}

$pages = Get-Content (Join-Path $CatalogDir "pages.catalog.json") -Raw | ConvertFrom-Json
$tweaks = Get-Content (Join-Path $CatalogDir "tweaks.catalog.json") -Raw | ConvertFrom-Json

$pageIds = @{}
foreach ($p in $pages.items) {
    if ([string]::IsNullOrWhiteSpace($p.id)) { Fail "Page with empty id" }
    if ($pageIds.ContainsKey($p.id)) { Fail "Duplicate page id: $($p.id)" }
    $pageIds[$p.id] = $true
}

$actionIds = @{}
foreach ($a in $tweaks.items) {
    foreach ($field in @("id","pageId","name","risk","action","commandPreview")) {
        if ([string]::IsNullOrWhiteSpace([string]$a.$field)) { Fail "Action $($a.id) missing $field" }
    }
    if (-not $pageIds.ContainsKey($a.pageId)) { Fail "Action $($a.id) references missing pageId $($a.pageId)" }
    if ($a.risk -notin @("SAFE","MEDIUM","DANGER","SECURITY")) { Fail "Action $($a.id) has invalid risk $($a.risk)" }
    if ($actionIds.ContainsKey($a.id)) { Fail "Duplicate action id: $($a.id)" }
    $actionIds[$a.id] = $true
}

$scriptPath = Join-Path $Root "scripts\run-action.ps1"
$scriptText = Get-Content $scriptPath -Raw
foreach ($a in $tweaks.items) {
    if ($scriptText -notmatch [regex]::Escape('"' + $a.action + '"')) {
        Fail "Action implementation not found in run-action.ps1: $($a.action)"
    }
}

if ($Failed) { exit 1 }
Write-Host "Catalog validation OK." -ForegroundColor Green
