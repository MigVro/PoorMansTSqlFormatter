#Requires -Version 7
# Renders draft expected outputs for a test input using the current formatter.
# Output is a snapshot of current behaviour, not a verified expectation.
param(
    [Parameter(Mandatory)][string]$InputFile,
    [Parameter(Mandatory)][string]$OutDir,
    [string[]]$Configs = @(),
    [switch]$NoParsed
)
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path "$PSScriptRoot\..\..\..").Path
$libDir = Join-Path $OutDir '_lib'
$dll = Join-Path $libDir 'PoorMansTSqlFormatterLib.dll'
dotnet build "$repoRoot\PoorMansTSqlFormatterLib\PoorMansTSqlFormatterLib.csproj" -c Debug -o $libDir -v q -nologo | Out-String -OutVariable buildLog | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Library build failed:`n$buildLog" }
Add-Type -Path $dll

# Mirrors PoorMansTSqlFormatterLib\NetUtils.ToXmlDoc, which the netstandard build does not include.
function ConvertTo-XmlNode([System.Xml.XmlDocument]$doc, $node) {
    $el = $doc.CreateNode([System.Xml.XmlNodeType]::Element, $node.Name, $null)
    foreach ($a in $node.Attributes.GetEnumerator()) {
        $attr = $doc.CreateAttribute($null, $a.Key, $null)
        $attr.Value = $a.Value
        [void]$el.Attributes.Append($attr)
    }
    $el.InnerText = if ($null -ne $node.TextValue) { $node.TextValue } else { '' }
    foreach ($child in $node.Children) { [void]$el.AppendChild((ConvertTo-XmlNode $doc $child)) }
    $el
}

$utf8Bom = [System.Text.UTF8Encoding]::new($true)
$name = [IO.Path]::GetFileNameWithoutExtension($InputFile)
$sql = [IO.File]::ReadAllText((Resolve-Path $InputFile))

$tokens = [PoorMansTSqlFormatterLib.Tokenizers.TSqlStandardTokenizer]::new().TokenizeSQL($sql)
$tree = [PoorMansTSqlFormatterLib.Parsers.TSqlStandardParser]::new().ParseSQL($tokens)

New-Item -ItemType Directory -Force "$OutDir\ParsedSql", "$OutDir\StandardFormatSql" | Out-Null

if (-not $NoParsed) {
    $doc = [System.Xml.XmlDocument]::new()
    [void]$doc.AppendChild((ConvertTo-XmlNode $doc $tree))
    [IO.File]::WriteAllText("$OutDir\ParsedSql\$name.txt", $doc.OuterXml, $utf8Bom)
}

foreach ($config in @('') + $Configs) {
    $options = [PoorMansTSqlFormatterLib.Formatters.TSqlStandardFormatterOptions]::new($config)
    $formatted = [PoorMansTSqlFormatterLib.Formatters.TSqlStandardFormatter]::new($options).FormatSQLTree($tree)
    $suffix = if ($config) { "($config)" } else { '' }
    [IO.File]::WriteAllText("$OutDir\StandardFormatSql\$name$suffix.txt", $formatted, $utf8Bom)
}

Get-ChildItem "$OutDir\ParsedSql", "$OutDir\StandardFormatSql" -File | ForEach-Object FullName
