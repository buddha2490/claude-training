# SDTM VS Domain Simulation
# Generates vital signs for WU-001 subjects across scheduled study visits
# CT sources: VSTESTCD C66770, Units C71620
# Reads:  data/dm.rds
# Output: data/vs.rds

library(dplyr)
library(tidyr)

set.seed(456)

# --- Load DM ----------------------------------------------------------------

dm <- readRDS("data/dm.rds") %>%
  select(STUDYID, USUBJID, RFSTDTC, RFENDTC)

# --- Visit Schedule ---------------------------------------------------------
# Nominal study days drive date calculation.
# target_day: positive = days from RFSTDTC (Day 1); negative = pre-dose; NA = use RFENDTC

visits <- tibble(
  VISITNUM   = c(  1L,          2L,         3L,       4L,       5L,        6L,        7L,        99L),
  VISIT      = c("SCREENING", "BASELINE", "WEEK 4", "WEEK 8", "WEEK 12", "WEEK 26", "WEEK 52", "END OF STUDY"),
  target_day = c( -7L,         1L,         28L,      56L,      84L,       182L,      364L,      NA_integer_)
)

# --- VS Parameter Reference -------------------------------------------------
# resid_sd: within-subject visit-to-visit variability (measurement + biological)
# decimals: rounding precision for VSORRES/VSSTRESN

vs_params <- tribble(
  ~VSTESTCD, ~VSTEST,                      ~VSORRESU,   ~VSSTRESU,   ~subj_mean, ~subj_sd, ~resid_sd, ~decimals, ~lo,  ~hi,
  "SYSBP",   "Systolic Blood Pressure",    "mmHg",      "mmHg",       130,        15,        5,         0,         80,   200,
  "DIABP",   "Diastolic Blood Pressure",   "mmHg",      "mmHg",        80,        10,        3,         0,         50,   120,
  "PULSE",   "Pulse Rate",                 "beats/min", "beats/min",   72,        10,        4,         0,         40,   130,
  "TEMP",    "Temperature",                "C",         "C",           36.8,       0.3,       0.2,       1,         35.5, 40.0,
  "WEIGHT",  "Weight",                     "kg",        "kg",          80,        15,        0.5,       1,         40,   180
)

# --- Subject-level Baseline Values (random intercept per subject/param) -----
# Each subject has a stable underlying true value that persists across visits.

subj_baselines <- dm %>%
  select(USUBJID) %>%
  crossing(vs_params %>% select(VSTESTCD, subj_mean, subj_sd)) %>%
  mutate(baseline_val = rnorm(n(), subj_mean, subj_sd)) %>%
  select(USUBJID, VSTESTCD, baseline_val)

# --- Expand to All Subject x Parameter x Visit Combinations ----------------

vs_all <- dm %>%
  crossing(vs_params %>% select(VSTESTCD, VSTEST, VSORRESU, VSSTRESU, resid_sd, decimals, lo, hi)) %>%
  crossing(visits) %>%
  left_join(subj_baselines, by = c("USUBJID", "VSTESTCD")) %>%
  arrange(USUBJID, VSTESTCD, VISITNUM)

# --- Calculate Visit Dates --------------------------------------------------
# BASELINE and END OF STUDY have no date jitter; all other visits ± 2 days.

vs_all <- vs_all %>%
  mutate(
    rfst  = as.Date(RFSTDTC),
    rfend = as.Date(RFENDTC),
    jitter = case_when(
      VISITNUM %in% c(2L, 99L) ~ 0L,
      TRUE                     ~ sample(-2L:2L, n(), replace = TRUE)
    ),
    # SDTM day-to-date: Day 1 = rfst, Day 28 = rfst + 27 days, etc.
    vsdtc_raw = case_when(
      is.na(target_day) ~ rfend,
      target_day < 0    ~ rfst + target_day + jitter,       # pre-dose (screening)
      TRUE              ~ rfst + (target_day - 1L) + jitter  # on/post-dose
    )
  ) %>%
  # Drop nominal visits that fall after the subject's last treatment day
  filter(vsdtc_raw <= rfend)

# --- Generate Measurement Values --------------------------------------------
# Measurement = subject baseline + small random visit noise, clamped to physiology bounds

vs_all <- vs_all %>%
  mutate(
    visit_noise = rnorm(n(), 0, resid_sd),
    raw_val     = baseline_val + visit_noise,
    # Clamp to physiologically plausible range
    raw_val     = pmax(lo, pmin(hi, raw_val)),
    vsstresn    = round(raw_val, decimals)
  )

# --- Introduce ~3% Missing Measurements (realistic CRF omissions) -----------

miss_idx <- sample(nrow(vs_all), floor(0.03 * nrow(vs_all)))
vs_all <- vs_all %>%
  mutate(vsstresn = ifelse(row_number() %in% miss_idx, NA_real_, vsstresn))

# --- SDTM Study Day (no Day 0 rule) -----------------------------------------

vs_all <- vs_all %>%
  mutate(
    VSDY = ifelse(
      vsdtc_raw >= rfst,
      as.integer(vsdtc_raw - rfst) + 1L,
      as.integer(vsdtc_raw - rfst)
    )
  )

# --- Baseline Flag: last pre-dose assessment (VISITNUM 2 = Day 1) -----------

vs_all <- vs_all %>%
  mutate(VSBLFL = ifelse(VISITNUM == 2L, "Y", ""))

# --- Assemble Final Dataset -------------------------------------------------

vs <- vs_all %>%
  mutate(
    DOMAIN   = "VS",
    VSORRES  = ifelse(is.na(vsstresn), NA_character_, as.character(vsstresn)),
    VSSTRESC = VSORRES,
    VSSTRESN = vsstresn,
    VSDTC    = as.character(vsdtc_raw)
  ) %>%
  arrange(USUBJID, VSTESTCD, VISITNUM) %>%
  group_by(USUBJID) %>%
  mutate(VSSEQ = row_number()) %>%
  ungroup() %>%
  select(
    STUDYID, DOMAIN, USUBJID, VSSEQ,
    VSTESTCD, VSTEST,
    VSORRES, VSORRESU, VSSTRESC, VSSTRESN, VSSTRESU,
    VSBLFL, VISITNUM, VISIT, VSDTC, VSDY
  )

# --- Variable Labels --------------------------------------------------------

labelled::var_label(vs) <- list(
  STUDYID  = "Study Identifier",
  DOMAIN   = "Domain Abbreviation",
  USUBJID  = "Unique Subject Identifier",
  VSSEQ    = "Sequence Number",
  VSTESTCD = "Vital Signs Test Short Name",
  VSTEST   = "Vital Signs Test Name",
  VSORRES  = "Result or Finding in Original Units",
  VSORRESU = "Original Units",
  VSSTRESC = "Character Result/Finding in Std Format",
  VSSTRESN = "Numeric Result/Finding in Standard Units",
  VSSTRESU = "Standard Units",
  VSBLFL   = "Baseline Flag",
  VISITNUM = "Visit Number",
  VISIT    = "Visit Name",
  VSDTC    = "Date/Time of Measurements",
  VSDY     = "Study Day of Vital Signs"
)

# --- Save -------------------------------------------------------------------

saveRDS(vs, file = "data/vs.rds")
message("Saved ", nrow(vs), " VS records for ",
        n_distinct(vs$USUBJID), " subjects to data/vs.rds")
