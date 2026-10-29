# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Poor Man's T-SQL Formatter: a coarse, fault-tolerant T-SQL tokenizer/parser/formatter library (netstandard2.0, and JS via Bridge.NET), plus hosts that wrap it (WinForms demo, web demo, command-line, a combined VS 2022/2026 + SSMS 22 VSIX, Notepad++ and WinMerge plugins). Licensed AGPL v3; source files carry the AGPL header.

Fork of `TaoK/PoorMansTSqlFormatter`; `origin` is the GitHub fork `MigVro/PoorMansTSqlFormatter`, `gitea` is a private Gitea mirror. Open work is in `TODOs.md`.

## Build

`msbuild` is not on PATH; use Visual Studio's MSBuild. `/restore` is required (SDK-style library, `PackageReference` in SSMSLib and the VSIX).

```
msbuild PoorMansTSqlFormatter.sln /restore /m /p:Configuration=Debug /p:Platform=PureDotNet
msbuild PoorMansTSqlFormatterLib\PoorMansTSqlFormatterLib.csproj /restore /p:Configuration=Debug
```

- Building `PoorMansTSqlFormatterVSPackage` also deploys it to the VS 2026 experimental instance (`devenv /rootsuffix Exp`); don't additionally install it there with VSIXInstaller.

- Solution platforms: `x86`, `x64`, `PureDotNet`. `x86`/`x64` exist for the Notepad++ plugin (UnmanagedExports).
- The WinMerge setup project (VS Installer Projects) and the WinMerge VB6 COM plugin need extra tooling and manual steps — see `BUILDING.txt`.
- `ExternalBuildTools/` (fart.exe, ILRepack), and `packages/` are vendored binaries. `Key.snk` files sign assemblies; don't regenerate them outside the guided step in the VSIX plan.

## Tests

`PoorMansTSqlFormatterTests` is a NUnit 3 library (`PackageReference` to `NUnit` and `NUnit.ConsoleRunner`). Build it with `/restore`, then from `PoorMansTSqlFormatterTest\bin\<Config>` run `%USERPROFILE%\.nuget\packages\nunit.consolerunner\3.17.0\tools\nunit3-console.exe PoorMansTSqlFormatterTests.dll`; filter with `--where "test =~ Parser"`.

Tests are data-driven from `PoorMansTSqlFormatterTest/Data/`:
- `InputSql/` — source SQL; each file becomes a `TestCaseSource` case.
- `ParsedSql/` — expected XML parse tree for the same file name.
- `StandardFormatSql/` — expected standard-formatter output. Options are encoded in the file name, e.g. `05_ComplexDDL(NewClauseLineBreaks=2,NewStatementLineBreaks=3).txt`; the part in parentheses is passed to `new TSqlStandardFormatterOptions(configString)` and stripped to find the matching `InputSql` file.
- Expected-output files are the spec. Only change them deliberately, never to make a test pass.
- Markers in test files: `KNOWN SQL REFORMATTING INCONSISTENCY`, and the parser error banner `--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!` (duplicated in `Utils.cs` on purpose).
- The data folder is resolved from the **current working directory** as `..\..\Data` (`Utils.GetTestContentFolder`), so run the tests with the working directory set to `bin\<Config>`.

## Architecture

**Single source, multiple targets.** All library code lives in `PoorMansTSqlFormatterLibShared/`, which is not a project itself. `PoorMansTSqlFormatterLib` (SDK-style, netstandard2.0) and `PoorMansTSqlFormatterJSLib` (Bridge.NET → JS) each compile `..\PoorMansTSqlFormatterLibShared\**\*.cs`. Code there must therefore stay compatible with netstandard2.0 **and** Bridge.NET transpilation. Target-specific shims live in each project (e.g. `PoorMansTSqlFormatterLib/NetUtils.cs`). All other projects target .NET Framework 4.7.2.

**Pipeline** (`SqlFormattingManager` orchestrates):
1. `ISqlTokenizer` → `TSqlStandardTokenizer` → `ITokenList`
2. `ISqlTokenParser` → `TSqlStandardParser` → `Node` tree (XML-like; element names in `Interfaces/SqlStructureConstants.cs`)
3. `ISqlTreeFormatter` → `TSqlStandardFormatter` (options in `TSqlStandardFormatterOptions`, parsed from/serialized to a `Key=Value,...` string), `TSqlIdentityFormatter` (round-trip), `TSqlObfuscatingFormatter`. `HtmlPageWrapper` adds colorized HTML output.

Parsing is deliberately coarse and must not throw on unknown constructs; errors are flagged on the tree and surfaced as the warning banner.

**Host layers:**
- `PoorMansTSqlFormatterPluginShared` — WinForms settings/about dialogs, `ISqlSettings`, and es/fr localized resources shared by the editor plugins.
- `PoorMansTSqlFormatterSSMSLib` — `GenericVSHelper` (formatting the active document, hotkey setup, `isVisualStudio` only changes the default hotkey) and `Settings`; used by the VSIX.
- `PoorMansTSqlFormatterVSPackage` — one amd64 VSIX (`AsyncPackage`) for VS 2022/2026 and SSMS 22 (`source.extension.vsixmanifest`, `FormatterPackage.cs`, `.vsct`). Output: `bin\<Config>\PoorMansTSqlFormatterVSPackage.vsix`.
- `PoorMansTSqlFormatterCmdLine` / `PoorMansTSqlFormatterDemo` — merged into single assemblies with ILRepack after build.

UI strings come in `.resx` triples (neutral, `.es`, `.fr`); keep keys in sync across all three.

## Versioning

`VersionBump.ps1` (run from the repo root): `.\VersionBump.ps1 [major|minor|patch|X.Y.Z]`. The source of truth is `<Identity ... Version>` in `PoorMansTSqlFormatterVSPackage\source.extension.vsixmanifest`; the script rewrites `AssemblyInfo.cs`, `FormatterPackage.cs` (`InstalledProductRegistration`) and `source.extension.vsixmanifest` (`<Identity ... Version>`). It expects those files to be **UTF-8 with BOM and CRLF**, so preserve both when editing.

Release packaging is manual (see the end of `BUILDING.txt`). GitHub Actions (`.github/workflows/vsix.yml`) builds the VSIX and attaches it to the GitHub release when a version tag (e.g. `1.6.17`) is pushed.
