---
name: sas-execution
description: Auto-invoked when running, submitting, or debugging a SAS program on this machine — batch invocation of SAS 9.4, passing -sysin/-log/-print, interpreting the return code, and scanning the log for ERRORs, WARNINGs, and the silent NOTEs that signal wrong answers. Use whenever a .sas file needs to be executed, a SAS log needs to be checked, or SAS output needs to be read back into the conversation. Governs execution mechanics only — not SAS coding standards.
---

# SAS Execution Skill

How to **submit a SAS program, retrieve its log and output, and decide whether it actually worked** on this machine. This skill owns the mechanics of running SAS. It does not own how SAS code is *written* — that belongs to the SAS programming skills and to `.claude/rules/cdisc-conventions.md`.

Every fact in this skill was verified against the local install; none of it is inferred from documentation.

## Local environment (verified)

| Item | Value |
|------|-------|
| Executable | `C:\Program Files\SASHome\SASFoundation\9.4\sas.exe` |
| Release | 9.4 TS1M9 (`9.0401M9`), X64_WIN+PRO |
| Encoding | `wlatin1` (Western Windows) |
| Default destination | LISTING is on in batch — a `.lst` is produced |
| Program location | `SAS/` in the project root |

Confirm the executable exists before the first submission of a session. Do not hardcode a SAS version path into generated code — resolve it once and reuse it.

---

## Rule 1 — Always submit in batch with explicit destinations

The canonical invocation:

```
sas.exe -sysin <program.sas> -log <program.log> -print <program.lst> -nosplash -batch -noterminal
```

`-batch -noterminal` prevent any interactive window or prompt; `-nosplash` suppresses the splash screen. All three are required for an unattended run.

**Always pass `-log` and `-print` explicitly.** Omitting them does *not* put the log next to the program — SAS writes `<program>.log` and `<program>.lst` into the **current working directory**. Submitting `SAS/foo.sas` from the project root silently litters the repo root with `foo.log` and `foo.lst`. This was verified, not guessed.

---

## Rule 2 — Shell-specific invocation (this is where runs actually break)

### PowerShell — must use `Start-Process -Wait`

`sas.exe` is a **GUI-subsystem executable**. PowerShell does not wait for GUI apps, so the obvious form is broken:

```powershell
# WRONG — returns immediately, $LASTEXITCODE is empty, the log does not exist yet
& $sas -sysin "$dir\prog.sas" -log "$dir\prog.log" ...
```

Reading the log after that line gets a missing or stale file. Use `Start-Process` with `-Wait -PassThru` and read `.ExitCode`:

```powershell
$sas = "C:\Program Files\SASHome\SASFoundation\9.4\sas.exe"
$dir = "C:\Users\briancarter\Rdata\claude-training\SAS"

$p = Start-Process -FilePath $sas -Wait -PassThru -NoNewWindow -ArgumentList @(
  "-sysin", "`"$dir\prog.sas`"",
  "-log",   "`"$dir\prog.log`"",
  "-print", "`"$dir\prog.lst`"",
  "-nosplash", "-batch", "-noterminal"
)
Write-Output "SAS exit code: $($p.ExitCode)"
```

### Bash (Git Bash) — must use `cygpath -w`

Bash *does* wait for `sas.exe` and `$?` is correct, so the invocation is simpler — but the **path quoting is a trap**:

```bash
# WRONG — "$dir\\$p.sas" does not expand as expected; SAS receives a literal
# "...\sastest$p.sas", fails to open -sysin, exits 102, and writes NO log at all.
"$SAS" -sysin "$dir\\$p.sas" -log "$dir\\$p.log" ...
```

Never build a Windows path by concatenating a variable after a backslash. Convert the **whole** POSIX path per file:

```bash
SAS="/c/Program Files/SASHome/SASFoundation/9.4/sas.exe"
DIR="/c/Users/briancarter/Rdata/claude-training/SAS"

"$SAS" -sysin "$(cygpath -w "$DIR/prog.sas")" \
       -log   "$(cygpath -w "$DIR/prog.log")" \
       -print "$(cygpath -w "$DIR/prog.lst")" \
       -nosplash -batch -noterminal
echo "SAS exit code: $?"
```

Symptom to recognize: **exit 102 with no log file produced** almost always means SAS could not open `-sysin`, i.e. the path was mangled — not that the SAS code is wrong.

---

## Rule 3 — The return code is a triage signal, never a verdict

Verified return codes on this install:

| RC | Meaning | Action |
|----|---------|--------|
| `0` | Ran to completion, no ERROR and no WARNING | **Still must scan the log** — see Rule 4 |
| `1` | Completed with WARNING(s), no ERRORs | Scan and report the warnings |
| `2` | Completed with ERROR(s) | Report the errors; the run failed |
| `102` (and other 1xx) | SAS never initialized or could not open `-sysin` | **The log may not exist.** Check file existence *before* parsing; suspect a bad path (Rule 2) |

Two failure modes make RC-only checking unsafe in both directions:

- **RC 0 hides broken logic.** A program whose log contains `NOTE: Variable x is uninitialized.` and `NOTE: Missing values were generated...` — a classic typo producing an all-missing column — returns **0**. Verified.
- **RC 102 hides the log.** Never `grep` a log you have not confirmed exists; an empty grep result reads identically to a clean run.

**Never report a SAS run as successful on the strength of the exit code alone.**

---

## Rule 4 — Scan the log in three tiers, every time

After every submission, read the log and classify. Tier 3 is the one that matters most: these are `NOTE:` lines that return RC 0 and produce a **plausible but wrong** dataset.

| Tier | Pattern | Verdict |
|------|---------|---------|
| 1 | `^ERROR` | Run failed. Report and fix. |
| 2 | `^WARNING` | Run suspect. Report; suppress only with a stated reason. |
| 3 | The NOTEs below | Silent wrong answer. Investigate before trusting output. |

Tier 3 NOTEs to treat as failures unless explicitly justified:

- `Variable .* is uninitialized` — misspelled variable name
- `Missing values were generated` — arithmetic on missing values
- `values have been converted` — implicit character/numeric conversion
- `MERGE statement has more than one data set with repeats of BY values` — many-to-many merge
- `Invalid (data|argument|numeric data)` — bad input to a function or informat
- `Division by zero detected`
- `Mathematical operations could not be performed`
- `At least one W.D format was too small` — truncated numbers in output
- `has 0 observations` — an empty result the program did not intend

One scan covering all three tiers:

```bash
LOG="/c/Users/briancarter/Rdata/claude-training/SAS/prog.log"
[ -f "$LOG" ] || { echo "NO LOG — SAS failed to start; check -sysin path"; exit 1; }

grep -n -E '^ERROR|^WARNING|NOTE: (Variable .* is uninitialized|Missing values were generated|.*values have been converted|MERGE statement has more than one data set with repeats|Invalid |Division by zero|Mathematical operations could not be performed|At least one W\.D format was too small|The data set .* has 0 observations)' "$LOG"
```

PowerShell equivalent:

```powershell
if (-not (Test-Path $log)) { throw "NO LOG — SAS failed to start; check -sysin path" }
Select-String -Path $log -Pattern '^ERROR','^WARNING','uninitialized',
  'Missing values were generated','values have been converted',
  'repeats of BY values','^NOTE: Invalid','Division by zero','has 0 observations'
```

Report counts and the matching lines. If all three tiers are clean, say so explicitly — "0 ERROR, 0 WARNING, no suspect NOTEs" — rather than just "it ran".

---

## Rule 5 — Force plain-text-readable listing output

Two separate defaults make a `.lst` hard to read back as text. Fix both:

```sas
options formchar='|----|+|---+=|-/\<>*'   /* ASCII table borders */
        formdlim='-';                      /* dashed rule instead of form feeds */
```

- **`formchar`** — the default table borders are wlatin1 box-drawing bytes that come back as `?????` mojibake. With this setting the borders are `-` and `|`.
- **`formdlim`** — SAS separates pages with a form feed (`0x0C`). It is not mojibake, but it *is* a control character, so a naive "is this file clean ASCII?" check will flag it. `formdlim='-'` replaces each page break with a dashed rule.

Verified: with both set, the `.lst` is 100% printable ASCII. With `formchar` alone, borders are fixed but form feeds remain — expect them, or strip with `tr -d '\f'` rather than mistaking them for an encoding fault.

---

## Rule 6 — Keep programs environment-independent

A `.sas` file must run from any working directory and on any machine. Therefore:

- **No log/output paths inside the program.** Destinations come from `-log` and `-print` at submission time, not from `proc printto` or hardcoded `ods` paths.
- **No absolute `libname` paths** baked into a program meant to be reused. Pass locations in with `-set` / `%let` at the top, or `libname` off a relative path resolved by the caller.
- **Start every program with an options block and reset titles/footnotes** so it does not inherit state:

```sas
options nodate nonumber ls=100 ps=60
        formchar='|----|+|---+=|-/\<>*' formdlim='-';
title;
footnote;
```

- **Seed any random generation** (`call streaminit(<n>)`) so reruns are comparable.

The worked reference is `SAS/sample_analysis.sas` — a self-contained program that builds a dataset and runs `PROC CONTENTS`, `PROC FREQ`, and `PROC MEANS`. Use it as the smoke test when verifying that the SAS connection itself works, before blaming a new program.

---

## Rule 7 — Logs and listings are artifacts, not source

`*.log` and `*.lst` are regenerated on every run. Commit the `.sas` file; never commit its output. Add to `.gitignore`:

```
SAS/*.log
SAS/*.lst
```

If a specific log must be preserved as evidence, copy it under a deliberate name and say why in the commit message.

---

## Rule 8 — Never log PHI, in SAS as in R

`.claude/rules/logging.md` applies to SAS logs too. `PROC PRINT` of patient-level data writes subject identifiers into the `.lst`, and `%put` of a subject value writes them into the `.log`. When debugging clinical data, print **counts, codes, and structure** (`PROC CONTENTS`, `PROC FREQ` of `PARAMCD`, record counts) — not rows. `options mprint;` is safe; `options symbolgen;` can echo subject values into the log, so use it only on non-patient data.

---

## Standard workflow

1. Confirm `sas.exe` exists at the path above.
2. Write or edit the `.sas` file under `SAS/`, following Rule 6.
3. Submit with Rule 1's flags, using the correct shell form from Rule 2.
4. Capture the return code — and confirm the log file exists.
5. Scan the log in three tiers (Rule 4).
6. Read the `.lst` only after the log is clean; a listing from a failed run is misleading.
7. Report: return code, ERROR/WARNING counts, any Tier 3 NOTEs, and where the log and listing are on disk.
