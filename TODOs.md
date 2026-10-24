# TODOs

- [ ] (2026-10-24) Add Arm64 support to the combined VSIX: add `<ProductArchitecture>arm64</ProductArchitecture>` install targets for VS 2026 and SSMS 22 (both ship Arm64 builds). Untested; needs an Arm64 machine to verify. See `VSIX-UPGRADE-PLAN.md`.
- [ ] (2026-10-24) Decide on CI for the VSIX (plan step 6). For now CI stays Notepad++-only (`appveyor.yml`) and the VSIX is packaged by hand. Options: AppVeyor on the VS 2022 image with the `.vsix` as an artifact (the deploy token is still `!!TODO!!`), or Gitea Actions on a Windows runner with VS installed. See `VSIX-UPGRADE-PLAN.md`.
