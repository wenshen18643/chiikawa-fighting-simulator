# Rebuild game-3 and reopen it in Roblox Studio.
# Run from PowerShell in this repo: .\reload.ps1
#
#   .\reload.ps1           strip comments, build, sourcemap, lint, type-check,
#                          restart Studio. This is the only command you need.
#   .\reload.ps1 -NoOpen   same, but leave Studio alone (use in a check loop)
#   .\reload.ps1 -Check    same, and FAIL on type errors, never touches Studio
#   .\reload.ps1 -Fresh    ignore the incremental cache, redo every stage
#   .\reload.ps1 -Serve    live-sync into an already-open Studio session
#
# Cost model. Every stage is either skipped, incremental, or overlapped:
#   - .reload\stamp.txt records size+mtime of src/, assets/ and the project
#     files. Nothing changed -> no build at all, just reopen the place.
#   - comments.ps1 only lexes the files whose stamp moved, not all 137.
#   - the sourcemap is only regenerated when a file is added or removed;
#     editing a file cannot change the DataModel tree.
#   - build, selene and luau-lsp run concurrently. luau-lsp costs ~4s before
#     it reads a single source file (that is globalTypes.d.luau), so it is
#     started first and its result is cached in .reload\typecheck.txt.
#   - Studio is killed at the top, in parallel with the build, instead of
#     being killed at the end and then slept on.
#
# Comments are stripped, not reported: CLAUDE.md bans them and selene has no
# lint for them. The type check only blocks under -Check, because src carries
# pre-existing type errors a plain reload should not stop on.
#
# -Serve is the loop to use when iterating on anything authored in Studio's
# viewport (assets/*.model.json). The default build path is ONE-WAY: it
# overwrites the .rbxl, so anything created in Studio and not exported back
# into the repo is destroyed by the next plain .\reload.ps1.

param(
    [switch]$NoOpen,
    [switch]$Check,
    [switch]$Serve,
    [switch]$Fresh
)

$ProjectRoot = $PSScriptRoot
$BuildOutput = Join-Path $ProjectRoot "Chiikawa Fighting Simulator.rbxl"
$SourcemapOutput = Join-Path $ProjectRoot "sourcemap.json"
$CacheDir = Join-Path $ProjectRoot ".reload"
$StampFile = Join-Path $CacheDir "stamp.txt"
$TypeCacheFile = Join-Path $CacheDir "typecheck.txt"

Set-Location $ProjectRoot

$Clock = [System.Diagnostics.Stopwatch]::StartNew()

function Write-Stage([string]$Message, [string]$Colour = "Cyan") {
    Write-Host ("[{0,5:0.00}s] {1}" -f $Clock.Elapsed.TotalSeconds, $Message) -ForegroundColor $Colour
}

if ($Check) { $NoOpen = $true }
if (-not (Test-Path $CacheDir)) { [void](New-Item -ItemType Directory -Path $CacheDir) }

function Resolve-Tool([string]$Name) {
    $OnPath = Get-Command $Name -ErrorAction SilentlyContinue
    if ($OnPath) { return $OnPath.Source }
    $Bundled = Join-Path $ProjectRoot "tools\$Name.exe"
    if (Test-Path $Bundled) { return $Bundled }
    return $null
}

$RojoPath = Resolve-Tool "rojo"
if (-not $RojoPath) {
    Write-Host "Rojo not found." -ForegroundColor Red
    Write-Host "Install Rojo from https://rojo.space or place rojo.exe in tools/rojo.exe" -ForegroundColor Yellow
    exit 1
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

# ---------------------------------------------------------------- stamps

# .NET enumeration, not Get-ChildItem: FileInfo already carries size and mtime,
# so the whole tree costs one directory walk and no per-file stat.
function Get-Stamps {
    $map = @{}
    foreach ($name in @("src", "assets", "tools")) {
        $dir = Join-Path $ProjectRoot $name
        if (-not (Test-Path $dir)) { continue }
        foreach ($file in [System.IO.DirectoryInfo]::new($dir).EnumerateFiles("*", "AllDirectories")) {
            if ($file.Extension -eq ".exe") { continue }
            $map[$file.FullName] = "$($file.LastWriteTimeUtc.Ticks):$($file.Length)"
        }
    }
    foreach ($file in [System.IO.DirectoryInfo]::new($ProjectRoot).EnumerateFiles("*.project.json")) {
        $map[$file.FullName] = "$($file.LastWriteTimeUtc.Ticks):$($file.Length)"
    }
    $self = [System.IO.FileInfo]::new($PSCommandPath)
    $map[$self.FullName] = "$($self.LastWriteTimeUtc.Ticks):$($self.Length)"
    return $map
}

function Read-Stamps {
    $map = @{}
    if (-not (Test-Path $StampFile)) { return $map }
    foreach ($line in [System.IO.File]::ReadAllLines($StampFile)) {
        $split = $line.LastIndexOf('|')
        if ($split -gt 0) { $map[$line.Substring(0, $split)] = $line.Substring($split + 1) }
    }
    return $map
}

function Write-Stamps($Map) {
    $lines = foreach ($key in $Map.Keys) { "$key|$($Map[$key])" }
    [System.IO.File]::WriteAllLines($StampFile, [string[]]$lines)
}

$Stamps = Get-Stamps
$Previous = if ($Fresh) { @{} } else { Read-Stamps }

$Dirty = New-Object System.Collections.Generic.List[string]
foreach ($key in $Stamps.Keys) {
    if ($Previous[$key] -ne $Stamps[$key]) { [void]$Dirty.Add($key) }
}

# Adding or removing a file changes the DataModel tree; editing one does not.
$PathSetMoved = $Previous.Count -eq 0
if (-not $PathSetMoved) {
    foreach ($key in $Stamps.Keys) { if (-not $Previous.ContainsKey($key)) { $PathSetMoved = $true; break } }
}
if (-not $PathSetMoved) {
    foreach ($key in $Previous.Keys) { if (-not $Stamps.ContainsKey($key)) { $PathSetMoved = $true; break } }
}
if (-not (Test-Path $SourcemapOutput)) { $PathSetMoved = $true }

# Only src/ is comment-stripped: tools\globalTypes.d.luau is vendored input.
$SrcDir = (Join-Path $ProjectRoot "src") + [System.IO.Path]::DirectorySeparatorChar
$DirtyLua = @($Dirty | Where-Object { $_ -match '\.luau?$' -and $_.StartsWith($SrcDir, "OrdinalIgnoreCase") })
$DirtyTooling = @($Dirty | Where-Object { -not $_.StartsWith($SrcDir, "OrdinalIgnoreCase") }).Count -gt 0

function Show-CachedTypeCheck {
    if (-not (Test-Path $TypeCacheFile)) { return }
    $cached = @([System.IO.File]::ReadAllLines($TypeCacheFile) | Where-Object { $_ -ne "" })
    if ($cached.Count -eq 0) {
        Write-Host "Type check clean (cached)." -ForegroundColor Green
        return
    }
    Write-Host "Type check: $($cached.Count) issue(s) (cached, not blocking)." -ForegroundColor Yellow
    $cached | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
}

function Stop-Studio {
    if ($NoOpen) { return }
    foreach ($proc in @(Get-Process -Name "RobloxStudioBeta" -ErrorAction SilentlyContinue)) {
        try { $proc.Kill(); [void]$proc.WaitForExit(10000) } catch {}
    }
}

function Open-Studio {
    if ($NoOpen) { return }
    Write-Stage "Opening $BuildOutput in Roblox Studio..."
    Start-Process $BuildOutput
}

# Nothing changed: the .rbxl on disk is already the build this source produces.
# -Check never takes this path - a gate that answers from cache is not a gate.
if ($Dirty.Count -eq 0 -and -not $Check -and (Test-Path $BuildOutput)) {
    Write-Stage "No source changes - reusing the existing build." "Green"
    Show-CachedTypeCheck
    Stop-Studio
    Open-Studio
    Write-Host "Done." -ForegroundColor Green
    exit 0
}

# Killed here, not after the build: Studio holds a lock on the .rbxl, so it
# has to be gone before rojo writes, and the kill overlaps the strip instead
# of being followed by a fixed two-second sleep.
Stop-Studio

# ------------------------------------------------------- comment stripping

# Runs BEFORE the build, or the place would be built from unstripped source.
# selene has no lint for comments (its rules are all semantic), so the
# no-comments rule from CLAUDE.md is enforced here. It strips rather than
# fails: reload is the only command you should have to run.
if ($DirtyLua.Count -gt 0) {
    Write-Stage "Stripping comments ($($DirtyLua.Count) changed file(s))..."
    & (Join-Path $ProjectRoot "tools\comments.ps1") -Fix -Files $DirtyLua
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Comment strip failed." -ForegroundColor Red
        exit 1
    }
    foreach ($path in $DirtyLua) {
        if (Test-Path -LiteralPath $path) {
            $info = [System.IO.FileInfo]::new($path)
            $Stamps[$info.FullName] = "$($info.LastWriteTimeUtc.Ticks):$($info.Length)"
        }
    }
}

# ------------------------------------------------------------- parallel run

# Raw Process, not Start-Process: a -PassThru process started without -Wait
# reports a null ExitCode in Windows PowerShell 5.1, which reads as failure.
# The streams are drained asynchronously or a chatty tool deadlocks on a full
# pipe buffer while we are still waiting for it to exit.
function Start-Tool([string]$Exe, [string[]]$ToolArgs) {
    $quoted = $ToolArgs | ForEach-Object { if ($_ -match '[\s"]') { '"' + $_ + '"' } else { $_ } }

    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $Exe
    $info.Arguments = ($quoted -join ' ')
    $info.WorkingDirectory = $ProjectRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true

    $proc = [System.Diagnostics.Process]::Start($info)
    return [pscustomobject]@{
        Proc = $proc
        Out  = $proc.StandardOutput.ReadToEndAsync()
        Err  = $proc.StandardError.ReadToEndAsync()
    }
}

function Wait-Tool($Job) {
    $Job.Proc.WaitForExit()
    $text = $Job.Out.Result + "`n" + $Job.Err.Result
    $lines = @($text -split "`r?`n" | Where-Object { $_ -ne "" })
    return [pscustomobject]@{ Code = $Job.Proc.ExitCode; Lines = $lines }
}

Write-Stage "Building, linting and type-checking..."

$SourcemapJob = $null
if ($PathSetMoved) {
    # --include-non-scripts because assets/ mounts Frames and other non-script
    # instances; without it luau-lsp cannot see ReplicatedStorage.Assets.* at
    # all and every template reference autocompletes to nothing.
    $SourcemapJob = Start-Tool $RojoPath @(
        "sourcemap", "default.project.json", "--include-non-scripts", "-o", $SourcemapOutput
    )
}

$BuildJob = Start-Tool $RojoPath @("build", "default.project.json", "-o", $BuildOutput)

$SelenePath = Resolve-Tool "selene"
$SeleneJob = if ($SelenePath) { Start-Tool $SelenePath @("src") } else { $null }

# luau-lsp is the long pole (~4s of fixed cost before it looks at src at all),
# so it is started as early as the sourcemap allows and waited on last.
$LspPath = Resolve-Tool "luau-lsp"
$Definitions = Join-Path $ProjectRoot "tools\globalTypes.d.luau"
$LspJob = $null
$LspSkipped = $DirtyLua.Count -eq 0 -and -not $DirtyTooling -and -not $Check -and (Test-Path $TypeCacheFile)

if ($LspPath -and -not (Test-Path $Definitions)) {
    Write-Host "tools/globalTypes.d.luau is missing - type check would be noise." -ForegroundColor Yellow
    Write-Host "Fetch it from https://github.com/JohnnyMorganz/luau-lsp/blob/main/scripts/globalTypes.d.luau" -ForegroundColor Yellow
}
elseif (-not $LspPath) {
    Write-Host "luau-lsp not found - skipping type check." -ForegroundColor Yellow
    Write-Host "Get it from https://github.com/JohnnyMorganz/luau-lsp/releases" -ForegroundColor Yellow
}
elseif (-not $LspSkipped) {
    if ($SourcemapJob) { $SourcemapJob.Proc.WaitForExit() }
    $LspJob = Start-Tool $LspPath @(
        "analyze", "--platform=roblox", "--definitions=$Definitions",
        "--sourcemap=$SourcemapOutput", "--no-strict-dm-types", "src"
    )
}

if ($SourcemapJob) {
    $sourcemap = Wait-Tool $SourcemapJob
    if ($sourcemap.Code -ne 0) {
        Write-Host "Sourcemap generation failed." -ForegroundColor Red
        $sourcemap.Lines | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
}

$build = Wait-Tool $BuildJob
if ($build.Code -ne 0) {
    Write-Host "Build failed." -ForegroundColor Red
    $build.Lines | ForEach-Object { Write-Host "  $_" }
    exit 1
}
Write-Stage "Build done." "Green"

if ($SeleneJob) {
    $selene = Wait-Tool $SeleneJob
    if ($selene.Code -ne 0) {
        Write-Host "Lint failed." -ForegroundColor Red
        $selene.Lines | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
    Write-Stage "Lint clean." "Green"
}
else {
    Write-Host "selene not found - skipping lint." -ForegroundColor Yellow
}

# The place is good from here on, so Studio starts loading while the type
# check - which never blocks a plain reload - is still running.
if (-not $Check) { Open-Studio }

# ------------------------------------------------------------- type check

$TypeFailed = $false
if ($LspSkipped) {
    Show-CachedTypeCheck
}
elseif ($LspJob) {
    $analysis = Wait-Tool $LspJob
    # An error is re-reported once per file that requires the offending module,
    # so the raw output is mostly duplicates. Trim the absolute path and the
    # [game/...] mirror of it to keep one line per issue.
    $Unique = @($analysis.Lines |
        Where-Object { $_ -match 'TypeError|SyntaxError' } |
        ForEach-Object { ($_ -replace [regex]::Escape($ProjectRoot + "\"), "") -replace ' \[game/[^\]]*\]', '' } |
        Select-Object -Unique)

    [System.IO.File]::WriteAllLines($TypeCacheFile, [string[]]$Unique)
    $TypeFailed = $Unique.Count -gt 0

    if ($TypeFailed) {
        $Note = if ($Check) { "" } else { " (not blocking)" }
        Write-Stage "Type check: $($Unique.Count) issue(s)$Note." "Yellow"
        $Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
    }
    else {
        Write-Stage "Type check clean." "Green"
    }
}

Write-Stamps $Stamps

if ($TypeFailed -and $Check) {
    Write-Host "Type check failed." -ForegroundColor Red
    exit 1
}

if ($Check -or $NoOpen) {
    Write-Stage "Done (Studio untouched)." "Green"
    exit 0
}

Write-Stage "Done." "Green"
