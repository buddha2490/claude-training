# SDTM AE Domain Simulation
# Generates adverse events for WU-001 subjects (Phase 2/3 chronic disease study)
# CT sources: Severity C66769, Serious C66728, Action Taken C66767, Causality C66726, Outcome C66727
# Reads:  data/dm.rds
# Output: data/ae.rds

library(dplyr)
library(tidyr)

set.seed(123)

# --- Load DM ----------------------------------------------------------------

dm <- readRDS("data/dm.rds") %>%
  select(STUDYID, USUBJID, RFSTDTC, RFENDTC, ARMCD)

# --- MedDRA SOC / Preferred Term / Verbatim Term Dictionary -----------------
# Representative profile for a chronic disease Phase 2/3 study.
# Verbatim terms intentionally differ slightly from preferred terms (realistic CRF entries).

ae_dict <- tribble(
  ~AEBODSYS,                                                ~AEDECOD,                           ~AETERM,                       ~wt,
  "Gastrointestinal disorders",                             "Nausea",                            "Nausea",                      0.12,
  "Gastrointestinal disorders",                             "Diarrhoea",                         "Diarrhea",                    0.10,
  "Gastrointestinal disorders",                             "Vomiting",                          "Vomiting",                    0.06,
  "Gastrointestinal disorders",                             "Abdominal pain",                    "Abdominal pain",              0.07,
  "Gastrointestinal disorders",                             "Constipation",                      "Constipation",                0.05,
  "General disorders and administration site conditions",   "Fatigue",                           "Fatigue",                     0.10,
  "General disorders and administration site conditions",   "Pyrexia",                           "Fever",                       0.04,
  "General disorders and administration site conditions",   "Peripheral oedema",                 "Leg swelling",                0.04,
  "Nervous system disorders",                               "Headache",                          "Headache",                    0.08,
  "Nervous system disorders",                               "Dizziness",                         "Dizziness",                   0.05,
  "Nervous system disorders",                               "Insomnia",                          "Insomnia",                    0.04,
  "Infections and infestations",                            "Nasopharyngitis",                   "Common cold",                 0.06,
  "Infections and infestations",                            "Upper respiratory tract infection",  "Upper respiratory infection", 0.05,
  "Infections and infestations",                            "Urinary tract infection",           "Urinary tract infection",     0.03,
  "Musculoskeletal and connective tissue disorders",        "Arthralgia",                        "Joint pain",                  0.04,
  "Musculoskeletal and connective tissue disorders",        "Back pain",                         "Back pain",                   0.05,
  "Musculoskeletal and connective tissue disorders",        "Myalgia",                           "Muscle aches",                0.03,
  "Skin and subcutaneous tissue disorders",                 "Rash",                              "Rash",                        0.04,
  "Skin and subcutaneous tissue disorders",                 "Pruritus",                          "Itching",                     0.03,
  "Investigations",                                         "Alanine aminotransferase increased", "ALT increased",              0.02,
  "Investigations",                                         "Weight decreased",                  "Weight loss",                 0.01
) %>%
  mutate(wt = wt / sum(wt))

# --- Controlled Terminology -------------------------------------------------

# Severity: MILD, MODERATE, SEVERE (C66769)
sev_ct <- c("MILD", "MODERATE", "SEVERE")
sev_wt <- c(0.55, 0.35, 0.10)

# --- Select Subjects and AE Count -------------------------------------------
# ~70% of subjects experience at least one AE (typical for this class of study)

subj_ae <- dm %>%
  mutate(has_ae = runif(n()) < 0.70) %>%
  filter(has_ae) %>%
  mutate(n_ae = sample(1:5, n(), replace = TRUE, prob = c(0.40, 0.30, 0.15, 0.10, 0.05))) %>%
  select(-has_ae) %>%
  uncount(n_ae)                    # one row per AE occurrence

n_ae <- nrow(subj_ae)

# --- Simulate AE Attributes -------------------------------------------------

# Term from dictionary
ae_idx   <- sample(nrow(ae_dict), n_ae, replace = TRUE, prob = ae_dict$wt)
severity <- sample(sev_ct, n_ae, replace = TRUE, prob = sev_wt)

# Serious event flag — higher probability for severe events (C66728: Y / N)
u_ser <- runif(n_ae)
aeser <- case_when(
  severity == "SEVERE"   ~ ifelse(u_ser < 0.40, "Y", "N"),
  severity == "MODERATE" ~ ifelse(u_ser < 0.05, "Y", "N"),
  TRUE                   ~ ifelse(u_ser < 0.01, "Y", "N")
)

# Action taken with study treatment (C66767)
u_acn <- runif(n_ae)
aeacn <- case_when(
  aeser == "Y" | severity == "SEVERE" ~
    case_when(u_acn < 0.35 ~ "DOSE REDUCED",
              u_acn < 0.65 ~ "DRUG WITHDRAWN",
              TRUE         ~ "DOSE NOT CHANGED"),
  severity == "MODERATE" ~
    case_when(u_acn < 0.25 ~ "DOSE REDUCED",
              u_acn < 0.35 ~ "DRUG WITHDRAWN",
              TRUE         ~ "DOSE NOT CHANGED"),
  TRUE ~   # MILD
    case_when(u_acn < 0.80 ~ "DOSE NOT CHANGED",
              TRUE         ~ "NOT APPLICABLE")
)

# Causality (C66726): ~40% of events are related to study drug
aerel <- ifelse(runif(n_ae) < 0.40, "RELATED", "NOT RELATED")

# AE start date: random day within treatment window
rfst      <- as.Date(subj_ae$RFSTDTC)
rfend     <- as.Date(subj_ae$RFENDTC)
trt_days  <- as.integer(rfend - rfst)
aestdtc_raw <- rfst + floor(runif(n_ae) * trt_days)

# AE duration: log-normal (median ~6 days, right-skewed for occasional prolonged events)
ae_dur      <- pmax(1L, round(rlnorm(n_ae, meanlog = 1.8, sdlog = 0.8)))
aeendtc_raw <- aestdtc_raw + ae_dur

# Outcome (C66727): resolved events more common; serious events may be ongoing
u_out <- runif(n_ae)
aeout <- case_when(
  aeser == "Y" ~
    case_when(u_out < 0.55 ~ "RECOVERED/RESOLVED",
              u_out < 0.70 ~ "RECOVERING/RESOLVING",
              u_out < 0.88 ~ "NOT RECOVERED/NOT RESOLVED",
              u_out < 0.95 ~ "FATAL",
              TRUE         ~ "UNKNOWN"),
  TRUE ~
    case_when(u_out < 0.75 ~ "RECOVERED/RESOLVED",
              u_out < 0.85 ~ "RECOVERING/RESOLVING",
              u_out < 0.93 ~ "NOT RECOVERED/NOT RESOLVED",
              TRUE         ~ "UNKNOWN")
)

# Study days (SDTM rule: Day 1 = RFSTDTC; no Day 0)
aestdy <- ifelse(
  aestdtc_raw >= rfst,
  as.integer(aestdtc_raw - rfst) + 1L,
  as.integer(aestdtc_raw - rfst)
)
aeendy <- ifelse(
  aeendtc_raw >= rfst,
  as.integer(aeendtc_raw - rfst) + 1L,
  as.integer(aeendtc_raw - rfst)
)

# --- Assemble Dataset -------------------------------------------------------

ae <- subj_ae %>%
  mutate(
    DOMAIN   = "AE",
    AETERM   = ae_dict$AETERM[ae_idx],
    AEDECOD  = ae_dict$AEDECOD[ae_idx],
    AEBODSYS = ae_dict$AEBODSYS[ae_idx],
    AESEV    = severity,
    AESER    = aeser,
    AEACN    = aeacn,
    AEREL    = aerel,
    AEOUT    = aeout,
    AESTDTC  = as.character(aestdtc_raw),
    AEENDTC  = as.character(aeendtc_raw),
    AESTDY   = aestdy,
    AEENDY   = aeendy
  ) %>%
  arrange(USUBJID, AESTDTC) %>%
  group_by(USUBJID) %>%
  mutate(AESEQ = row_number()) %>%
  ungroup() %>%
  select(
    STUDYID, DOMAIN, USUBJID, AESEQ,
    AETERM, AEDECOD, AEBODSYS,
    AESEV, AESER, AEACN, AEREL, AEOUT,
    AESTDTC, AEENDTC, AESTDY, AEENDY
  )

# --- Variable Labels (required for SDTM transport) --------------------------

labelled::var_label(ae) <- list(
  STUDYID  = "Study Identifier",
  DOMAIN   = "Domain Abbreviation",
  USUBJID  = "Unique Subject Identifier",
  AESEQ    = "Sequence Number",
  AETERM   = "Reported Term for the Adverse Event",
  AEDECOD  = "Dictionary-Derived Term",
  AEBODSYS = "Body System or Organ Class",
  AESEV    = "Severity/Intensity",
  AESER    = "Serious Event",
  AEACN    = "Action Taken with Study Treatment",
  AEREL    = "Causality",
  AEOUT    = "Outcome of Adverse Event",
  AESTDTC  = "Start Date/Time of Adverse Event",
  AEENDTC  = "End Date/Time of Adverse Event",
  AESTDY   = "Study Day of Start of Adverse Event",
  AEENDY   = "Study Day of End of Adverse Event"
)

# --- Save -------------------------------------------------------------------

saveRDS(ae, file = "data/ae.rds")
message("Saved ", nrow(ae), " AE records for ",
        n_distinct(ae$USUBJID), " subjects to data/ae.rds")
