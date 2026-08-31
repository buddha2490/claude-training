# SDTM LB Domain Simulation
# Generates laboratory test results for WU-001 subjects across scheduled study visits
# Panels: Chemistry (14 tests) and Hematology (10 tests)
# Sex-specific reference ranges applied to HGB, HCT, RBC
# CT sources: LBTESTCD C65047, Units C71620, Normal Range Indicator C78736
# Reads:  data/dm.rds
# Output: data/lb.rds

library(dplyr)
library(tidyr)

set.seed(789)

# --- Load DM ----------------------------------------------------------------

dm <- readRDS("data/dm.rds") %>%
  select(STUDYID, USUBJID, RFSTDTC, RFENDTC, SEX)

# --- Visit Schedule ---------------------------------------------------------
# Labs drawn at same scheduled visits as VS; no screening labs in this study.

visits <- tibble(
  VISITNUM   = c(  2L,         3L,       4L,       5L,        6L,        7L,        99L),
  VISIT      = c("BASELINE", "WEEK 4", "WEEK 8", "WEEK 12", "WEEK 26", "WEEK 52", "END OF STUDY"),
  target_day = c(  1L,         28L,      56L,      84L,       182L,      364L,      NA_integer_)
)

# --- Laboratory Parameter Reference Tables ----------------------------------
# Columns with _m / _f suffix are sex-specific (M = Male, F = Female).
# For analytes with identical ranges by sex, _m == _f.
# subj_sd: between-subject variability (random intercept)
# resid_sd: within-subject visit-to-visit variability
# decimals: rounding for LBSTRESN / LBORRES

lb_params <- tribble(
  ~LBTESTCD,  ~LBTEST,                        ~LBCAT,       ~LBSTRESU,    ~mean_m,  ~sd_m,   ~lo_m,  ~hi_m,  ~mean_f,  ~sd_f,   ~lo_f,  ~hi_f,  ~resid_sd, ~decimals,
  # --- Chemistry ------------------------------------------------------------
  "SODIUM",   "Sodium",                        "CHEMISTRY",  "mEq/L",       140,      3,      136,    145,     140,      3,      136,    145,     1.5,       0,
  "POTASSI",  "Potassium",                     "CHEMISTRY",  "mEq/L",         4.2,    0.4,      3.5,    5.0,     4.2,    0.4,      3.5,    5.0,     0.2,       1,
  "CHLORIDE", "Chloride",                      "CHEMISTRY",  "mEq/L",       102,      3,       98,    107,     102,      3,       98,    107,     1.5,       0,
  "BICARB",   "Bicarbonate",                   "CHEMISTRY",  "mEq/L",        25,      2,       22,     29,      25,      2,       22,     29,     1.0,       0,
  "BUN",      "Blood Urea Nitrogen",           "CHEMISTRY",  "mg/dL",        14,      5,        7,     20,      12,      4,        7,     20,     2.0,       0,
  "CREAT",    "Creatinine",                    "CHEMISTRY",  "mg/dL",         1.0,    0.15,     0.7,    1.3,     0.8,    0.15,     0.5,    1.1,     0.06,      2,
  "GLUC",     "Glucose",                       "CHEMISTRY",  "mg/dL",        92,     18,       70,    100,      90,     16,       70,    100,     5.0,       0,
  "CALCIUM",  "Calcium",                       "CHEMISTRY",  "mg/dL",         9.5,    0.5,      8.5,   10.2,     9.4,    0.5,      8.5,   10.2,     0.2,       1,
  "ALT",      "Alanine Aminotransferase",      "CHEMISTRY",  "U/L",          22,     12,        7,     40,      18,     10,        7,     35,     4.0,       0,
  "AST",      "Aspartate Aminotransferase",    "CHEMISTRY",  "U/L",          24,     10,       10,     40,      20,      8,       10,     35,     3.0,       0,
  "ALKPH",    "Alkaline Phosphatase",          "CHEMISTRY",  "U/L",          80,     30,       44,    147,      75,     28,       44,    147,    10.0,       0,
  "BILI",     "Total Bilirubin",               "CHEMISTRY",  "mg/dL",         0.7,    0.3,      0.1,    1.2,     0.6,    0.3,      0.1,    1.2,     0.1,       1,
  "ALBUMIN",  "Albumin",                       "CHEMISTRY",  "g/dL",          4.2,    0.4,      3.5,    5.0,     4.1,    0.4,      3.5,    5.0,     0.1,       1,
  "PROTEIN",  "Total Protein",                 "CHEMISTRY",  "g/dL",          7.2,    0.5,      6.0,    8.3,     7.1,    0.5,      6.0,    8.3,     0.2,       1,
  # --- Hematology -----------------------------------------------------------
  "WBC",      "Leukocytes",                    "HEMATOLOGY", "10^9/L",        7.0,    1.5,      4.5,   11.0,     7.0,    1.5,      4.5,   11.0,    0.5,       1,
  "RBC",      "Erythrocytes",                  "HEMATOLOGY", "10^12/L",       5.0,    0.4,      4.5,    5.5,     4.5,    0.4,      4.0,    5.0,    0.15,      2,
  "HGB",      "Hemoglobin",                    "HEMATOLOGY", "g/dL",         15.0,    1.0,     13.5,   17.5,    13.0,    1.0,     12.0,   15.5,    0.3,       1,
  "HCT",      "Hematocrit",                    "HEMATOLOGY", "%",            46,      3,       41,     53,      40,      3,       36,     46,     0.8,       0,
  "PLT",      "Platelets",                     "HEMATOLOGY", "10^9/L",      250,     60,      150,    400,     265,     60,      150,    400,    10.0,       0,
  "NEUT",     "Neutrophils",                   "HEMATOLOGY", "10^9/L",        4.0,    1.5,      1.8,    7.7,     4.0,    1.5,      1.8,    7.7,    0.4,       2,
  "LYMPH",    "Lymphocytes",                   "HEMATOLOGY", "10^9/L",        2.5,    0.8,      1.0,    4.8,     2.5,    0.8,      1.0,    4.8,    0.2,       2,
  "MONO",     "Monocytes",                     "HEMATOLOGY", "10^9/L",        0.50,   0.20,     0.20,   0.80,    0.50,   0.20,     0.20,   0.80,   0.05,      2,
  "EOS",      "Eosinophils",                   "HEMATOLOGY", "10^9/L",        0.20,   0.15,     0.00,   0.50,    0.20,   0.15,     0.00,   0.50,   0.04,      2,
  "BASO",     "Basophils",                     "HEMATOLOGY", "10^9/L",        0.05,   0.04,     0.00,   0.10,    0.05,   0.04,     0.00,   0.10,   0.01,      2
)

# --- Subject-level Baseline Values (random intercept per subject/analyte) ---
# Join SEX to select the correct sex-specific distribution parameters.

subj_baselines <- dm %>%
  select(USUBJID, SEX) %>%
  crossing(lb_params %>% select(LBTESTCD, mean_m, sd_m, mean_f, sd_f)) %>%
  mutate(
    lbmean    = ifelse(SEX == "M", mean_m, mean_f),
    lbsd      = ifelse(SEX == "M", sd_m,   sd_f),
    baseline_val = rnorm(n(), lbmean, lbsd)
  ) %>%
  select(USUBJID, LBTESTCD, baseline_val)

# --- Expand to All Subject x Analyte x Visit Combinations ------------------

lb_all <- dm %>%
  crossing(lb_params) %>%
  crossing(visits) %>%
  left_join(subj_baselines, by = c("USUBJID", "LBTESTCD")) %>%
  arrange(USUBJID, LBTESTCD, VISITNUM)

# --- Calculate Visit Dates --------------------------------------------------

lb_all <- lb_all %>%
  mutate(
    rfst  = as.Date(RFSTDTC),
    rfend = as.Date(RFENDTC),
    jitter = case_when(
      VISITNUM %in% c(2L, 99L) ~ 0L,
      TRUE                     ~ sample(-1L:1L, n(), replace = TRUE)  # tighter window for lab draws
    ),
    lbdtc_raw = case_when(
      is.na(target_day) ~ rfend,
      TRUE              ~ rfst + (target_day - 1L) + jitter
    )
  ) %>%
  filter(lbdtc_raw <= rfend)

# --- Generate Analyte Values ------------------------------------------------
# Select sex-appropriate normal range; generate value from subject baseline + noise.

lb_all <- lb_all %>%
  mutate(
    lbstnrlo = ifelse(SEX == "M", lo_m, lo_f),
    lbstnrhi = ifelse(SEX == "M", hi_m, hi_f),
    visit_noise = rnorm(n(), 0, resid_sd),
    raw_val     = baseline_val + visit_noise,
    # Clamp to biologically plausible range (3 SD below lower / above upper limit)
    raw_val     = pmax(lbstnrlo * 0.5, pmin(lbstnrhi * 2, raw_val)),
    lbstresn    = round(raw_val, decimals)
  )

# --- Normal Range Indicator (C78736: H / N / L) ----------------------------

lb_all <- lb_all %>%
  mutate(
    LBNRIND = case_when(
      lbstresn > lbstnrhi ~ "H",
      lbstresn < lbstnrlo ~ "L",
      TRUE                 ~ "N"
    )
  )

# --- Introduce ~2% Missing Results (realistic missed blood draws) -----------

miss_idx <- sample(nrow(lb_all), floor(0.02 * nrow(lb_all)))
lb_all <- lb_all %>%
  mutate(
    lbstresn = ifelse(row_number() %in% miss_idx, NA_real_, lbstresn),
    LBNRIND  = ifelse(row_number() %in% miss_idx, NA_character_, LBNRIND)
  )

# --- SDTM Study Day (no Day 0 rule) -----------------------------------------

lb_all <- lb_all %>%
  mutate(
    LBDY = ifelse(
      lbdtc_raw >= rfst,
      as.integer(lbdtc_raw - rfst) + 1L,
      as.integer(lbdtc_raw - rfst)
    )
  )

# --- Baseline Flag: Day 1 (VISITNUM 2) --------------------------------------

lb_all <- lb_all %>%
  mutate(LBBLFL = ifelse(VISITNUM == 2L, "Y", ""))

# --- Assemble Final Dataset -------------------------------------------------

lb <- lb_all %>%
  mutate(
    DOMAIN   = "LB",
    LBORRES  = ifelse(is.na(lbstresn), NA_character_, as.character(lbstresn)),
    LBORRESU = LBSTRESU,
    LBSTRESC = LBORRES,
    LBDTC    = as.character(lbdtc_raw)
  ) %>%
  arrange(USUBJID, LBCAT, LBTESTCD, VISITNUM) %>%
  group_by(USUBJID) %>%
  mutate(LBSEQ = row_number()) %>%
  ungroup() %>%
  select(
    STUDYID, DOMAIN, USUBJID, LBSEQ,
    LBTESTCD, LBTEST, LBCAT,
    LBORRES, LBORRESU, LBSTRESC, LBSTRESN = lbstresn, LBSTRESU,
    LBSTNRLO = lbstnrlo, LBSTNRHI = lbstnrhi, LBNRIND,
    LBBLFL, VISITNUM, VISIT, LBDTC, LBDY
  )

# --- Variable Labels --------------------------------------------------------

labelled::var_label(lb) <- list(
  STUDYID  = "Study Identifier",
  DOMAIN   = "Domain Abbreviation",
  USUBJID  = "Unique Subject Identifier",
  LBSEQ    = "Sequence Number",
  LBTESTCD = "Lab Test or Examination Short Name",
  LBTEST   = "Lab Test or Examination Name",
  LBCAT    = "Category for Lab Test",
  LBORRES  = "Result or Finding in Original Units",
  LBORRESU = "Original Units",
  LBSTRESC = "Character Result/Finding in Std Format",
  LBSTRESN = "Numeric Result/Finding in Standard Units",
  LBSTRESU = "Standard Units",
  LBSTNRLO = "Reference Range Lower Limit-Std Units",
  LBSTNRHI = "Reference Range Upper Limit-Std Units",
  LBNRIND  = "Reference Range Indicator",
  LBBLFL   = "Baseline Flag",
  VISITNUM = "Visit Number",
  VISIT    = "Visit Name",
  LBDTC    = "Date/Time of Specimen Collection",
  LBDY     = "Study Day of Specimen Collection"
)

# --- Save -------------------------------------------------------------------

saveRDS(lb, file = "data/lb.rds")
message("Saved ", nrow(lb), " LB records for ",
        n_distinct(lb$USUBJID), " subjects to data/lb.rds")
