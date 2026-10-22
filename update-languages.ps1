$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$inv = [Globalization.CultureInfo]::InvariantCulture

$colors = @{
    "C#" = "#178600"; "TypeScript" = "#3178C6"; "C" = "#A8B9CC"; "HTML" = "#E34C26"; "JavaScript" = "#F1E05A"
    "Python" = "#3572A5"; "Svelte" = "#FF3E00"; "PowerShell" = "#5391FE"; "PLpgSQL" = "#336790"; "SQL" = "#336790"
    "CSS" = "#563D7C"; "C++" = "#F34B7D"; "Java" = "#B07219"; "Lua" = "#000080"
}
$ignored = @("CMake", "Inno Setup", "Batchfile", "Shell", "Makefile", "Dockerfile")

$repos = @(gh repo list panseeker --limit 200 --json nameWithOwner,isFork | ConvertFrom-Json) | ForEach-Object { $_ } | Where-Object { -not $_.isFork }
$totals = @{}
foreach ($r in $repos) {
    $langs = gh api "repos/$($r.nameWithOwner)/languages" | ConvertFrom-Json
    foreach ($p in $langs.PSObject.Properties) {
        if ($ignored -contains $p.Name) { continue }
        $name = if ($p.Name -eq "PLpgSQL") { "SQL" } else { $p.Name }
        $totals[$name] = [long]$totals[$name] + [long]$p.Value
    }
}
$sum = [double]($totals.Values | Measure-Object -Sum).Sum
$sorted = $totals.GetEnumerator() | Sort-Object Value -Descending
$top = @($sorted | Select-Object -First 9 | ForEach-Object { [pscustomobject]@{ Name = $_.Key; Pct = 100 * $_.Value / $sum; Color = $(if ($colors[$_.Key]) { $colors[$_.Key] } else { "#8B949E" }) } })
$rest = 100 - ($top | Measure-Object Pct -Sum).Sum
if ($rest -ge 0.05) { $top += [pscustomobject]@{ Name = "Other"; Pct = $rest; Color = "#8B949E" } }

$width = 495; $barX = 25; $barW = $width - 50
$rows = [Math]::Ceiling($top.Count / 2)
$height = 92 + $rows * 26
$segments = ""; $x = [double]$barX
foreach ($l in $top) {
    $w = $barW * $l.Pct / 100
    $segments += "<rect x=`"$($x.ToString('0.##', $inv))`" y=`"58`" width=`"$([Math]::Max($w, 0).ToString('0.##', $inv))`" height=`"10`" fill=`"$($l.Color)`"/>"
    $x += $w
}
$legend = ""
for ($i = 0; $i -lt $top.Count; $i++) {
    $l = $top[$i]
    $cx = if ($i % 2 -eq 0) { 30 } else { 260 }
    $cy = 98 + [Math]::Floor($i / 2) * 26
    $legend += "<circle cx=`"$cx`" cy=`"$($cy - 4)`" r=`"5`" fill=`"$($l.Color)`"/><text x=`"$($cx + 12)`" y=`"$cy`" class=`"lang`">$([Security.SecurityElement]::Escape($l.Name))</text><text x=`"$($cx + 205)`" y=`"$cy`" class=`"pct`" text-anchor=`"end`">$($l.Pct.ToString('0.0', $inv)) %</text>"
}

$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" viewBox="0 0 $width $height" role="img" aria-label="Most used languages">
<style>
.title { font: 600 18px 'Segoe UI', Ubuntu, sans-serif; fill: #70A5FD; }
.sub { font: 400 12px 'Segoe UI', Ubuntu, sans-serif; fill: #6B7394; }
.lang { font: 400 13px 'Segoe UI', Ubuntu, sans-serif; fill: #A9B1D6; }
.pct { font: 600 13px 'Segoe UI', Ubuntu, sans-serif; fill: #C0CAF5; }
</style>
<rect x="0.5" y="0.5" rx="10" width="$($width - 1)" height="$($height - 1)" fill="#1A1B27"/>
<text x="25" y="34" class="title">Most used languages</text>
<text x="$($width - 25)" y="34" class="sub" text-anchor="end">all repositories, incl. private</text>
<clipPath id="bar"><rect x="$barX" y="58" width="$barW" height="10" rx="5"/></clipPath>
<g clip-path="url(#bar)">$segments</g>
$legend
</svg>
"@
[IO.File]::WriteAllText((Join-Path $PSScriptRoot "languages.svg"), $svg, (New-Object Text.UTF8Encoding($false)))
"languages.svg: " + (($top | ForEach-Object { "$($_.Name) $($_.Pct.ToString('0.0', $inv))%" }) -join ", ")
