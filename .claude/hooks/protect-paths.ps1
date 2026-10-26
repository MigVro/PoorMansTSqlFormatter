$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$path = ($payload.tool_input.file_path -replace '\\', '/')
if (-not $path) { exit 0 }

$denied = @('/packages/', '/ExternalBuildTools/', '/PoorMansTSqlFormatterTest/References/', '.snk')
$ask = @('/PoorMansTSqlFormatterTest/Data/ParsedSql/', '/PoorMansTSqlFormatterTest/Data/StandardFormatSql/')

function Write-Decision($decision, $reason) {
    @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = $decision; permissionDecisionReason = $reason } } | ConvertTo-Json -Compress
    exit 0
}

foreach ($p in $denied) {
    if ($path.Contains($p)) { Write-Decision 'deny' "Vendored/signing file ($p) - not editable per CLAUDE.md." }
}
foreach ($p in $ask) {
    if ($path.Contains($p)) { Write-Decision 'ask' 'Expected-output files are the spec; change only deliberately, never to make a test pass.' }
}
