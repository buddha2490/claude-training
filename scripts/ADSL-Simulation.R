# ADSL Derivation
# Derives the ADaM Subject Level (ADSL) dataset from SDTM DM.
#
# Source:  data/dm.rds
# Output:  data/adsl.rds
#
# All variables are derived from DM. No external data sources are required.
# CT references: Sex C66731, Race C74457, Ethnic C66790, Completion C66727.

library(dplyr)
library(lubridate)
library(labelled)

# --- Load source data --------------------------------------------------------
dm <- readRDS("data/dm.rds")

# --- Derive ADSL -------------------------------------------------------------

adsl <- dm %>%
  mutate(

    # -------------------------------------------------------------------------
    # Subject identifiers (carried from DM)
    # -------------------------------------------------------------------------
    STUDYID = STUDYID,
    USUBJID = USUBJID,
    SUBJID  = SUBJID,
    SITEID  = SITEID,
    COUNTRY = COUNTRY,

    # -------------------------------------------------------------------------
    # Demographics — carried from DM
    # -------------------------------------------------------------------------
    AGE    = AGE,
    AGEU   = "YEARS",
    SEX    = SEX,
    RACE   = RACE,
    ETHNIC = ETHNIC,

    # -------------------------------------------------------------------------
    # Age group (AGEGR1 / AGEGR1N)
    # Standard clinical trial grouping: <65 vs >=65
    # -------------------------------------------------------------------------
    AGEGR1  = case_when(
      AGE < 65            ~ "<65",
      AGE >= 65           ~ ">=65"
    ),
    AGEGR1N = case_when(
      AGEGR1 == "<65"     ~ 1L,
      AGEGR1 == ">=65"    ~ 2L
    ),

    # -------------------------------------------------------------------------
    # Numeric mappings for categorical demographics
    # -------------------------------------------------------------------------
    SEXN = case_when(
      SEX == "M" ~ 1L,
      SEX == "F" ~ 2L,
      TRUE       ~ NA_integer_
    ),
    RACEN = case_when(
      RACE == "WHITE"                                      ~ 1L,
      RACE == "BLACK OR AFRICAN AMERICAN"                  ~ 2L,
      RACE == "ASIAN"                                      ~ 3L,
      RACE == "AMERICAN INDIAN OR ALASKA NATIVE"           ~ 4L,
      RACE == "NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER"  ~ 5L,
      RACE == "OTHER"                                      ~ 6L,
      RACE == "NOT REPORTED"                               ~ 7L,
      TRUE                                                 ~ NA_integer_
    ),
    ETHNICN = case_when(
      ETHNIC == "HISPANIC OR LATINO"     ~ 1L,
      ETHNIC == "NOT HISPANIC OR LATINO" ~ 2L,
      ETHNIC == "NOT REPORTED"           ~ 3L,
      ETHNIC == "UNKNOWN"                ~ 4L,
      TRUE                               ~ NA_integer_
    ),

    # -------------------------------------------------------------------------
    # Treatment assignment (from DM planned and actual arms)
    # -------------------------------------------------------------------------
    TRT01P  = ARM,
    TRT01PN = case_when(
      ARMCD == "TRT" ~ 1L,
      ARMCD == "PBO" ~ 2L,
      TRUE           ~ NA_integer_
    ),
    TRT01A  = ACTARM,
    TRT01AN = case_when(
      ACTARMCD == "TRT" ~ 1L,
      ACTARMCD == "PBO" ~ 2L,
      TRUE              ~ NA_integer_
    ),

    # -------------------------------------------------------------------------
    # Study dates (derived from DM reference dates)
    # TRTSDT / TRTEDTM: treatment start / end as Date
    # TRTDUR: days on treatment (inclusive)
    # RANDDT: date of randomization (informed consent date from DM)
    # -------------------------------------------------------------------------
    TRTSDT  = as.Date(RFSTDTC),
    TRTEDTM = as.Date(RFENDTC),
    TRTDUR  = as.integer(as.Date(RFENDTC) - as.Date(RFSTDTC)) + 1L,
    RANDDT  = as.Date(RFICDTC),

    # -------------------------------------------------------------------------
    # Death (carried from DM)
    # -------------------------------------------------------------------------
    DTHFL  = DTHFL,
    DTHDTC = DTHDTC,

    # -------------------------------------------------------------------------
    # Population flags (ADaM convention: "Y" or "")
    # All subjects in DM were randomized, treated, and are in ITT/Safety.
    # -------------------------------------------------------------------------
    RANDFL = "Y",
    SAFFL  = "Y",
    ITTFL  = "Y",

    # -------------------------------------------------------------------------
    # End of study status (C66727 CT)
    # Derived from DM: DTHFL drives DEATH; everyone else is COMPLETED
    # (DS domain would refine discontinuation reasons in a full submission)
    # -------------------------------------------------------------------------
    EOSSTT  = if_else(DTHFL == "Y", "DEATH", "COMPLETED"),
    COMPLFL = if_else(EOSSTT == "COMPLETED", "Y", "")

  ) %>%
  # Keep only ADSL variables in standard order
  select(
    STUDYID, USUBJID, SUBJID, SITEID, COUNTRY,
    AGE, AGEU, AGEGR1, AGEGR1N,
    SEX, SEXN,
    RACE, RACEN,
    ETHNIC, ETHNICN,
    TRT01P, TRT01PN, TRT01A, TRT01AN,
    TRTSDT, TRTEDTM, TRTDUR,
    RANDDT,
    RANDFL, SAFFL, ITTFL,
    EOSSTT, COMPLFL,
    DTHFL, DTHDTC
  )

# --- Variable labels ---------------------------------------------------------
var_label(adsl) <- list(
  STUDYID  = "Study Identifier",
  USUBJID  = "Unique Subject Identifier",
  SUBJID   = "Subject Identifier for the Study",
  SITEID   = "Study Site Identifier",
  COUNTRY  = "Country",
  AGE      = "Age",
  AGEU     = "Age Units",
  AGEGR1   = "Pooled Age Group 1",
  AGEGR1N  = "Pooled Age Group 1 (N)",
  SEX      = "Sex",
  SEXN     = "Sex (N)",
  RACE     = "Race",
  RACEN    = "Race (N)",
  ETHNIC   = "Ethnicity",
  ETHNICN  = "Ethnicity (N)",
  TRT01P   = "Planned Treatment for Period 01",
  TRT01PN  = "Planned Treatment for Period 01 (N)",
  TRT01A   = "Actual Treatment for Period 01",
  TRT01AN  = "Actual Treatment for Period 01 (N)",
  TRTSDT   = "Date of First Exposure to Treatment",
  TRTEDTM  = "Date of Last Exposure to Treatment",
  TRTDUR   = "Total Treatment Duration (Days)",
  RANDDT   = "Date of Randomization",
  RANDFL   = "Randomized Population Flag",
  SAFFL    = "Safety Population Flag",
  ITTFL    = "Intent-To-Treat Population Flag",
  EOSSTT   = "End of Study Status",
  COMPLFL  = "Completers Population Flag",
  DTHFL    = "Subject Death Flag",
  DTHDTC   = "Date/Time of Death"
)

# --- Save --------------------------------------------------------------------
saveRDS(adsl, file = "data/adsl.rds")
message("Saved ", nrow(adsl), " subjects | ", ncol(adsl), " variables to data/adsl.rds")
