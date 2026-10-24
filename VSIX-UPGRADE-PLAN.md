# Combined VSIX upgrade plan (VS 2022/2026 + SSMS 21/22)

Status: approved, not started. Revised 2026-10-24 after the codebase scan.

## Goal

One 64-bit VSIX, `PoorMansTSqlFormatterVSPackage`, targeting Visual Studio 2022/2026 and SSMS 21/22.

## Findings that shape the plan

- SSMS 22 is built on the VS 2026 shell and is 64-bit (x64 and Arm64). Source: https://learn.microsoft.com/ssms/faq
- Third-party SSMS extensions are not supported but not blocked (same FAQ).
- SSMS 21/22 install a normal VSIX via VSIXInstaller, per user, under `%LocalAppData%\Microsoft\SSMS\<version_id>\Extensions`.
  Reference: https://github.com/nicholas-ross/SSMS-Schema-Folders (InstallationTarget `Microsoft.VisualStudio.Ssms` `[21.0,23.0)` amd64).
- `FormatterPackage.vsct` is identical in the VS2019 and SSMS projects (Tools menu).
- `GenericVSHelper`'s `isVisualStudio` flag only affects the default hotkey; with null delegates VS and SSMS take the same path.
  So the VS2019 `AsyncPackage` code runs as-is in SSMS.
- In-process VS and SSMS extensions run on .NET Framework, so the VSIX stays on .NET Framework 4.7.2 (see step 1).
- Build tooling: `msbuild` is not on PATH on the dev machine, and the `dotnet` SDK (10.0.402) builds only the SDK-style `PoorMansTSqlFormatterNetStandardLib`. Old-style csproj and VSSDK targets need Visual Studio's MSBuild.
- `appveyor.yml` uses the VS 2017 image, publishes only the Notepad++ artifacts, and its GitHub deploy token is still a `!!TODO!!` placeholder.
- `VersionBump.ps1` finds files by name pattern (`AssemblyInfo.cs`, `FormatterPackage.cs`, `source.extension.vsixmanifest`), so the new project is picked up without script changes.
- The formatter tests only run in the NUnit 2.5.10 GUI. They cover the library, not the hosts, so the VSIX needs manual testing (step 6).

## Decisions

1. Identity: new GUIDs (manifest Identity, package, command set) and a new `Key.snk`. Done as a guided step (see step 0).
2. New project folder `PoorMansTSqlFormatterVSPackage`, based on `PoorMansTSqlFormatterVSPackage2019`.
3. Obsolete projects are removed from the solution and their folders deleted.
4. Arm64: deferred, tracked in `TODOs.md`.

## Prerequisites

- Visual Studio 2022 or 2026 with the **Visual Studio extension development** workload. Build from a Developer PowerShell for VS, so `msbuild` and `sn` are on PATH.
- The .NET Framework 3.5 Windows feature, for the .NET 2.0/3.5 library projects. Unverified: whether VS 2026 still builds v2.0 targets; check this first.
- SSMS 21 and 22 installed for testing.

## Steps

### 0. Identity (guided, done together)

- Generate three GUIDs (manifest Identity Id, package GUID, command set GUID): `[guid]::NewGuid()` in PowerShell.
- Generate a new strong-name key: `sn -k Key.snk` from a Developer PowerShell for VS.
- Decide the `Publisher` and `DisplayName` values for the manifest.
- Places to update:
  - `source.extension.vsixmanifest`: `Identity Id`, `Publisher`, `DisplayName`, `Description`.
  - `FormatterPackage.cs`: `guidPoorMansTSqlFormatterSSMSPackagePkgString`, `guidPoorMansTSqlFormatterSSMSPackageCmdSetString`.
  - `FormatterPackage.vsct`: the matching `GuidSymbol` values in `<Symbols>`.

### 1. Project

- Copy `PoorMansTSqlFormatterVSPackage2019` to `PoorMansTSqlFormatterVSPackage` (new ProjectGuid, RootNamespace, AssemblyName).
- Keep the old-style csproj, since VSSDK still expects it.
- Replace `packages.config`, the `Shell.14.0`/`Shell.Immutable.*`/`Threading 14.0` references and the `Sdk.BuildTasks.14.0` imports with PackageReferences:
  - `Microsoft.VisualStudio.SDK` 17.0.x, with `ExcludeAssets="runtime"`, to compile against the lowest API both hosts have.
  - `Microsoft.VSSDK.BuildTools` 17.x.
  - Pick exact versions from NuGet at implementation time.
- `TargetFrameworkVersion`: v4.6 → v4.7.2.
- Leave `PoorMansTSqlFormatterLib`, `PluginShared` and `SSMSLib` on .NET 2.0. They already load into CLR 4, and other plugins (Notepad++ and others) share them.

### 2. Manifest

```xml
<Installation>
  <InstallationTarget Id="Microsoft.VisualStudio.Community" Version="[17.0,19.0)">
    <ProductArchitecture>amd64</ProductArchitecture>
  </InstallationTarget>
  <InstallationTarget Id="Microsoft.VisualStudio.Ssms" Version="[21.0,23.0)">
    <ProductArchitecture>amd64</ProductArchitecture>
  </InstallationTarget>
</Installation>
<Prerequisites>
  <Prerequisite Id="Microsoft.VisualStudio.Component.CoreEditor" Version="[17.0,)" />
</Prerequisites>
```

`Community` also covers Pro and Enterprise. The current manifest uses `Pro`, which leaves out Community.

### 3. Code (`FormatterPackage.cs`)

- Add `ThreadHelper.ThrowIfNotOnUIThread()` to the two command callbacks and to `QueryFormatButtonStatus`, which use DTE. The 17.x analyzers (VSTHRD010) flag them otherwise.
- Update version strings and the `InstalledProductRegistration` text.
- Existing bug, not approved yet: `QueryFormatButtonStatus` dereferences `queryingCommand` in the `else` branch even when it's null. Ask before fixing.

### 4. Solution cleanup

Remove from `PoorMansTSqlFormatter.sln` and delete these folders:

- `PoorMansTSqlFormatterVSPackage2013`
- `PoorMansTSqlFormatterVSPackage2019` (after the new project works)
- `PoorMansTSqlFormatterSSMSPackage`
- `PoorMansTSqlFormatterSSMSAddIn`
- `PoorMansTSqlFormatterSSMSPackage.Setup.action`
- `PoorMansTSqlFormatterSSMSAddIn.Setup.action`

Unverified: whether `PoorMansTSqlFormatterWebDemo` (ASP.NET Web Forms) still builds in VS 2026.

Afterwards, update the host-layer list in `CLAUDE.md` and the packaging steps in `BUILDING.txt`.

### 5. CI (needs a decision)

`appveyor.yml` can't build the new VSIX as it stands. Options:
- Switch to the VS 2022 image and add the `.vsix` as an artifact. The deploy token must be filled in before releases can be published.
- Leave CI on Notepad++ only and package the VSIX by hand, as now.

### 6. Testing

- **VS 2026:** F5 into the experimental instance, `/rootsuffix Exp`.
- **VS 2022:** install the VSIX.
- **SSMS 21/22:** SSMS has no experimental instance. Install with VSIXInstaller, then attach the debugger to `Ssms.exe`.
- In each host, check the Tools-menu commands (Format, Options), the enable/disable state with no active document, and that settings persist.

## Phase 2: .NET modernisation (after the VSIX ships)

Status: approved in principle, not planned in detail.

In-process VS/SSMS extensions and the Notepad++ plugin must stay on .NET Framework, so only part of the solution moves to .NET 10.

| Project | Target |
|---|---|
| `PoorMansTSqlFormatterLib`, `_35`, `NetStandardLib` | One SDK-style project, `netstandard2.0`; drop LinqBridge |
| `PoorMansTSqlFormatterCmdLine` | `net10.0`; single-file publish replaces ILRepack |
| `PoorMansTSqlFormatterDemo` | `net10.0-windows` (WinForms); single-file publish replaces ILRepack |
| `PoorMansTSqlFormatterTests` | `net10.0`, NUnit 4, `dotnet test` (headless) |
| `PluginShared`, `SSMSLib`, `NppPlugin`, VSIX | .NET Framework 4.8 (SDK-style where VSSDK and UnmanagedExports allow) |

Decisions needed before starting:
- **Breaking change:** dropping the .NET 2.0/3.5 library targets affects any consumer of the published package that still uses them.
- **JSLib (Bridge.NET, abandoned):** keep it frozen, which means the shared source must still compile under Bridge.NET, or drop it.
- **WebDemo (Web Forms):** drop it or rewrite it on ASP.NET Core.

Known work:
- Tests: `Utils.GetTestContentFolder` resolves `..\..\Data` from the working directory, and that breaks with the `bin\<Config>\net10.0` output folder. The expected-output files must stay byte-identical.
- `VersionBump.ps1`: SDK-style projects carry the version in the csproj, or in `Directory.Build.props`, rather than `AssemblyInfo.cs`, so the script needs updating.
- `appveyor.yml` and `BUILDING.txt`: switch to `dotnet build`/`dotnet test` where possible.
- Unverified: whether VSSDK supports SDK-style csproj for VSIX projects in 17.x; check when planning this phase.
