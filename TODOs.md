# TODOs

- [ ] (2026-10-24) Add Arm64 support to the combined VSIX: add `<ProductArchitecture>arm64</ProductArchitecture>` install targets for VS 2026 and SSMS 22 (both ship Arm64 builds). Untested; needs an Arm64 machine to verify. See `VSIX-UPGRADE-PLAN.md`.
- [ ] (2026-10-24) Parse DDL triggers (`FOR LOGON`, `ON ALL SERVER` / `ON DATABASE`); the parser has no handling for them yet.
- [ ] (2026-10-24) Format/indent ranking and window functions (`OVER (PARTITION BY ... ORDER BY ...)`); `OVER` and `PARTITION` are currently plain keywords.
- [ ] (2026-10-24) Verify VSIX settings survive major VS 2026 / SSMS 22 upgrades, and whether they are shared between VS and SSMS.
- [ ] (2026-10-24) Replace the old FxCop item with the .NET analyzers (`<EnableNETAnalyzers>` / `<AnalysisLevel>`), at least on the library.
- [ ] (2026-10-24) Decide on table hints without `WITH` (compat level 80): drop support and treat only `WITH (...)` as hints, or keep parsing them as function arguments.
- [x] (2026-10-24) CI for the VSIX (plan step 6): GitHub Actions workflow `.github/workflows/vsix.yml` builds it and attaches it to releases on version tags.
