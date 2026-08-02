param(
    [string]$Path = "src",
    [switch]$Fix
)

$ErrorActionPreference = "Stop"

# Comment spans are found with a real Luau lexer pass, not a regex: "a--b" and
# [[ a -- b ]] are strings, and --[==[ ]==] blocks span lines. Backticks are
# interpolated strings whose {...} holes may themselves span lines.
# Directives (--!strict, -- selene: allow, -- stylua: ignore) are tool input and
# are never stripped.
function Get-CommentMask([string]$Text) {
    $n = $Text.Length
    $mask = New-Object 'bool[]' $n
    $i = 0

    while ($i -lt $n) {
        $c = $Text[$i]

        if ($c -eq '`') {
            $i++
            $depth = 0
            while ($i -lt $n) {
                $d = $Text[$i]
                if ($d -eq '\') { $i += 2; continue }
                if ($d -eq '{') { $depth++ }
                elseif ($d -eq '}') { if ($depth -gt 0) { $depth-- } }
                elseif ($d -eq '`' -and $depth -eq 0) { $i++; break }
                elseif ($d -eq "`n" -and $depth -eq 0) { break }
                $i++
            }
            continue
        }

        if ($c -eq '"' -or $c -eq "'") {
            $quote = $c
            $i++
            while ($i -lt $n) {
                if ($Text[$i] -eq '\') { $i += 2; continue }
                if ($Text[$i] -eq "`n") { break }
                if ($Text[$i] -eq $quote) { $i++; break }
                $i++
            }
            continue
        }

        if ($c -eq '[') {
            $j = $i + 1
            while ($j -lt $n -and $Text[$j] -eq '=') { $j++ }
            if ($j -lt $n -and $Text[$j] -eq '[') {
                $level = $j - $i - 1
                $close = "]" + ("=" * $level) + "]"
                $end = $Text.IndexOf($close, $j + 1)
                $i = if ($end -lt 0) { $n } else { $end + $close.Length }
                continue
            }
        }

        if ($c -eq '-' -and $i + 1 -lt $n -and $Text[$i + 1] -eq '-') {
            $start = $i
            $j = $i + 2

            $isLong = $false
            if ($j -lt $n -and $Text[$j] -eq '[') {
                $k = $j + 1
                while ($k -lt $n -and $Text[$k] -eq '=') { $k++ }
                if ($k -lt $n -and $Text[$k] -eq '[') {
                    $isLong = $true
                    $level = $k - $j - 1
                    $close = "]" + ("=" * $level) + "]"
                    $end = $Text.IndexOf($close, $k + 1)
                    $i = if ($end -lt 0) { $n } else { $end + $close.Length }
                }
            }

            if (-not $isLong) {
                $end = $Text.IndexOfAny([char[]]@("`r", "`n"), $j)
                $i = if ($end -lt 0) { $n } else { $end }

                $body = $Text.Substring($j, $i - $j)
                if ($body.StartsWith("!") -or $body -match '^\s*(selene|stylua)\s*:') { continue }
            }

            for ($m = $start; $m -lt $i; $m++) { $mask[$m] = $true }
            continue
        }

        $i++
    }

    return $mask
}

function Remove-Comments([string]$Text, [bool[]]$Mask) {
    $newline = if ($Text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = New-Object System.Collections.Generic.List[string]
    $line = New-Object System.Text.StringBuilder
    $kept = New-Object System.Text.StringBuilder
    $stripped = $false

    $commit = {
        # A line whose only content was a comment disappears completely, so the
        # code below it moves up instead of leaving a hole.
        if (-not ($stripped -and $kept.ToString().Trim() -eq "")) {
            $lines.Add($line.ToString().TrimEnd())
        }
        [void]$line.Clear(); [void]$kept.Clear()
    }

    for ($i = 0; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]

        if ($c -eq "`n") {
            & $commit
            $stripped = $false
            continue
        }
        if ($c -eq "`r") { continue }

        if ($Mask[$i]) {
            $stripped = $true
            # An inline block comment can be the only separator between two
            # tokens (a--[[x]]b), so it collapses to a space, not to nothing.
            $atEnd = ($i + 1 -ge $Text.Length) -or (-not $Mask[$i + 1])
            $prev = if ($line.Length -gt 0) { $line[$line.Length - 1] } else { ' ' }
            $next = if ($i + 1 -lt $Text.Length) { $Text[$i + 1] } else { ' ' }
            if ($atEnd -and $prev -ne ' ' -and $next -ne ' ' -and $next -ne "`n" -and $next -ne "`r") {
                [void]$line.Append(' ')
            }
            continue
        }

        [void]$line.Append($c)
        [void]$kept.Append($c)
    }
    if ($line.Length -gt 0 -or $stripped) { & $commit }

    # Whitespace left behind by the removed lines: no blank lines at the top of
    # a file, never two blank lines in a row, exactly one trailing newline.
    $out = New-Object System.Collections.Generic.List[string]
    for ($k = 0; $k -lt $lines.Count; $k++) {
        $l = $lines[$k]
        if ($l.Trim() -ne "") { $out.Add($l); continue }

        if ($out.Count -eq 0) { continue }
        if ($out[$out.Count - 1].Trim() -eq "") { continue }

        # A comment that opened or closed a block leaves the blank line behind;
        # a block should not start or end with one.
        $prev = $out[$out.Count - 1].Trim()
        if ($prev -match '(\{|\(|\bthen|\bdo|\belse|\brepeat)$') { continue }

        $nextIdx = $k
        while ($nextIdx -lt $lines.Count -and $lines[$nextIdx].Trim() -eq "") { $nextIdx++ }
        if ($nextIdx -lt $lines.Count) {
            $next = $lines[$nextIdx].Trim()
            if ($next -match '^(end|else|elseif|until|\}|\))') { continue }
        }

        $out.Add($l)
    }
    while ($out.Count -gt 0 -and $out[$out.Count - 1].Trim() -eq "") { $out.RemoveAt($out.Count - 1) }

    return ($out -join $newline) + $newline
}

$root = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location) $Path }
$files = Get-ChildItem -Path $root -Recurse -Include *.lua, *.luau -File

$offenders = @()
$changed = 0

foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    $mask = Get-CommentMask $text
    $hasComment = $mask -contains $true

    if ($Fix) {
        $new = Remove-Comments $text $mask
        if ($new -ne $text) {
            [System.IO.File]::WriteAllText($file.FullName, $new)
            $changed++
        }
        continue
    }

    if (-not $hasComment) { continue }

    $rel = $file.FullName.Substring((Get-Location).Path.Length).TrimStart('\', '/')
    $lineNo = 1
    $reported = @{}
    for ($i = 0; $i -lt $text.Length; $i++) {
        if ($text[$i] -eq "`n") { $lineNo++; continue }
        if ($mask[$i] -and -not $reported.ContainsKey($lineNo)) {
            $reported[$lineNo] = $true
            $offenders += "$rel`:$lineNo"
        }
    }
}

if ($Fix) {
    Write-Host "Cleaned $changed file(s)." -ForegroundColor Green
    exit 0
}

if ($offenders.Count -gt 0) {
    Write-Host "Comments are not allowed in src/ (see CLAUDE.md)." -ForegroundColor Red
    $offenders | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" }
    if ($offenders.Count -gt 40) { Write-Host "  ... and $($offenders.Count - 40) more" }
    Write-Host "Run: .\tools\comments.ps1 -Fix" -ForegroundColor Yellow
    exit 1
}

exit 0
