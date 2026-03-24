param(
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$GitArgs
)

$blocked_flags = @("--no-verify", "-n")

if (-not $GitArgs -or $GitArgs.Count -eq 0) {
	& git
	exit $LASTEXITCODE
}

foreach ($arg in $GitArgs) {
	if ($blocked_flags -contains $arg) {
		Write-Host "[git-wrapper] Forbidden flag detected: $arg" -ForegroundColor Red
		Write-Host "[git-wrapper] '--no-verify' is blocked. Fix hook failures and commit normally." -ForegroundColor Yellow
		exit 2
	}
}

$output = & git @GitArgs 2>&1
$exit_code = $LASTEXITCODE

foreach ($line in $output) {
	Write-Host $line.ToString()
}

if ($exit_code -ne 0 -and $GitArgs[0] -eq "commit") {
	$joined_output = [string]::Join("`n", ($output | ForEach-Object { $_.ToString() }))
	if ($joined_output -match "(?i)trailing whitespace|whitespace error") {
		Write-Host ""
		Write-Host "[git-wrapper] Commit was blocked by trailing whitespace checks." -ForegroundColor Yellow
		Write-Host "[git-wrapper] Run: ./scripts/fix-trailing-whitespace.ps1" -ForegroundColor Cyan
		Write-Host "[git-wrapper] Then review changes, stage files, and commit again." -ForegroundColor Yellow
	}
}

exit $exit_code
