---
name: add-format-test
description: Add a data-driven formatter test case (InputSql + ParsedSql + StandardFormatSql files and csproj entries) from a T-SQL snippet.
disable-model-invocation: true
argument-hint: <sql snippet or file path> [option configs, e.g. "UppercaseKeywords=false"]
---

# Add a formatter test case

Tests in `PoorMansTSqlFormatterTest/Data/` are picked up automatically by file name; see the Tests section of `CLAUDE.md` for how each folder is consumed.

## 1. Gather

From `$ARGUMENTS` or by asking, establish:
- **SQL**: a snippet or a file path.
- **Intent**:
  - *regression*: the current output is correct and should be locked in.
  - *bug/feature*: the current output is wrong, and the user will supply or confirm the correct output.
- **Option configs** (optional): zero or more `Key=Value,...` strings using `TSqlStandardFormatterOptions` property names (e.g. `ExpandCommaLists=false,MaxLineWidth=60`), **not** the command-line switches. The default config is always rendered.
- **ParsedSql**: yes by default. Skip it only if the user says so (not every input has one).

## 2. Name and write the input

- Name it `NN_PascalCase_Words.txt`, where `NN` is one higher than the highest prefix in `Data/InputSql/`.
- If the input is deliberately not valid SQL, end the name with `_INVALID`.
- Write it to a scratchpad folder first (not `Data/`), as UTF-8 **with BOM** and **CRLF** line endings.
- If the user expects first-pass and reformatted output to differ, the input must contain the text `KNOWN SQL REFORMATTING INCONSISTENCY` (usually in a comment). That makes the reparse test skip its consistency asserts.

## 3. Render drafts

```
pwsh -File .claude/skills/add-format-test/render.ps1 -InputFile <scratch input> -OutDir <scratch dir> [-Configs "<cfg1>","<cfg2>"] [-NoParsed]
```

The script builds `PoorMansTSqlFormatterNetStandardLib` (same shared source as the tested .NET 2.0 lib) and writes `ParsedSql/<name>.txt` and `StandardFormatSql/<name>[(<cfg>)].txt` with BOM. It reproduces every existing expected output exactly.

## 4. Review — stop here

The drafts show what the formatter **currently** does. They are not verified expectations.

- Show the user each StandardFormatSql draft in full. For ParsedSql, summarize anything notable, such as the parse error banner, or `Other` nodes where a keyword or structure was expected.
- *Regression intent*: get explicit confirmation the output is correct.
- *Bug/feature intent*: the user supplies the correct output, or tells you how to edit the draft. The resulting test is expected to fail until the code is fixed. Say so.
- Never adjust an expected file just to match what the code produces without the user's say-so.

## 5. Install

Only after approval:
1. Copy the input to `Data/InputSql/`, and the approved drafts to `Data/ParsedSql/` and `Data/StandardFormatSql/`. Keep BOM and CRLF.
2. In `PoorMansTSqlFormatterTest/PoorMansTSqlFormatterTests.csproj`, add `<Content Include="Data\<Folder>\<file>" />` for each new file, in sorted position within its folder's group. Escape `(` and `)` as `%28` and `%29`.
3. Report the files added. The identity-formatter and reparse tests also run against the new input with no extra files needed; mention that.
