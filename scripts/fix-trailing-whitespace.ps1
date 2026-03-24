param(
	[switch]$Staged = $true,
	[switch]$Unstaged,
	[switch]$Restage
)

function Get-WhitespaceOffenders {
	param([bool]$CheckStaged, [bool]$CheckUnstaged)

	$reports = @()
	if ($CheckStaged) {
		$reports += (& git diff --cached --check 2>$null)
	}
	if ($CheckUnstaged) {
		$reports += (& git diff --check 2>$null)
	}

	$files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	foreach ($line in $reports) {
		if ($line -match "^(.*?):\d+:\s") {
			$null = $files.Add($Matches[1])
		}
	}

	return @($files)
}

function Remove-TrailingWhitespace {
	param([string]$Path)

	if (-not (Test-Path -LiteralPath $Path)) {
		return $false
	}

	$reader = $null
	$writer = $null
	try {
		$reader = [System.IO.StreamReader]::new($Path, $true)
		$content = $reader.ReadToEnd()
		$encoding = $reader.CurrentEncoding
		$reader.Close()
		$reader.Dispose()

		$fixed = [System.Text.RegularExpressions.Regex]::Replace($content, "[ \t]+(?=\r?$)", "", [System.Text.RegularExpressions.RegexOptions]::Multiline)
		if ($fixed -ceq $content) {
			return $false
		}

		$writer = [System.IO.StreamWriter]::new($Path, $false, $encoding)
		$writer.Write($fixed)
		$writer.Close()
		$writer.Dispose()
		return $true
	} catch {
		Write-Host "[fix-trailing-whitespace] Skip '$Path': $($_.Exception.Message)" -ForegroundColor Yellow
		return $false
	} finally {
		if ($reader) { $reader.Dispose() }
		if ($writer) { $writer.Dispose() }
	}
}

$check_staged = $true
$check_unstaged = $false

if ($Unstaged) {
	$check_unstaged = $true
}

if (-not $Staged -and $Unstaged) {
	$check_staged = $false
}

$offenders = Get-WhitespaceOffenders -CheckStaged $check_staged -CheckUnstaged $check_unstaged

if ($offenders.Count -eq 0) {
	Write-Host "[fix-trailing-whitespace] No trailing whitespace issues found."
	exit 0
}

Write-Host "[fix-trailing-whitespace] Found $($offenders.Count) file(s) with trailing whitespace:"
foreach ($file in $offenders) {
	Write-Host " - $file"
}

$changed = @()
foreach ($file in $offenders) {
	if (Remove-TrailingWhitespace -Path $file) {
		$changed += $file
	}
}

if ($changed.Count -eq 0) {
	Write-Host "[fix-trailing-whitespace] No file content changed."
	exit 0
}

Write-Host "[fix-trailing-whitespace] Fixed $($changed.Count) file(s)."

if ($Restage) {
	& git add -- $changed
	if ($LASTEXITCODE -ne 0) {
		Write-Host "[fix-trailing-whitespace] Failed to restage changed files." -ForegroundColor Red
		exit 1
	}
	Write-Host "[fix-trailing-whitespace] Restaged changed files."
}

$remaining = Get-WhitespaceOffenders -CheckStaged $check_staged -CheckUnstaged $check_unstaged
if ($remaining.Count -gt 0) {
	Write-Host "[fix-trailing-whitespace] Remaining issues in:"
	foreach ($file in $remaining) {
		Write-Host " - $file"
	}
	exit 1
}

Write-Host "[fix-trailing-whitespace] All trailing whitespace issues resolved."
exit 0
