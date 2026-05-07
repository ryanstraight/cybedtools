#!/usr/bin/env Rscript
# 000-build.R
#
# Master orchestrator. Runs the full pipeline from ingestion through
# query execution, producing every output under data/processed/.
#
# Prerequisites:
#   - Each framework's source file staged under data/raw/<framework>/
#     (see docs/framework-data-sources.md for where to obtain each).
#   - R >= 4.3.0 with package dependencies listed in DESCRIPTION.
#
# Usage:
#   Rscript scripts/000-build.R
#
# Output:
#   data/raw/<framework>/tables/*.csv     per-framework tidy CSVs
#   data/raw/<framework>/provenance.yml   SHA256 + retrieval manifest
#   data/processed/jsonld/*.jsonld        assembled semantic graphs
#   data/processed/query-results/*.csv    SPARQL query results
#   docs/ingestion-summary.md             auto-generated framework inventory
#   data/audit/audit-log.ndjson           append-only verification log
#
# Failure handling:
#   - Ingestion scripts abort if their source file is missing (manual-stage
#     frameworks only; the auto-download frameworks re-fetch on demand).
#   - Verification is the gate: HARD failures exit with non-zero status
#     before downstream steps run. SOFT flags warn and continue.
#   - Assembly + query steps exit non-zero on any R error.

suppressPackageStartupMessages({
  library(here)
})

# Ingestion scripts (one per framework). Each is idempotent.
ingestion_scripts <- c(
  "scripts/010-ingest-nice.R",
  "scripts/010-ingest-sfia.R",
  "scripts/010-ingest-dcwf.R",
  "scripts/010-ingest-ecsf.R",
  "scripts/010-ingest-cyberorg.R",
  "scripts/010-ingest-csta.R",
  "scripts/010-ingest-csec2017.R",
  "scripts/010-ingest-digcomp.R"
)

# Pipeline stages after ingestion
post_ingestion_scripts <- c(
  "scripts/015-verify-ingestion.R",
  "scripts/016-summarize-ingestion.R",
  "scripts/020-assemble-jsonld.R",
  "scripts/025-export-ntriples.R",
  "scripts/040-run-sparql.R"
)

run_stage <- function(script_path) {
  full_path <- here(script_path)
  if (!file.exists(full_path)) {
    stop("Missing script: ", full_path)
  }
  message("\n=== Running: ", script_path, " ===")
  exit_code <- system2("Rscript", args = full_path, stdout = "", stderr = "")
  if (exit_code != 0) {
    stop("Stage failed: ", script_path, " (exit ", exit_code, ")")
  }
  invisible(exit_code)
}

message("=== cybedtools pipeline build ===")
message("Project root: ", here())

for (script in c(ingestion_scripts, post_ingestion_scripts)) {
  run_stage(script)
}

message("\n=== Build complete ===")
message("Outputs:")
message("  data/raw/<framework>/tables/       -- tidy CSVs per framework")
message("  data/processed/jsonld/*.jsonld     -- assembled semantic graphs")
message("  data/processed/query-results/*.csv -- SPARQL query outputs")
message("  docs/ingestion-summary.md          -- framework inventory")
message("  data/audit/audit-log.ndjson        -- verification audit log")
