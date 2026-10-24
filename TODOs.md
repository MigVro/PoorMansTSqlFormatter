# TODOs

- [ ] (2026-10-24) Add Arm64 support to the combined VSIX: add `<ProductArchitecture>arm64</ProductArchitecture>` install targets for VS 2026 and SSMS 22 (both ship Arm64 builds). Untested; needs an Arm64 machine to verify. See `VSIX-UPGRADE-PLAN.md`.
- [x] (2026-10-24) CI for the VSIX (plan step 6): GitHub Actions workflow `.github/workflows/vsix.yml` builds it and attaches it to releases on version tags.
