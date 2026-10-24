# Combined VSIX upgrade plan (VS 2022/2026 + SSMS 22)

Status: approved, not started. Revised 2026-10-24: the netstandard2.0 library from Phase 2 is pulled forward so nothing needs .NET Framework 3.5.

## Goal

One 64-bit VSIX, `PoorMansTSqlFormatterVSPackage`, targeting Visual Studio 2022/2026 and SSMS 22. SSMS 21 is out of scope (not installed, so it can't be tested).
The solution must build without the .NET Framework 3.5 Windows feature.

## Findings that shape the plan

- SSMS 22 is built on the VS 2026 shell and is 64-bit (x64 and Arm64). Source: https://learn.microsoft.com/ssms/faq
- Third-party SSMS extensions are not supported but not blocked (same FAQ).
- SSMS 21/22 install a normal VSIX via VSIXInstaller, per user, under `%LocalAppData%\Microsoft\SSMS\<version_id>\Extensions`.
  Reference: https://github.com/nicholas-ross/SSMS-Schema-Folders (InstallationTarget `Microsoft.VisualStudio.Ssms` `[21.0,23.0)` amd64).
- `FormatterPackage.vsct` is identical in the VS2019 and SSMS projects (Tools menu).
- `GenericVSHelper`'s `isVisualStudio` flag only affects the default hotkey; with null delegates VS and SSMS take the same path.
  So the VS2019 `AsyncPackage` code runs as-is in SSMS.
- In-process VS and SSMS extensions run on .NET Framework, so the VSIX stays on .NET Framework 4.7.2 (see step 2).
- Every host project (Demo, CmdLine, NppPlugin, Tests, WebDemo, PluginShared, SSMSLib, the old SSMS add-in) and `PoorMansTSqlFormatterLib` target v2.0, and building v2.0 needs the .NET 3.5 feature. Moving the library alone isn't enough; every v2.0 project must move too.
- No `.nuspec` in the repo, so the library isn't published as a NuGet package from here. Dropping v2.0/3.5 affects only users of the DLL downloads.
- `PoorMansTSqlFormatterLib/NetUtils.cs` (`ToXmlDoc`, `char.ToLowerInvariant`/`ToUpperInvariant` extensions) is still needed on netstandard2.0.
- `SIMPLIFIEDFW` strips the COM attributes from `SqlFormattingManager` (used by the WinMerge VB6 plugin) and replaces the invariant string conversions. The netstandard2.0 build must not define it.
- Build tooling: `msbuild` is not on PATH on the dev machine, and the `dotnet` SDK (10.0.402) builds only the SDK-style `PoorMansTSqlFormatterNetStandardLib`. Old-style csproj and VSSDK targets need Visual Studio's MSBuild.
- `appveyor.yml` uses the VS 2017 image, publishes only the Notepad++ artifacts, and its GitHub deploy token is still a `!!TODO!!` placeholder.
- `VersionBump.ps1` finds files by name pattern (`AssemblyInfo.cs`, `FormatterPackage.cs`, `source.extension.vsixmanifest`), so the new project is picked up without script changes.
- The formatter tests only run in the NUnit 2.5.10 GUI. They cover the library, not the hosts, so the VSIX needs manual testing (step 6).

## Decisions

1. Identity: new GUIDs (manifest Identity, package, command set) and a new `Key.snk`. Done as a guided step (see step 0).
2. New project folder `PoorMansTSqlFormatterVSPackage`, based on `PoorMansTSqlFormatterVSPackage2019`.
3. Obsolete projects are removed from the solution and their folders deleted.
4. Arm64: deferred, tracked in `TODOs.md`.
5. No .NET 3.5: `PoorMansTSqlFormatterLib` becomes one SDK-style netstandard2.0 project (converted in place, same assembly name). `Lib_35`, `PoorMansTSqlFormatterNetStandardLib` and `PoorMansTSqlFormatterNetStandard.sln` are deleted.
6. All other v2.0 projects move to v4.7.2 with minimal changes (old-style csproj and ILRepack stay). Their move to net10 stays in Phase 2.

## Prerequisites

Checked on the dev machine on 2026-10-24:

- [x] VS 2022 Community 17.14 and VS 2026 Community 18.11. MSBuild: `C:\dev\vs\2026\Community\MSBuild\Current\Bin\MSBuild.exe`.
- [x] `sn.exe` (Windows SDK, NETFX 4.8 Tools).
- [x] **Visual Studio extension development** workload: installed in VS 2022 and VS 2026 (`VSSDK` folder present).
- [x] SSMS 22.11 (`C:\dev\ssms\22\Release`).
- SSMS 21: not installed; the SSMS range is narrowed to `[22.0,23.0)`.
- .NET Framework 3.5 is not needed (decision 5).

## Steps

### 0. Identity (guided, done together)

- Generate three GUIDs (manifest Identity Id, package GUID, command set GUID): `[guid]::NewGuid()` in PowerShell.
- Generate a new strong-name key: `sn -k Key.snk` from a Developer PowerShell for VS.
- Decide the `Publisher` and `DisplayName` values for the manifest.
- Places to update:
  - `source.extension.vsixmanifest`: `Identity Id`, `Publisher`, `DisplayName`, `Description`.
  - `FormatterPackage.cs`: `guidPoorMansTSqlFormatterSSMSPackagePkgString`, `guidPoorMansTSqlFormatterSSMSPackageCmdSetString`.
  - `FormatterPackage.vsct`: the matching `GuidSymbol` values in `<Symbols>`.

### 1. Library to netstandard2.0, hosts to v4.7.2

Library (`PoorMansTSqlFormatterLib.csproj`, converted in place):
- SDK-style, `<TargetFramework>netstandard2.0</TargetFramework>`, `AssemblyName` `PoorMansTSqlFormatterLib`.
- Compile `..\PoorMansTSqlFormatterLibShared\**\*.cs` and `NetUtils.cs`. Don't define `SIMPLIFIEDFW`.
- `GenerateAssemblyInfo=false` and keep `Properties\AssemblyInfo.cs`, so `VersionBump.ps1` still works.
- Drop the LinqBridge reference. Delete `References\LinqBridge` once nothing else uses it.
- Keep the existing signing settings, if any.
- Delete `PoorMansTSqlFormatterLib_35.csproj`, `PoorMansTSqlFormatterNetStandardLib/` and `PoorMansTSqlFormatterNetStandard.sln`, and remove `Lib_35` from `PoorMansTSqlFormatter.sln`.

Hosts (`PluginShared`, `SSMSLib`, `Demo`, `CmdLine`, `NppPlugin`, `Tests`, `WebDemo`):
- `TargetFrameworkVersion` v2.0 → v4.7.2. Drop the LinqBridge references (PluginShared, Tests).
- The solution's `x86`/`x64` platforms map the library to Any CPU.

`PoorMansTSqlFormatterJSLib` (Bridge.NET) compiles the shared source on its own and isn't touched.

Verify:
- The solution builds for all three platforms without the .NET 3.5 feature.
- The NUnit tests pass with identical expected-output files.

Unverified, check during this step:
- ILRepack (vendored version) merging a netstandard2.0 assembly into the net472 Demo/CmdLine exes.
- COM registration of the netstandard2.0 `SqlFormattingManager` for the WinMerge VB6 plugin.
- Notepad++ loading the v4.7.2 UnmanagedExports plugin.
- `PoorMansTSqlFormatterWebDemo` building on v4.7.2.

### 2. VSIX project

- Copy `PoorMansTSqlFormatterVSPackage2019` to `PoorMansTSqlFormatterVSPackage` (new ProjectGuid, RootNamespace, AssemblyName).
- Keep the old-style csproj, since VSSDK still expects it.
- Replace `packages.config`, the `Shell.14.0`/`Shell.Immutable.*`/`Threading 14.0` references and the `Sdk.BuildTasks.14.0` imports with PackageReferences:
  - `Microsoft.VisualStudio.SDK` 17.0.x, with `ExcludeAssets="runtime"`, to compile against the lowest API both hosts have.
  - `Microsoft.VSSDK.BuildTools` 17.x.
  - Pick exact versions from NuGet at implementation time.
- `TargetFrameworkVersion`: v4.6 → v4.7.2.

### 3. Manifest

```xml
<Installation>
  <InstallationTarget Id="Microsoft.VisualStudio.Community" Version="[17.0,19.0)">
    <ProductArchitecture>amd64</ProductArchitecture>
  </InstallationTarget>
  <InstallationTarget Id="Microsoft.VisualStudio.Ssms" Version="[22.0,23.0)">
    <ProductArchitecture>amd64</ProductArchitecture>
  </InstallationTarget>
</Installation>
<Prerequisites>
  <Prerequisite Id="Microsoft.VisualStudio.Component.CoreEditor" Version="[17.0,)" />
</Prerequisites>
```

`Community` also covers Pro and Enterprise. The current manifest uses `Pro`, which leaves out Community.

### 4. Code (`FormatterPackage.cs`)

- Add `ThreadHelper.ThrowIfNotOnUIThread()` to the two command callbacks and to `QueryFormatButtonStatus`, which use DTE. The 17.x analyzers (VSTHRD010) flag them otherwise.
- Update version strings and the `InstalledProductRegistration` text.
- Existing bug, not approved yet: `QueryFormatButtonStatus` dereferences `queryingCommand` in the `else` branch even when it's null. Ask before fixing.

### 5. Solution cleanup

Remove from `PoorMansTSqlFormatter.sln` and delete these folders:

- `PoorMansTSqlFormatterVSPackage2013`
- `PoorMansTSqlFormatterVSPackage2019` (after the new project works)
- `PoorMansTSqlFormatterSSMSPackage`
- `PoorMansTSqlFormatterSSMSAddIn`
- `PoorMansTSqlFormatterSSMSPackage.Setup.action`
- `PoorMansTSqlFormatterSSMSAddIn.Setup.action`

Afterwards, update `CLAUDE.md` (build commands, the target list under Architecture, host layers) and the packaging steps in `BUILDING.txt`.
`CLAUDE.md` also puts `NetUtils.cs` in `NetStandardLib`; it's in `PoorMansTSqlFormatterLib`.

### 6. CI (needs a decision)

`appveyor.yml` can't build the new VSIX as it stands. Options:
- Switch to the VS 2022 image and add the `.vsix` as an artifact. The deploy token must be filled in before releases can be published.
- Leave CI on Notepad++ only and package the VSIX by hand, as now.

### 7. Testing

- **VS 2026:** F5 into the experimental instance, `/rootsuffix Exp`.
- **VS 2022:** install the VSIX.
- **SSMS 22:** SSMS has no experimental instance. Install with VSIXInstaller, then attach the debugger to `Ssms.exe`.
- In each host, check the Tools-menu commands (Format, Options), the enable/disable state with no active document, and that settings persist.

## Phase 2: .NET modernisation (after the VSIX ships)

Status: approved in principle, not planned in detail.

In-process VS/SSMS extensions and the Notepad++ plugin must stay on .NET Framework, so only part of the solution moves to .NET 10.
The netstandard2.0 library is already done in Phase 1 (step 1).

| Project | Target |
|---|---|
| `PoorMansTSqlFormatterCmdLine` | `net10.0`; single-file publish replaces ILRepack |
| `PoorMansTSqlFormatterDemo` | `net10.0-windows` (WinForms); single-file publish replaces ILRepack |
| `PoorMansTSqlFormatterTests` | `net10.0`, NUnit 4, `dotnet test` (headless) |
| `PluginShared`, `SSMSLib`, `NppPlugin`, VSIX | .NET Framework 4.8 (SDK-style where VSSDK and UnmanagedExports allow) |

Decisions needed before starting:
- **JSLib (Bridge.NET, abandoned):** keep it frozen, which means the shared source must still compile under Bridge.NET, or drop it.
- **WebDemo (Web Forms):** drop it or rewrite it on ASP.NET Core.

Known work:
- Tests: `Utils.GetTestContentFolder` resolves `..\..\Data` from the working directory, and that breaks with the `bin\<Config>\net10.0` output folder. The expected-output files must stay byte-identical.
- `VersionBump.ps1`: SDK-style projects carry the version in the csproj, or in `Directory.Build.props`, rather than `AssemblyInfo.cs`, so the script needs updating.
- `appveyor.yml` and `BUILDING.txt`: switch to `dotnet build`/`dotnet test` where possible.
- Unverified: whether VSSDK supports SDK-style csproj for VSIX projects in 17.x; check when planning this phase.
