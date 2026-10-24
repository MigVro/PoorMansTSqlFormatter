# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Poor Man's T-SQL Formatter: a coarse, fault-tolerant T-SQL tokenizer/parser/formatter library (.NET 2.0, netstandard1.0, and JS via Bridge.NET), plus hosts that wrap it (WinForms demo, web demo, command-line, SSMS add-in/package, VS 2013/2019 VSIX, Notepad++ and WinMerge plugins). Licensed AGPL v3; source files carry the AGPL header.

Fork of `TaoK/PoorMansTSqlFormatter` (remote `github`); `origin` is a private Gitea. Active work: combined VS 2022/2026 + SSMS 21/22 VSIX — see `VSIX-UPGRADE-PLAN.md` and `TODOs.md`.

## Build

```
msbuild PoorMansTSqlFormatter.sln /m /p:Configuration=Debug /p:Platform=PureDotNet
msbuild PoorMansTSqlFormatterLib\PoorMansTSqlFormatterLib.csproj /p:Configuration=Debug
msbuild PoorMansTSqlFormatterNetStandard.sln
```

- Solution platforms: `x86`, `x64`, `PureDotNet`. `x86`/`x64` exist for the Notepad++ plugin (UnmanagedExports); CI also passes `/p:PlatformToolset=v140_xp`.
- Setup projects (WiX, VS Installer Projects) and the WinMerge VB6 COM plugin need extra tooling and manual steps — see `BUILDING.txt`.
- `ExternalBuildTools/` (fart.exe, ILRepack), `packages/`, and `PoorMansTSqlFormatterTest/References/` are vendored binaries. `Key.snk` files sign assemblies; don't regenerate them outside the guided step in the VSIX plan.

## Tests

`PoorMansTSqlFormatterTests` is an **Exe** that launches the vendored NUnit 2.5.10 GUI runner on itself (`Program.cs`); there is no console runner in the repo. Build it, run `PoorMansTSqlFormatterTest\bin\<Config>\PoorMansTSqlFormatterTests.exe`, and select a single test or fixture in the GUI.

Tests are data-driven from `PoorMansTSqlFormatterTest/Data/`:
- `InputSql/` — source SQL; each file becomes a `TestCaseSource` case.
- `ParsedSql/` — expected XML parse tree for the same file name.
- `StandardFormatSql/` — expected standard-formatter output. Options are encoded in the file name, e.g. `05_ComplexDDL(NewClauseLineBreaks=2,NewStatementLineBreaks=3).txt`; the part in parentheses is passed to `new TSqlStandardFormatterOptions(configString)` and stripped to find the matching `InputSql` file.
- Expected-output files are the spec. Only change them deliberately, never to make a test pass.
- Markers in test files: `KNOWN SQL REFORMATTING INCONSISTENCY`, and the parser error banner `--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!` (duplicated in `Utils.cs` on purpose).
- The data folder is resolved from the **current working directory** as `..\..\Data` (`Utils.GetTestContentFolder`), so run the tests with the working directory set to `bin\<Config>`.

## Architecture

**Single source, multiple targets.** All library code lives in `PoorMansTSqlFormatterLibShared/`, which is not a project itself. `PoorMansTSqlFormatterLib` (.NET 2.0), `PoorMansTSqlFormatterLib_35`, `PoorMansTSqlFormatterNetStandardLib` (netstandard1.0) and `PoorMansTSqlFormatterJSLib` (Bridge.NET → JS) each compile `..\PoorMansTSqlFormatterLibShared\**\*.cs`. Code there must therefore stay compatible with C#/.NET 2.0 (LinqBridge provides LINQ), netstandard1.0, **and** Bridge.NET transpilation. Target-specific shims live in each project (e.g. `NetStandardLib/NetUtils.cs`).

**Pipeline** (`SqlFormattingManager` orchestrates):
1. `ISqlTokenizer` → `TSqlStandardTokenizer` → `ITokenList`
2. `ISqlTokenParser` → `TSqlStandardParser` → `Node` tree (XML-like; element names in `Interfaces/SqlStructureConstants.cs`)
3. `ISqlTreeFormatter` → `TSqlStandardFormatter` (options in `TSqlStandardFormatterOptions`, parsed from/serialized to a `Key=Value,...` string), `TSqlIdentityFormatter` (round-trip), `TSqlObfuscatingFormatter`. `HtmlPageWrapper` adds colorized HTML output.

Parsing is deliberately coarse and must not throw on unknown constructs; errors are flagged on the tree and surfaced as the warning banner.

**Host layers:**
- `PoorMansTSqlFormatterPluginShared` — WinForms settings/about dialogs, `ISqlSettings`, and es/fr localized resources shared by the editor plugins.
- `PoorMansTSqlFormatterSSMSLib` — `GenericVSHelper` (formatting the active document, hotkey setup, `isVisualStudio` only changes the default hotkey) and `Settings`; shared by the SSMS add-in, SSMS package and VS packages.
- `PoorMansTSqlFormatterSSMSPackage`, `PoorMansTSqlFormatterVSPackage2013`, `PoorMansTSqlFormatterVSPackage2019` — VSIX packages (`source.extension.vsixmanifest`, `FormatterPackage.cs`, `.vsct`).
- `PoorMansTSqlFormatterCmdLine` / `PoorMansTSqlFormatterDemo` — merged into single assemblies with ILRepack after build.

UI strings come in `.resx` triples (neutral, `.es`, `.fr`); keep keys in sync across all three.

## Versioning

`VersionBump.ps1` (run from the repo root): `.\VersionBump.ps1 [major|minor|patch|X.Y.Z]`. The source of truth is `version:` in `appveyor.yml`; the script rewrites `AssemblyInfo.cs`, `FormatterPackage.cs` (`InstalledProductRegistration`) and `source.extension.vsixmanifest` (`<Identity ... Version>`). It expects those files to be **UTF-8 with BOM and CRLF**, so preserve both when editing.

Release packaging is manual (see the end of `BUILDING.txt`). `appveyor.yml` only builds and publishes the Notepad++ plugin artifacts.
