# SDTM DM Domain Simulation
# Generates 1000 simulated subjects conforming to CDISC SDTM DM domain standards.
# CT sources: Race C74457, Ethnic Group C66790, Sex C66731
# Output: data/dm.rds

library(dplyr)
library(lubridate)

set.seed(42)

# --- Constants -----------------------------------------------------------

STUDYID  <- "WU-001"
N        <- 1000

# Sites: 10 sites across 3 countries
sites <- tibble(
  SITEID  = sprintf("%03d", 1:10),
  COUNTRY = c("USA", "USA", "USA", "USA", "CAN", "CAN", "GBR", "GBR", "DEU", "DEU")
)

# Arms: 1:1 randomization
arms <- tibble(
  ARMCD    = c("TRT", "PBO"),
  ARM      = c("Active Treatment", "Placebo"),
  ACTARMCD = c("TRT", "PBO"),
  ACTARM   = c("Active Treatment", "Placebo")
)

# CDISC CT: Race (C74457) — not extensible
race_ct <- c(
  "WHITE",
  "BLACK OR AFRICAN AMERICAN",
  "ASIAN",
  "AMERICAN INDIAN OR ALASKA NATIVE",
  "NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER",
  "OTHER",
  "NOT REPORTED"
)
race_wt <- c(0.60, 0.13, 0.06, 0.01, 0.01, 0.05, 0.14)

# CDISC CT: Ethnic Group (C66790) — not extensible
ethnic_ct <- c("HISPANIC OR LATINO", "NOT HISPANIC OR LATINO", "NOT REPORTED")
ethnic_wt <- c(0.18, 0.78, 0.04)

# CDISC CT: Sex (C66731)
sex_ct <- c("M", "F")
sex_wt <- c(0.52, 0.48)

# --- Subject-level simulation --------------------------------------------

# Assign sites and arms
site_assign <- sites[sample(nrow(sites), N, replace = TRUE), ]
arm_assign  <- arms[sample(nrow(arms),  N, replace = TRUE, prob = c(0.5, 0.5)), ]

# Study dates
# Enrollment window: 2022-01-01 to 2023-06-30
enroll_start <- as.Date("2022-01-01")
enroll_end   <- as.Date("2023-06-30")

rficdtc_raw  <- enroll_start + sample(0:as.integer(enroll_end - enroll_start), N, replace = TRUE)
# Informed consent 1-7 days before first dose
rfstdtc_raw  <- rficdtc_raw + sample(1:7, N, replace = TRUE)
# Treatment duration: 12-52 weeks
duration_days <- sample(84:364, N, replace = TRUE)
rfendtc_raw  <- rfstdtc_raw + duration_days
# Last exposure = reference end (simplification: no early discontinuation handling)
rfxstdtc_raw <- rfstdtc_raw
rfxendtc_raw <- rfendtc_raw
# Last known alive = end of treatment + 0-30 days follow-up
rfpendtc_raw <- rfendtc_raw + sample(0:30, N, replace = TRUE)

# Death: ~2% mortality
dth_flag <- sample(c("Y", ""), N, replace = TRUE, prob = c(0.02, 0.98))
# Death date = 1-30 days after last known alive (only for deaths)
dthdtc_raw <- ifelse(
  dth_flag == "Y",
  as.character(rfpendtc_raw + sample(1:30, N, replace = TRUE)),
  NA_character_
)

# Demographics
age  <- sample(18:80, N, replace = TRUE)
sex  <- sample(sex_ct,    N, replace = TRUE, prob = sex_wt)
race <- sample(race_ct,   N, replace = TRUE, prob = race_wt)
ethnic <- sample(ethnic_ct, N, replace = TRUE, prob = ethnic_wt)

# Study day of DM collection (typically day 1)
dmdy <- 1L

# --- Build DM dataset ----------------------------------------------------

dm <- tibble(
  STUDYID  = STUDYID,
  DOMAIN   = "DM",
  USUBJID  = sprintf("%s-%s-%04d", STUDYID, site_assign$SITEID, seq_len(N)),
  SUBJID   = sprintf("%04d", seq_len(N)),
  RFSTDTC  = as.character(rfstdtc_raw),
  RFENDTC  = as.character(rfendtc_raw),
  RFXSTDTC = as.character(rfxstdtc_raw),
  RFXENDTC = as.character(rfxendtc_raw),
  RFICDTC  = as.character(rficdtc_raw),
  RFPENDTC = as.character(rfpendtc_raw),
  DTHDTC   = dthdtc_raw,
  DTHFL    = dth_flag,
  SITEID   = site_assign$SITEID,
  AGE      = age,
  AGEU     = "YEARS",
  SEX      = sex,
  RACE     = race,
  ETHNIC   = ethnic,
  ARMCD    = arm_assign$ARMCD,
  ARM      = arm_assign$ARM,
  ACTARMCD = arm_assign$ACTARMCD,
  ACTARM   = arm_assign$ACTARM,
  COUNTRY  = site_assign$COUNTRY,
  DMDTC    = RFSTDTC,
  DMDY     = dmdy
)

# Apply variable labels (required for SDTM transport)
labelled::var_label(dm) <- list(
  STUDYID  = "Study Identifier",
  DOMAIN   = "Domain Abbreviation",
  USUBJID  = "Unique Subject Identifier",
  SUBJID   = "Subject Identifier for the Study",
  RFSTDTC  = "Subject Reference Start Date/Time",
  RFENDTC  = "Subject Reference End Date/Time",
  RFXSTDTC = "Date/Time of First Study Treatment",
  RFXENDTC = "Date/Time of Last Study Treatment",
  RFICDTC  = "Date/Time of Informed Consent",
  RFPENDTC = "Date/Time of End of Participation",
  DTHDTC   = "Date/Time of Death",
  DTHFL    = "Subject Death Flag",
  SITEID   = "Study Site Identifier",
  AGE      = "Age",
  AGEU     = "Age Units",
  SEX      = "Sex",
  RACE     = "Race",
  ETHNIC   = "Ethnicity",
  ARMCD    = "Planned Arm Code",
  ARM      = "Description of Planned Arm",
  ACTARMCD = "Actual Arm Code",
  ACTARM   = "Description of Actual Arm",
  COUNTRY  = "Country",
  DMDTC    = "Date/Time of Collection",
  DMDY     = "Study Day of Collection"
)

# --- Save ----------------------------------------------------------------

saveRDS(dm, file = "data/dm.rds")
message("Saved ", nrow(dm), " subjects to data/dm.rds")
