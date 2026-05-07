# 010-ingest-csta.R
#
# Ingest the CSTA K-12 Computer Science Standards (Revised 2017) from the
# CSTA Foundation XLSX distribution.
#
# Source: csta-k-12-standards-revised-2017.xlsx, CSTA Foundation.
# License: CC BY-NC-SA 4.0 (attribution, non-commercial, share-alike).
#
# Structure (single sheet, 9 columns):
#   Identifier | Level | Grades | Standard | Clarification | Concept |
#   Subconcept | Practice | Subpractice
#
# Note: CSTA is not cybersecurity-specific. Cybersec-relevant content
# concentrates in the "Impacts of Computing" and "Networks & the Internet"
# concepts. Included to support pedagogical-framework comparison against
# cybersecurity-specific K-12 standards.
#
# Run: Rscript scripts/010-ingest-csta.R

suppressPackageStartupMessages({
  library(here)
  library(readxl)
  library(dplyr)
  library(readr)
  library(yaml)
  library(glue)
  library(purrr)
  library(tibble)
  library(stringr)
  library(digest)
})

csta_config <- list(
  framework_version = "CSTA K-12 Computer Science Standards (Revised 2017)",
  version_date      = "2017",
  publisher         = "Computer Science Teachers Association (CSTA)",
  xlsx_filename     = "csta-k-12-standards-revised-2017.xlsx",
  sheet_name        = "CSTA Standards, Revised 2017",
  staging_dir       = here("data", "raw", "csta"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml",
  license           = "CC BY-NC-SA 4.0"
)

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

extract_csta <- function(xlsx_path) {
  read_excel(xlsx_path, sheet = csta_config$sheet_name) |>
    rename_with(\(x) str_replace_all(tolower(x), "[^a-z0-9]+", "_")) |>
    # Clean up multi-practice rows (some entries list 2-3 practices separated by ", ")
    mutate(
      identifier = str_squish(identifier),
      standard   = str_squish(standard)
    ) |>
    filter(!is.na(identifier), identifier != "")
}

#' Build the level catalog (1A, 1B, 2, 3A, 3B)
build_level_catalog <- function(standards) {
  standards |>
    distinct(level, grades) |>
    arrange(level)
}

#' Build the concept × level cluster catalog (the "role" analog for CSTA)
build_cluster_catalog <- function(standards) {
  standards |>
    distinct(level, concept) |>
    mutate(cluster_id = paste(level, str_replace_all(concept, "[^A-Za-z]+", ""), sep = "-")) |>
    arrange(level, concept)
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(xlsx_path, standards, levels, clusters) {
  manifest <- list(
    framework         = "CSTA K-12 CS",
    framework_version = csta_config$framework_version,
    version_date      = csta_config$version_date,
    source = list(
      type     = "official_xlsx",
      publisher = csta_config$publisher,
      filename  = csta_config$xlsx_filename
    ),
    retrieval = list(
      retrieved_date   = format(Sys.Date(), "%Y-%m-%d"),
      retrieved_by     = "scripts/010-ingest-csta.R",
      file_size_bytes  = file.info(xlsx_path)$size,
      file_sha256      = digest(file = xlsx_path, algo = "sha256")
    ),
    extraction = list(
      standards_count  = nrow(standards),
      levels_count     = nrow(levels),
      clusters_count   = nrow(clusters),
      concepts         = length(unique(standards$concept)),
      practices        = length(unique(standards$practice))
    ),
    licensing = list(
      source_license = csta_config$license,
      redistribution_note = paste(
        "CC BY-NC-SA 4.0: attribution + non-commercial + share-alike.",
        "Commercial toolkit release may not include CSTA text.",
        "Analytical derivatives publishable with attribution."
      )
    ),
    notes = list(
      framework_type = "pedagogical K-12 computer science standards",
      cybersec_coverage = paste(
        "Not cybersecurity-specific. Cybersec content lives in 'Impacts of",
        "Computing' and 'Networks & the Internet' concepts. Inclusion here",
        "is for cross-curricular breadth comparison against Cyber.org K-12."
      )
    )
  )

  manifest_path <- file.path(csta_config$staging_dir, csta_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== CSTA K-12 CS Standards Ingestion ===")

  xlsx_path <- file.path(csta_config$staging_dir, csta_config$xlsx_filename)
  if (!file.exists(xlsx_path)) stop("CSTA XLSX not found at ", xlsx_path)

  message("Extracting standards...")
  standards <- extract_csta(xlsx_path)
  message("  Standards: ", nrow(standards))

  message("Building level catalog...")
  levels <- build_level_catalog(standards)

  message("Building cluster catalog (level x concept)...")
  clusters <- build_cluster_catalog(standards)

  tables_dir <- file.path(csta_config$staging_dir, csta_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(standards, file.path(tables_dir, "standards.csv"))
  write_csv(levels,    file.path(tables_dir, "levels.csv"))
  write_csv(clusters,  file.path(tables_dir, "clusters.csv"))

  write_provenance_manifest(xlsx_path, standards, levels, clusters)

  message("\n=== Summary ===")
  message("  Standards: ",  nrow(standards))
  message("  Levels: ",     nrow(levels))
  message("  Clusters: ",   nrow(clusters))
  message("  Concepts: ",   length(unique(standards$concept)))
  cat("\nLevel breakdown:\n")
  print(standards |> count(level))
  cat("\nConcept breakdown:\n")
  print(standards |> count(concept))
  message("\nDone.")

  invisible(list(standards = standards, levels = levels, clusters = clusters))
}

if (sys.nframe() == 0) {
  main()
}
