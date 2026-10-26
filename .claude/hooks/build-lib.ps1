$payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
$path = ($payload.tool_input.file_path -replace '\\', '/')
if ($path -notmatch '/PoorMansTSqlFormatterLibShared/.*\.cs$') { exit 0 }

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$msbuild = & $vswhere -latest -requires Microsoft.Component.MSBuild -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
if (-not $msbuild) { [Console]::Error.WriteLine('build-lib hook: MSBuild not found via vswhere.'); exit 1 }

$project = Join-Path $env:CLAUDE_PROJECT_DIR 'PoorMansTSqlFormatterLib\PoorMansTSqlFormatterLib.csproj'
$output = & $msbuild $project /restore /nologo /v:q /clp:ErrorsOnly /p:Configuration=Debug
if ($LASTEXITCODE -eq 0) { exit 0 }

[Console]::Error.WriteLine(($output -join "`n"))
exit 2
