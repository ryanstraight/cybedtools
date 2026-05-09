# 010-ingest-sfia.R
#
# Ingest SFIA 9 framework data from the jankudev/sfia-tools SQLite release,
# extract structural tables into tidy CSVs, and generate a provenance
# manifest for reproducibility.
#
# Source: https://github.com/jankudev/sfia-tools/releases/tag/v0.0.1
#   Asset: sfia-sqlite.db (744 KB, 2025-02-05)
#
# Licensing note: SFIA content is redistributed by jankudev under the SFIA
# Foundation's non-commercial free-use provision. Research use (derivative
# analysis, cross-framework comparison) is permissible. We do NOT redistribute
# SFIA skill-description text in downstream toolkit releases without confirming
# licensing first. Analytical outputs (frequency tables, code distributions,
# mappings) are safe to publish.
#
# Run: Rscript scripts/010-ingest-sfia.R

suppressPackageStartupMessages({
  library(here)
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(readr)
  library(yaml)
  library(glue)
})

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

sfia_config <- list(
  release_tag        = "v0.0.1",
  release_date       = "2025-02-05",
  source_repo        = "jankudev/sfia-tools",
  source_url         = "https://github.com/jankudev/sfia-tools/releases/download/v0.0.1/sfia-sqlite.db",
  sfia_version       = "SFIA 9",
  sfia_version_date  = "2024-10",
  db_filename        = "sfia-sqlite.db",
  staging_dir        = here("data", "raw", "sfia"),
  manifest_filename  = "provenance.yml"
)

# ---------------------------------------------------------------------------
# Download (idempotent)
# ---------------------------------------------------------------------------

#' Download SFIA SQLite DB if not already staged
#'
#' @return Character path to the DB file.
ensure_sfia_db_downloaded <- function() {
  db_path <- file.path(sfia_config$staging_dir, sfia_config$db_filename)

  if (!dir.exists(sfia_config$staging_dir)) {
    dir.create(sfia_config$staging_dir, recursive = TRUE)
  }

  if (!file.exists(db_path)) {
    message("Downloading SFIA SQLite DB from ", sfia_config$source_url)
    download.file(
      url      = sfia_config$source_url,
      destfile = db_path,
      mode     = "wb",
      quiet    = FALSE
    )
  } else {
    message("SFIA DB already staged at: ", db_path)
  }

  db_path
}

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

#' Extract all relevant tables from the SFIA SQLite DB
#'
#' @param db_path Character path to SQLite file.
#' @return Named list of tibbles (one per table).
extract_sfia_tables <- function(db_path) {
  conn <- dbConnect(RSQLite::SQLite(), db_path)
  on.exit(dbDisconnect(conn))

  tables_to_extract <- c(
    "Skill",
    "SkillLevel",
    "Level",
    "Attribute",
    "AttributeType",
    "AttributeLevel",
    "RelatedSkill",
    "SkillsProfile",
    "SkillsProfileFamily",
    "SkillsProfileJobTitle",
    "SkillsProfileSkill"
  )

  extracted <- tables_to_extract |>
    purrr::set_names() |>
    purrr::map(\(table_name) {
      message("  Extracting: ", table_name)
      dbReadTable(conn, table_name) |> tibble::as_tibble()
    })

  extracted
}

#' Write extracted tables as tidy CSVs
#'
#' @param tables Named list of tibbles.
#' @param output_dir Character directory path.
#' @return Named character vector of written file paths.
write_sfia_csvs <- function(tables, output_dir) {
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }

  written_paths <- tables |>
    purrr::imap_chr(\(table_data, table_name) {
      file_name <- paste0(tolower(gsub("([a-z])([A-Z])", "\\1-\\2", table_name)), ".csv")
      file_path <- file.path(output_dir, file_name)
      write_csv(table_data, file_path)
      file_path
    })

  written_paths
}

# ---------------------------------------------------------------------------
# Provenance manifest
# ---------------------------------------------------------------------------

#' Render a vector of absolute paths as repo-root-relative strings
#'
#' Used in provenance manifests so the recorded paths do not embed any
#' contributor's local checkout location.
#'
#' @param paths Character vector of file paths.
#' @return Character vector of paths relative to here::here(), forward-slashed.
relativize_to_root <- function(paths) {
  root  <- normalizePath(here::here(), winslash = "/", mustWork = FALSE)
  norm  <- normalizePath(paths,        winslash = "/", mustWork = FALSE)
  pref  <- paste0(root, "/")
  ifelse(startsWith(norm, pref), substring(norm, nchar(pref) + 1L), norm)
}

#' Compute SHA256 hash of the DB file for provenance
#'
#' @param file_path Character.
#' @return Character SHA256.
compute_sha256 <- function(file_path) {
  digest::digest(file = file_path, algo = "sha256")
}

#' Write a provenance manifest YAML
#'
#' @param db_path Character path to SQLite DB.
#' @param tables Named list of extracted tibbles.
#' @param csv_paths Named character vector of CSV output paths.
write_provenance_manifest <- function(db_path, tables, csv_paths) {
  manifest <- list(
    framework         = "SFIA",
    framework_version = sfia_config$sfia_version,
    framework_date    = sfia_config$sfia_version_date,
    source = list(
      type         = "third_party_structural_extract",
      repository   = sfia_config$source_repo,
      release_tag  = sfia_config$release_tag,
      release_date = sfia_config$release_date,
      download_url = sfia_config$source_url
    ),
    retrieval = list(
      retrieved_date = format(Sys.Date(), "%Y-%m-%d"),
      retrieved_by   = "scripts/010-ingest-sfia.R",
      db_file        = basename(db_path),
      db_size_bytes  = file.info(db_path)$size,
      db_sha256      = compute_sha256(db_path)
    ),
    extraction = list(
      table_row_counts = tables |> purrr::map_int(nrow) |> as.list(),
      output_files     = as.list(relativize_to_root(csv_paths))
    ),
    licensing = list(
      sfia_text_license = "SFIA Foundation non-commercial free-use provision",
      jankudev_license  = "See jankudev/sfia-tools repository",
      redistribution_note = paste(
        "SFIA skill-description text is redistributed by jankudev under SFIA",
        "Foundation policy. Derivative analytical outputs (code frequencies,",
        "cross-framework mappings) are safe to publish. Do NOT redistribute",
        "SFIA text in toolkit releases without confirming licensing."
      )
    )
  )

  manifest_path <- file.path(sfia_config$staging_dir, sfia_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== SFIA 9 Ingestion ===")

  db_path <- ensure_sfia_db_downloaded()

  message("Extracting tables...")
  tables <- extract_sfia_tables(db_path)

  message("Writing CSVs...")
  csv_output_dir <- file.path(sfia_config$staging_dir, "tables")
  csv_paths <- write_sfia_csvs(tables, csv_output_dir)

  message("Writing provenance manifest...")
  write_provenance_manifest(db_path, tables, csv_paths)

  message("\n=== Summary ===")
  tables |> purrr::iwalk(\(table_data, table_name) {
    message(glue("  {table_name}: {nrow(table_data)} rows"))
  })
  message("\nOutput: ", csv_output_dir)
  message("Done.")

  invisible(list(db_path = db_path, tables = tables, csv_paths = csv_paths))
}

if (sys.nframe() == 0) {
  main()
}
