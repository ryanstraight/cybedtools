# 010-ingest-dcwf.R
#
# Ingest the DoD Cyber Workforce Framework (DCWF) v5.1 from the official
# DoD CIO XLSX workbook, extract work roles and the master task/KSA list
# into tidy CSVs, and write a provenance manifest.
#
# Source: DoD CIO, DCWF Work Role Tool, v5.1 dated 2025-07-25.
#   File: data/raw/dcwf/dcwf-work-role-tool-v5.1.xlsx (supplied manually).
#
# Licensing: US Government work, public domain. Safe to redistribute
# derived analytical outputs.
#
# Run: Rscript scripts/010-ingest-dcwf.R

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

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

dcwf_config <- list(
  framework_version = "DCWF v5.1",
  version_date      = "2025-07-25",
  source_authority  = "DoD Chief Information Officer (DoD CIO)",
  source_note       = paste(
    "Manually downloaded by Ryan from DoD CIO site; public.cyber.mil DCWF",
    "pages require browser-class User-Agent. Future release of this toolkit",
    "may automate fetch with an appropriate UA."
  ),
  xlsx_filename     = "dcwf-work-role-tool-v5.1.xlsx",
  staging_dir       = here("data", "raw", "dcwf"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml"
)

# ---------------------------------------------------------------------------
# Sheet-name conventions
# ---------------------------------------------------------------------------

dcwf_admin_sheets <- c(
  "Info Sheet", "Change Log", "Master Task & KSA List",
  "DCWF Roles", "Template"
)

#' Identify per-role sheets (those with "(XX-NNN)" prefix in name)
#'
#' @param all_sheets Character vector of sheet names.
#' @return Character vector of per-role sheet names.
identify_role_sheets <- function(all_sheets) {
  role_pattern <- "^\\([A-Z]{2}-\\d{3}\\)"
  all_sheets[str_detect(all_sheets, role_pattern)]
}

#' Extract role code from sheet name (e.g., "IT-411" from "(IT-411) Tech...")
#'
#' @param sheet_name Character.
#' @return Character role code.
extract_role_code <- function(sheet_name) {
  str_extract(sheet_name, "(?<=\\()[A-Z]{2}-\\d{3}(?=\\))")
}

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

#' Extract the DCWF Roles catalog sheet
#'
#' Structure: Element | (unnamed) | Work Role | DCWF Code | NCWF ID |
#'            Work Role Definition. First data row appears a few rows down
#'            due to merged-cell header formatting; we skip likely header
#'            rows and clean.
#'
#' @param xlsx_path Character path.
#' @return Tibble with cleaned role catalog.
extract_dcwf_roles <- function(xlsx_path) {
  raw <- read_excel(
    xlsx_path,
    sheet = "DCWF Roles",
    col_names = FALSE,
    .name_repair = "unique_quiet"
  )

  header_hits <- raw |>
    mutate(row_num = row_number()) |>
    filter(if_any(everything(), \(x) str_detect(
      as.character(x), "(?i)^\\s*DCWF\\s*Code\\s*$"
    ))) |>
    pull(row_num)

  header_row <- if (length(header_hits) > 0) header_hits[1] else 2

  roles_df <- read_excel(
    xlsx_path,
    sheet = "DCWF Roles",
    skip = header_row - 1,
    .name_repair = "unique"
  )

  roles_df |>
    janitor::clean_names() |>
    filter(!is.na(dcwf_code)) |>
    select(any_of(c(
      "element", "work_role", "dcwf_code", "ncwf_id", "work_role_definition"
    )))
}

#' Extract the Master Task & KSA List sheet
#'
#' @param xlsx_path Character path.
#' @return Tibble with the master element catalog.
extract_master_task_ksa <- function(xlsx_path) {
  raw <- read_excel(
    xlsx_path,
    sheet = "Master Task & KSA List",
    col_names = FALSE,
    .name_repair = "unique_quiet"
  )

  header_hits <- raw |>
    mutate(row_num = row_number()) |>
    filter(if_any(everything(), \(x) str_detect(
      as.character(x), "(?i)^\\s*Task\\s*/\\s*KSA\\s*$"
    ))) |>
    pull(row_num)

  header_row <- if (length(header_hits) > 0) header_hits[1] else 2

  tasks_ksas <- read_excel(
    xlsx_path,
    sheet = "Master Task & KSA List",
    skip = header_row - 1,
    .name_repair = "unique"
  ) |>
    janitor::clean_names()

  tasks_ksas |>
    filter(if_any(any_of(c("dcwf_number", "dcwf_num")), \(x) !is.na(x)))
}

#' Extract per-role element associations
#'
#' Each per-role sheet has a 4-column structure. Header rows vary; actual
#' role-element mappings typically list element IDs.
#'
#' @param xlsx_path Character path.
#' @param role_sheet_name Character sheet name like "(IT-411) Tech Supp Specialist".
#' @return Tibble with role_code and raw sheet content for downstream parsing.
extract_role_sheet <- function(xlsx_path, role_sheet_name) {
  role_code <- extract_role_code(role_sheet_name)

  sheet_data <- read_excel(
    xlsx_path,
    sheet = role_sheet_name,
    col_names = FALSE,
    .name_repair = "unique_quiet"
  ) |>
    mutate(role_code = role_code, role_sheet = role_sheet_name, .before = 1)

  sheet_data
}

#' Extract all per-role sheets into a combined long tibble
#'
#' @param xlsx_path Character path.
#' @param role_sheets Character vector of sheet names.
#' @return Long tibble of all role sheets with role_code column.
extract_all_role_sheets <- function(xlsx_path, role_sheets) {
  role_sheets |>
    set_names() |>
    map(\(sheet) {
      message("  Role sheet: ", sheet)
      extract_role_sheet(xlsx_path, sheet)
    }) |>
    bind_rows()
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(xlsx_path, roles_df, master_df, role_sheets) {
  manifest <- list(
    framework         = "DCWF",
    framework_version = dcwf_config$framework_version,
    framework_date    = dcwf_config$version_date,
    source = list(
      type              = "official_xlsx_workbook",
      authority         = dcwf_config$source_authority,
      source_filename   = dcwf_config$xlsx_filename,
      acquisition_note  = dcwf_config$source_note
    ),
    retrieval = list(
      retrieved_date = format(Sys.Date(), "%Y-%m-%d"),
      retrieved_by   = "scripts/010-ingest-dcwf.R",
      file_size_bytes = file.info(xlsx_path)$size,
      file_sha256    = digest(file = xlsx_path, algo = "sha256")
    ),
    extraction = list(
      roles_count             = nrow(roles_df),
      master_task_ksa_count   = nrow(master_df),
      per_role_sheet_count    = length(role_sheets)
    ),
    licensing = list(
      source_license = "US Government work, public domain",
      redistribution = "Safe to redistribute DCWF text and derivative analysis"
    )
  )

  manifest_path <- file.path(dcwf_config$staging_dir, dcwf_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== DCWF v5.1 Ingestion ===")

  xlsx_path <- file.path(dcwf_config$staging_dir, dcwf_config$xlsx_filename)
  if (!file.exists(xlsx_path)) {
    stop("DCWF XLSX not found at ", xlsx_path,
         ". Manual download required (see dcwf_config$source_note).")
  }

  if (!requireNamespace("janitor", quietly = TRUE)) {
    stop("Package 'janitor' is required for DCWF ingestion (used for ",
         "clean_names() on the XLSX sheets). Install with: ",
         'install.packages("janitor")')
  }

  message("Reading sheet index...")
  all_sheets <- excel_sheets(xlsx_path)
  role_sheets <- identify_role_sheets(all_sheets)
  message("  Total sheets: ", length(all_sheets))
  message("  Per-role sheets: ", length(role_sheets))

  message("Extracting DCWF Roles catalog...")
  roles_df <- extract_dcwf_roles(xlsx_path)
  message("  Roles: ", nrow(roles_df))

  message("Extracting Master Task & KSA List...")
  master_df <- extract_master_task_ksa(xlsx_path)
  message("  Master elements: ", nrow(master_df))

  message("Extracting per-role sheet content...")
  role_content <- extract_all_role_sheets(xlsx_path, role_sheets)
  message("  Total rows across role sheets: ", nrow(role_content))

  tables_dir <- file.path(dcwf_config$staging_dir, dcwf_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(roles_df,     file.path(tables_dir, "dcwf-roles.csv"))
  write_csv(master_df,    file.path(tables_dir, "master-task-ksa.csv"))
  write_csv(role_content, file.path(tables_dir, "per-role-content-long.csv"))

  message("Writing provenance manifest...")
  write_provenance_manifest(xlsx_path, roles_df, master_df, role_sheets)

  message("\n=== Summary ===")
  message("  DCWF Roles: ",        nrow(roles_df))
  message("  Master Task/KSA: ",   nrow(master_df))
  message("  Per-role sheets: ",   length(role_sheets))
  message("  Per-role rows: ",     nrow(role_content))
  message("\nOutput: ", tables_dir)
  message("Done.")

  invisible(list(
    xlsx_path    = xlsx_path,
    roles_df     = roles_df,
    master_df    = master_df,
    role_content = role_content
  ))
}

if (sys.nframe() == 0) {
  main()
}
