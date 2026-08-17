# Wu AI Harness — Claude Code Instructions

## What This Project Is

This is a training harness for Wu Consulting clinical research consultants learning to use Claude Code for CDISC programming workflows. The repo contains a working Shiny application, simulated SDTM and ADaM datasets, and a set of rules, skills, and agents tailored to clinical data programming.

The goal of each exercise is to produce CDISC-compliant R code by collaborating with Claude — not by writing it from scratch. Claude reads the existing files, understands the standards, and generates code that the consultant then reviews and validates.

---

## Simulated Study

**Study ID:** WU-001 | **N:** 1,000 subjects | **Arms:** Active Treatment (TRT) vs. Placebo (PBO), 1:1
**Sites:** 10 sites across USA, Canada, United Kingdom, Germany
**Enrollment:** January 2022 – June 2023 | **Treatment duration:** 12–52 weeks

### Available Datasets (`data/`)

| File | Domain/Dataset | Description |
|------|----------------|-------------|
| `dm.rds` | SDTM DM | Demographics — 1,000 subjects, source of all `USUBJID` |
| `ae.rds` | SDTM AE | Adverse events — 1,466 records across 705 subjects |
| `vs.rds` | SDTM VS | Vital signs — 33,404 records, 5 parameters, up to 8 visits |
| `lb.rds` | SDTM LB | Lab results — 136,366 records, 24 tests (chemistry + hematology) |
| `adsl.rds` | ADaM ADSL | Subject-level analysis dataset derived from DM |

All datasets share the same `STUDYID`, `USUBJID`, and site structure. Dates in AE, VS, and LB are bounded by each subject's `RFSTDTC`/`RFENDTC` from DM.

### Simulated Data Limitations

These datasets are realistic in structure and terminology but are not derived from real patients. Participants should validate code logic but should not need to question the plausibility of individual data points.

---

## Application Structure

The app uses the three-file layout: `global.R`, `ui.R`, `server.R`. Module files live in `R/mod_*.R` and are sourced in `global.R`. Never use `app.R`. See `.claude/rules/shiny-app-structure.md` for the full convention.

---

## Git Rules for Training Participants

**Never work on `main`.** Before starting any exercise:

```bash
git checkout -b feature/<your-name>-<exercise>
```

- Commit after each completed exercise unit with a Conventional Commit message
- Do not push to the remote without instructor guidance
- Claude may suggest commits; always review staged files before confirming

---

## CDISC Standards

When working with SDTM or ADaM variables, always consult the built-in RAG before hardcoding controlled terminology values. The RAG has CDISC CT codelist definitions indexed and searchable.

- Use `mcp__cdisc-rag__rag_search` for CT lookups, domain definitions, and variable labels
- Follow `.claude/rules/cdisc-conventions.md` for date formats, identifier construction, flag encoding, and missing value handling
- Variable names follow SDTM-IG: uppercase, max 8 characters

---

## Coding Standards

- **R style:** tidyverse (`%>%`, `snake_case`, `library()` not `require()`) — see `.claude/rules/r-style.md`
- **Packages:** all `library()` calls in `global.R`; no loading in modules or `server.R`
- **Namespace conflicts:** qualify only when genuinely ambiguous — see `.claude/rules/namespace-conflicts.md`
- **Error handling:** wrap risky operations in `with_error_handling()` — see `.claude/rules/error-handling.md`

---

## Acceptance Criteria

An exercise is complete when:

1. The app launches without errors (`Rscript -e "shiny::runApp()"` or Run App in Positron)
2. Every tab/output the exercise touched renders without a red error box
3. The code follows the conventions in `.claude/rules/`
4. A commit exists on your personal branch with a meaningful message

---

## What Claude Should NOT Do

- Do not push without the participant explicitly asking
- Do not install packages not already in `renv.lock` without confirming with the participant
- Do not modify simulation scripts in `R/SDTM-*` or `R/ADSL-Simulation.R`
- Do not modify files in `claude-training/`
