# Full NICE-role x 12-profile top-1 match distribution table, zero-filled.
# Reuses the cached best_per_role from
# _data-prep-nice-ecsf-alignment.R -- run that first if _data/ is stale.
#
# Output is DATE-STAMPED and previous stamps are never overwritten: each
# CSV is the record of the table as it stood on that date. The 2026-08-14
# file is the 41-role table from before the NICE v2.2.0 re-ingest; the
# 2026-08-21 file is the 42-role table after it.
# Bump RUN_STAMP when regenerating against changed source data.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(here)
})

RUN_STAMP <- "2026-08-21"

data_dir <- here("concordance", "_data")

# Publication terms per framework. This script reads a cached alignment table
# and writes profile titles and counts, no statement text, so no assert call is
# needed; the guard is sourced so it is in hand if a text column is ever added.
# No graph is loaded here, so the guard runs on invariants slugs alone.
source(here("concordance", "_publication-guard.R"))
invisible(publication_policy())

best <- readRDS(file.path(data_dir, "nice_ecsf_best.rds"))

ecsf_levels <- c(
  "Cyber Incident Responder",
  "Chief Information Security Officer (CISO)",
  "Penetration Tester",
  "Cyber Threat Intelligence Specialist",
  "Cybersecurity Auditor",
  "Cybersecurity Architect",
  "Cyber Legal, Policy & Compliance Officer",
  "Cybersecurity Educator",
  "Cybersecurity Implementer",
  "Cybersecurity Researcher",
  "Cybersecurity Risk Manager",
  "Digital Forensics Investigator"
)

distribution <- best |>
  count(ecsf_name, name = "nice_roles_matched") |>
  tidyr::complete(ecsf_name = ecsf_levels, fill = list(nice_roles_matched = 0)) |>
  arrange(desc(nice_roles_matched)) |>
  rename(ecsf_profile = ecsf_name)

# Every NICE role must land in exactly one bucket. Derive the expected
# total from the input rather than pinning it to a literal: the previous
# hardcoded 41L failed the moment NICE went to 42 work roles in v2.2.0,
# which is the right failure but the wrong reason to have to edit a script.
n_nice_roles <- nrow(best)
stopifnot(sum(distribution$nice_roles_matched) == n_nice_roles)
stopifnot(nrow(distribution) == 12L)

out_path <- here("concordance", "_data",
                 paste0("nice_ecsf_distribution_", RUN_STAMP, ".csv"))
if (file.exists(out_path)) {
  stop("Refusing to overwrite an existing dated table:", out_path,
       "\nBump RUN_STAMP if this is a new regeneration.")
}
write.csv(distribution, out_path, row.names = FALSE)

cat("\n=== Full ", n_nice_roles, "-role x 12-profile top-1 match distribution ===\n", sep = "")
print(distribution, n = 12)
cat("\nSum check: ", sum(distribution$nice_roles_matched),
    " (must equal ", n_nice_roles, ")\n", sep = "")
cat("Profiles with zero top-1 matches: ",
    paste(distribution$ecsf_profile[distribution$nice_roles_matched == 0], collapse = "; "),
    "\n", sep = "")
cat("Written to: ", out_path, "\n", sep = "")
