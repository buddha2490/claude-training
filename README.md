# Wu AI Harness — Claude Code Training for CDISC Programming

A training repository for Wu Consulting clinical research consultants. Participants use Claude Code to build CDISC-compliant R/Shiny applications, derive ADaM datasets, and produce tables, figures, and listings (TFLs) — with AI as a collaborator rather than as a search engine.

---

## Before You Start

Complete all setup steps in **`claude-training/Claude setup.qmd`** before the first session. That document covers:

- Installing the **Positron** IDE (a free, data-science-focused VS Code fork from Posit)
- Installing **Node.js** and **Claude Code** on Windows, macOS, and Linux
- Creating a **GitHub** account, configuring Git, and setting up SSH authentication
- Cloning this repository and creating your personal working branch

Read it carefully — setup problems on Day 1 waste everyone's time.

---

## R Environment Setup

This repo uses `renv` to pin every R package to a known version. After cloning, open the project in Positron and run the following once in the R console:

```r
renv::restore()
```

This installs all required packages into the project library. If R prompts you to install `renv` itself first, follow the prompt and then run `renv::restore()` again.

To verify the environment is clean:

```r
renv::status()   # should report "No issues found"
```

> **Do not run `install.packages()` directly.** Use `renv::install("pkg")` so the lockfile stays in sync.

---

## Launching the App

Once the environment is restored, launch the starter Shiny application from the Positron terminal:

```bash
Rscript -e "shiny::runApp()"
```

Or click **Run App** in Positron's R panel. The app displays a demographics listing built from the simulated SDTM DM dataset and serves as the starting point for all training exercises.

---

## Starting Claude Code

In the Positron terminal:

```bash
claude
```

For a hands-off session where Claude can read and write files without per-action prompts:

```bash
claude --dangerously-skip-permissions
```

On your first run, Claude will ask you to log in to your Anthropic account. Complete that step in the browser before proceeding.

---

## Repository Overview

```
wu-ai-harness/
├── global.R                    # Package loading, data loading, module sourcing
├── ui.R                        # Shiny UI definition
├── server.R                    # Shiny server logic
├── R/
│   ├── mod_*.R                 # Shiny module files
│   ├── SDTM-DM-Simulation.R   # Source code for simulated SDTM datasets
│   ├── SDTM-AE-Simulation.R
│   ├── SDTM-VS-Simulation.R
│   ├── SDTM-LB-Simulation.R
│   └── ADSL-Simulation.R
├── data/
│   ├── dm.rds                  # SDTM DM  — 1,000 subjects
│   ├── ae.rds                  # SDTM AE  — adverse events
│   ├── vs.rds                  # SDTM VS  — vital signs
│   ├── lb.rds                  # SDTM LB  — laboratory results
│   └── adsl.rds                # ADaM ADSL — subject-level analysis dataset
├── www/
│   └── custom.css              # App stylesheet
├── .claude/
│   ├── rules/                  # Project coding standards (CDISC, R style, Shiny, etc.)
│   ├── skills/                 # Reusable Claude skill definitions
│   └── agents/                 # Feature planner and architect agent definitions
├── rag/                        # CDISC RAG MCP server (auto-started by Claude)
├── claude-training/
│   ├── Claude setup.qmd        # Installation and setup guide  ← START HERE
│   └── syllabus.qmd            # Course outline and exercise descriptions
├── CLAUDE.md                   # Claude's project instructions (read automatically)
├── renv.lock                   # Pinned R package versions
└── .Rprofile                   # Activates renv on project open
```

---

## Simulated Study

All datasets represent a fictional Phase 2/3 study (`WU-001`) with 1,000 subjects across 10 sites in the USA, Canada, UK, and Germany. The study compares an active treatment arm to placebo over 12–52 weeks. Data are structurally CDISC-compliant (SDTM-IG variable names, controlled terminology, ISO 8601 dates, labelled vectors) but not derived from real patients.

---

## Git Workflow

Work on your own branch — never commit directly to `main`:

```bash
git checkout -b feature/<your-name>-<exercise-name>
```

Commit after each completed exercise:

```bash
git add <files>
git commit -m "feat(adsl): derive SAFFL and ITTFL from DM"
```

Do not push to the remote without instructor guidance.

---

## Getting Help

- Ask Claude: describe what you are trying to do and reference the relevant file by name
- CDISC standards: Claude has access to a built-in RAG — ask it to look up any CT codelist or domain definition
- Setup issues: re-read `claude-training/Claude setup.qmd` or ask the instructor
