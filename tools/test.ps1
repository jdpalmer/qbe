# Native Windows test runner (amd64_win only). See tools/test.sh for the
# full cross-target harness.
param(
	[Parameter(Position = 0, Mandatory = $true)]
	[string]$What
)

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Bin = if ($env:bin) { $env:bin } else { Join-Path $Root 'qbe.exe' }
$Cc = if ($env:CC) { $env:CC } else { 'clang' }
$Target = 'amd64_win'
$Tmp = Join-Path $env:TEMP 'qbe.zzzz'
$Asm = "$Tmp.s"
$Drv = "$Tmp.c"
$Exe = "$Tmp.exe"
$Out = "$Tmp.out"
$Utf8 = New-Object System.Text.UTF8Encoding $false

# Writes extracted lines to $Dest; returns line count.
function Write-Section([string]$Name, [string]$File, [string]$Dest) {
	$buf = New-Object System.Collections.Generic.List[string]
	$on = $false
	foreach ($line in Get-Content -LiteralPath $File) {
		if ($line -match "^# >>> $Name\b") { $on = $true; continue }
		if ($on -and $line -match '^# <<<') { break }
		if ($on) {
			if ($line.StartsWith('# ')) { [void]$buf.Add($line.Substring(2)) }
			elseif ($line -eq '#') { [void]$buf.Add('') }
			else { [void]$buf.Add($line) }
		}
	}
	[System.IO.File]::WriteAllLines($Dest, $buf.ToArray(), $Utf8)
	return $buf.Count
}

function Invoke-Once([string]$Test) {
	if (-not (Test-Path -LiteralPath $Test)) {
		Write-Host "invalid test file $Test"
		return 1
	}

	$first = Get-Content -LiteralPath $Test -TotalCount 1
	if ($first -match "skip.*\b$Target\b") {
		return 0
	}

	$name = Split-Path $Test -Leaf
	Write-Host ("{0,-45}" -f "$name...") -NoNewline

	& $Bin -t $Target -o $Asm $Test
	if ($LASTEXITCODE -ne 0) {
		Write-Host '[qbe fail]'
		return 1
	}

	$ndrv = Write-Section 'driver' $Test $Drv
	$nout = Write-Section 'output' $Test $Out

	if ($ndrv -gt 0) {
		& $Cc -g -o $Exe $Drv $Asm
	} else {
		& $Cc -g -o $Exe $Asm
	}
	if ($LASTEXITCODE -ne 0) {
		Write-Host '[cc fail]'
		return 1
	}

	$got = & $Exe a b c 2>&1 | ForEach-Object { "$_" -replace "`r", '' }
	$ret = $LASTEXITCODE
	if ($null -eq $got) { $got = @() } else { $got = @($got) }

	if ($nout -gt 0) {
		$exp = @(Get-Content -LiteralPath $Out | ForEach-Object { $_ -replace "`r", '' })
		$ok = ($got.Count -eq $exp.Count)
		if ($ok) {
			for ($i = 0; $i -lt $exp.Count; $i++) {
				if ($got[$i] -ne $exp[$i]) { $ok = $false; break }
			}
		}
		if (-not $ok) {
			Write-Host '[output fail]'
			return 1
		}
	} elseif ($ret -ne 0) {
		Write-Host "[returned $ret fail]"
		return 1
	}

	Write-Host '[ok]'
	return 0
}

if (-not (Test-Path -LiteralPath $Bin)) {
	Write-Host "qbe not found: $Bin"
	exit 1
}

if ($What -eq 'all') {
	$fail = 0
	$count = 0
	$tests = Get-ChildItem (Join-Path $Root 'test\*.ssa') |
		Where-Object { $_.Name -notlike '_*' } |
		Sort-Object Name
	foreach ($t in $tests) {
		$fail += Invoke-Once $t.FullName
		$count++
	}
	Write-Host ''
	if ($fail -ge 1) {
		Write-Host "$fail of $count tests failed!"
	} else {
		Write-Host 'All is fine!'
	}
	exit $fail
}

exit (Invoke-Once $What)
