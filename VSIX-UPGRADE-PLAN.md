# Combined VSIX upgrade plan (VS 2022/2026 + SSMS 21/22)

Status: approved, not started.

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

## Decisions

1. Identity: new GUIDs (manifest Identity, package, command set) and a new `Key.snk`. Done as a guided step (see step 0).
2. New project folder `PoorMansTSqlFormatterVSPackage`, based on `PoorMansTSqlFormatterVSPackage2019`.
3. Obsolete projects are removed from the solution and their folders deleted.
4. Arm64: deferred, tracked in `TODOs.md`.

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

Unverified: whether `PoorMansTSqlFormatterWebDemo` still builds in VS 2026.

### 5. Testing

- **VS 2026:** F5 into the experimental instance, `/rootsuffix Exp`.
- **VS 2022:** install the VSIX.
- **SSMS 21/22:** SSMS has no experimental instance. Install with VSIXInstaller, then attach the debugger to `Ssms.exe`.
- In each host, check the Tools-menu commands (Format, Options), the enable/disable state with no active document, and that settings persist.
