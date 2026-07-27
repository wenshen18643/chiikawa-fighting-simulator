# Rebuild game-3 and reopen it in Roblox Studio.
# Run from PowerShell in this repo: .\reload.ps1
#
#   .\reload.ps1           build, regenerate sourcemap, restart Studio
#   .\reload.ps1 -NoOpen   build only, leave Studio alone (use in a check loop)
#   .\reload.ps1 -Check    build + analyze, never touches Studio
#   .\reload.ps1 -Serve    live-sync into an already-open Studio session
#
# -Serve is the loop to use when iterating on anything authored in Studio's
# viewport (assets/*.model.json). The default build path is ONE-WAY: it
# overwrites the .rbxl, so anything created in Studio and not exported back
# into the repo is destroyed by the next plain .\reload.ps1.

param(
    [switch]$NoOpen,
    [switch]$Check,
    [switch]$Serve
)

$ProjectRoot = $PSScriptRoot
$BuildOutput = Join-Path $ProjectRoot "Chiikawa Fighting Simulator.rbxl"
$SourcemapOutput = Join-Path $ProjectRoot "sourcemap.json"

Set-Location $ProjectRoot

if ($Check) { $NoOpen = $true }

# Prefer a Rojo binary on PATH; fall back to the bundled tools/rojo.exe.
$RojoPath = Get-Command rojo -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $RojoPath) {
    $RojoPath = Join-Path $ProjectRoot "tools\rojo.exe"
    if (-not (Test-Path $RojoPath)) {
        Write-Host "Rojo not found." -ForegroundColor Red
        Write-Host "Install Rojo from https://rojo.space or place rojo.exe in tools/rojo.exe" -ForegroundColor Yellow
        exit 1
    }
}

# Warn once rather than failing: the place still runs without Packages, on
# DataService's unlocked-DataStore fallback. See README "Setup" step 2.
if (-not (Test-Path (Join-Path $ProjectRoot "Packages"))) {
    Write-Host "WARNING: Packages/ is missing - ProfileService is not installed." -ForegroundColor Yellow
    Write-Host "         DataService will run its UNLOCKED DataStore fallback." -ForegroundColor Yellow
    Write-Host "         Run 'wally install' before any public test." -ForegroundColor Yellow
}

# Serve short-circuits everything below: no build, no place file, no Studio
# restart. Connect from the Rojo plugin in an already-open Studio session.
if ($Serve) {
    Write-Host "Regenerating sourcemap before serving..." -ForegroundColor Cyan
    & $RojoPath sourcemap default.project.json --include-non-scripts -o $SourcemapOutput

    Write-Host "Starting Rojo server. Connect via the Rojo plugin in Studio." -ForegroundColor Green
    Write-Host "Ctrl+C to stop." -ForegroundColor Yellow
    & $RojoPath serve default.project.json
    exit $LASTEXITCODE
}

Write-Host "Building project with $RojoPath..." -ForegroundColor Cyan
& $RojoPath build default.project.json -o $BuildOutput
if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed." -ForegroundColor Red
    exit 1
}

# Keeps luau-lsp / editor autocomplete honest about the DataModel shape.
# --include-non-scripts because assets/ mounts Frames and other non-script
# instances; without it luau-lsp cannot see ReplicatedStorage.Assets.* at all
# and every template reference autocompletes to nothing.
Write-Host "Regenerating sourcemap..." -ForegroundColor Cyan
& $RojoPath sourcemap default.project.json --include-non-scripts -o $SourcemapOutput
if ($LASTEXITCODE -ne 0) {
    Write-Host "Sourcemap generation failed." -ForegroundColor Red
    exit 1
}

# Same fallback as Rojo: prefer a binary on PATH, otherwise use the bundled one
# in tools/. That way the check gate runs identically whether or not the machine
# has been through `aftman install`.
function Resolve-Tool([string]$Name) {
    $OnPath = Get-Command $Name -ErrorAction SilentlyContinue
    if ($OnPath) { return $OnPath.Source }
    $Bundled = Join-Path $ProjectRoot "tools\$Name.exe"
    if (Test-Path $Bundled) { return $Bundled }
    return $null
}

$SelenePath = Resolve-Tool "selene"
if ($SelenePath) {
    Write-Host "Linting with selene..." -ForegroundColor Cyan
    & $SelenePath src
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Lint failed." -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "selene not found - skipping lint." -ForegroundColor Yellow
}

if ($Check) {
    $LspPath = Resolve-Tool "luau-lsp"
    if ($LspPath) {
        Write-Host "Type-checking with luau-lsp..." -ForegroundColor Cyan
        $Files = Get-ChildItem -Path src -Filter *.lua -Recurse | ForEach-Object { $_.FullName }

        # WITHOUT --definitions, luau-lsp knows nothing about Roblox: every
        # Instance, Enum and Color3 becomes "unknown global" and the ~2,000
        # resulting errors bury any real one. The definitions file is not
        # downloaded by the analyzer, so it is kept in tools/ alongside it.
        $Definitions = Join-Path $ProjectRoot "tools\globalTypes.d.luau"
        if (-not (Test-Path $Definitions)) {
            Write-Host "tools/globalTypes.d.luau is missing - type check would be noise." -ForegroundColor Yellow
            Write-Host "Fetch it from https://github.com/JohnnyMorganz/luau-lsp/blob/main/scripts/globalTypes.d.luau" -ForegroundColor Yellow
        }
        else {
            & $LspPath analyze --platform=roblox --definitions=$Definitions --sourcemap=sourcemap.json --no-strict-dm-types @Files
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Type check failed." -ForegroundColor Red
                exit 1
            }
        }
    }
    else {
        Write-Host "luau-lsp not found - skipping type check." -ForegroundColor Yellow
        Write-Host "Get it from https://github.com/JohnnyMorganz/luau-lsp/releases" -ForegroundColor Yellow
    }
}

if ($NoOpen) {
    Write-Host "Done (Studio untouched)." -ForegroundColor Green
    exit 0
}

Write-Host "Closing Roblox Studio..." -ForegroundColor Cyan
Stop-Process -Name "RobloxStudioBeta" -Force -ErrorAction SilentlyContinue

Start-Sleep -Seconds 2

Write-Host "Opening $BuildOutput in Roblox Studio..." -ForegroundColor Cyan
Start-Process $BuildOutput

Write-Host "Done." -ForegroundColor Green
