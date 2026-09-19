# 010-ingest-nice.R
#
# Ingest the NICE Framework (NIST SP 800-181 Rev 1, Components v2.2.0)
# from the NIST Cybersecurity and Privacy Reference Tool (CPRT) JSON
# distribution.
#
# Source:
#   - v2-2-0_nf_components.json (NIST CPRT export, staged in
#     data/raw/nice/v2.2.0/).
#   - Publisher: National Institute of Standards and Technology (NIST).
#   - Authority: NIST SP 800-181 Rev 1 (Components v2.2.0, released
#     2026-04-28).
#
# Licensing: US public domain (17 U.S.C. 105); foreign rights may be
# reserved; attribute NIST as source.
#
# v2.2.0 additions beyond the v2.0.0-era ingest:
#   - Competency areas carry knowledge/skill membership relationships,
#     staged as competency-area-ks-associations.csv.
#   - opm_code elements (new element type; Federal-use OPM occupational
#     series codes) and work_role -> opm_code relationships, staged as
#     opm-codes.csv / role-opm-codes.csv. The opm_code elements carry no
#     title/text payload; the code itself is the identifier.
#   - 'sort' elements (display ordering) are ignored, as before.
#
# Errata: the v2.2.0 source carries a wrong description for the
# Investigation (IN) category (foreign-intelligence text, an upstream
# NIST regression). This script deterministically applies the correction
# declared in the errata table below, and writes the machine-readable
# record to data/raw/nice/errata.csv. If NIST fixes the source upstream,
# the published_value match check fails loudly so the stale erratum is
# reviewed rather than silently reapplied.
#
# Run: Rscript scripts/010-ingest-nice.R

suppressPackageStartupMessages({
  library(here)
  library(jsonlite)
  library(dplyr)
  library(readr)
  library(yaml)
  library(glue)
  library(purrr)
  library(tibble)
  library(stringr)
  library(digest)
})

source(here("scripts", "_ingest-common.R"), local = TRUE)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

nice_config <- list(
  framework_version = "NICE v2.2.0 (NIST SP 800-181 Rev 1 components)",
  version_source    = "NIST CPRT v2.2.0 export",
  version_date      = "2026-04-28",
  publisher         = "NIST (National Institute of Standards and Technology)",
  json_subpath      = file.path("v2.2.0", "v2-2-0_nf_components.json"),
  staging_dir       = here("data", "raw", "nice"),
  tables_subdir     = "tables",
  errata_filename   = "errata.csv",
  manifest_filename = "provenance.yml"
)

# Element types in the NIST CPRT JSON
nice_element_types <- list(
  work_role       = "work_role",
  task            = "task",
  knowledge       = "knowledge",
  skill           = "skill",
  category        = "category",
  competency_area = "competency_area",
  opm_code        = "opm_code"
)

# ---------------------------------------------------------------------------
# Errata (upstream source defects corrected at ingest)
# ---------------------------------------------------------------------------
#
# Single source of truth for source-data corrections. Each row must match
# the published value exactly (after str_squish) or ingestion stops: a
# mismatch means NIST revised the source and the erratum needs review.
# The table is also written to data/raw/nice/errata.csv so the corrections
# are machine-readable alongside the staged data.

nice_errata <- tibble::tribble(
  ~element_id, ~field, ~published_value, ~corrected_value, ~rationale, ~source,
  "IN", "text",
  "Collects, processes, analyzes, and disseminates information from all sources of intelligence on foreign actors' cyberspace programs, intentions, capabilities, research and development, and operational activities",
  "Conducts national cybersecurity and cybercrime investigations, including the collection, management, and analysis of digital evidence.",
  "The v2.2.0 CPRT export carries foreign-intelligence collection text in place of the Investigation category description -- an upstream NIST regression. The correct description is restored from the v2.0.0 release.",
  "NICE v2.0.0 CPRT export (archived at data/raw/nice/v2.0.0/tables/categories.csv)"
)

#' Apply errata rows to an extracted element table
#'
#' Matches on element_id + field; requires the current value to equal the
#' declared published_value (hard stop otherwise). Rows whose element_id is
#' not present in the table are ignored (they target a different table).
apply_errata <- function(tbl, errata, table_label) {
  applicable <- errata |>
    filter(element_id %in% tbl$element_id, field %in% names(tbl))
  if (nrow(applicable) == 0) return(tbl)

  for (i in seq_len(nrow(applicable))) {
    row <- applicable[i, ]
    idx <- which(tbl$element_id == row$element_id)
    current <- tbl[[row$field]][idx]
    if (!identical(current, row$published_value)) {
      stop(glue(
        "Erratum mismatch in {table_label}: {row$element_id}${row$field} ",
        "does not equal the declared published_value. The upstream source ",
        "may have been revised; review data/raw/nice/errata.csv."
      ))
    }
    tbl[[row$field]][idx] <- row$corrected_value
    message(glue("  Erratum applied: {table_label} {row$element_id}${row$field}"))
  }
  tbl
}

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

`%||%` <- function(a, b) if (is.null(a)) b else a

#' Load the NIST CPRT JSON export
load_nice_cprt <- function(json_path) {
  fromJSON(json_path, simplifyVector = FALSE)
}

#' Extract elements of a specific type into a tibble
extract_elements_of_type <- function(cprt, element_type) {
  matched <- cprt$elements |>
    keep(\(e) identical(e$element_type, element_type))

  # map_dfr() over an empty list returns a 0-row, 0-COLUMN tibble, which
  # loses the schema and breaks downstream bind_rows()/select() calls.
  # A zero-match type must return 0 rows with all 5 columns intact.
  if (length(matched) == 0) {
    return(tibble(
      element_id   = character(0),
      element_type = character(0),
      title        = character(0),
      text         = character(0),
      doc_id       = character(0)
    ))
  }

  matched |>
    map_dfr(\(e) tibble(
      element_id   = e$element_identifier %||% NA_character_,
      element_type = e$element_type       %||% NA_character_,
      title        = e$title               %||% NA_character_,
      text         = e$text                %||% NA_character_,
      doc_id       = e$doc_identifier      %||% NA_character_
    )) |>
    mutate(across(where(is.character), \(x) str_squish(x)))
}

#' Flatten the CPRT relationship list into a tibble
extract_relationships <- function(cprt) {
  cprt$relationships |>
    map_dfr(\(r) tibble(
      source_id = r$source_element_identifier %||% NA_character_,
      dest_id   = r$dest_element_identifier   %||% NA_character_,
      rel_id    = r$relationship_identifier   %||% NA_character_
    ))
}

#' Build the work-role -> TKS association table
#'
#' NICE CPRT uses `projection` relationships. A work_role is the source,
#' a task/knowledge/skill is the destination.
build_role_tks_associations <- function(relationships, work_roles, tks_elements) {
  relationships |>
    filter(source_id %in% work_roles$element_id,
           dest_id %in% tks_elements$element_id) |>
    left_join(
      tks_elements |> select(element_id, element_type, text),
      by = c("dest_id" = "element_id")
    ) |>
    left_join(
      work_roles |> select(element_id, title),
      by = c("source_id" = "element_id")
    ) |>
    transmute(
      work_role_id    = source_id,
      work_role_title = title,
      statement_id    = dest_id,
      statement_type  = element_type,
      statement_text  = text
    ) |>
    arrange(work_role_id, statement_type, statement_id)
}

#' Build the work-role -> category mapping (category is the source)
build_role_categories <- function(relationships, work_roles, categories) {
  relationships |>
    filter(source_id %in% categories$element_id,
           dest_id %in% work_roles$element_id) |>
    transmute(
      work_role_id = dest_id,
      category_id  = source_id
    )
}

#' Build the competency-area -> knowledge/skill membership table (v2.2.0)
build_comp_area_ks_associations <- function(relationships, comp_areas, tks_elements) {
  relationships |>
    filter(source_id %in% comp_areas$element_id,
           dest_id %in% tks_elements$element_id) |>
    left_join(
      tks_elements |> select(element_id, element_type, text),
      by = c("dest_id" = "element_id")
    ) |>
    left_join(
      comp_areas |> select(element_id, title),
      by = c("source_id" = "element_id")
    ) |>
    transmute(
      competency_area_id    = source_id,
      competency_area_title = title,
      statement_id          = dest_id,
      statement_type        = element_type,
      statement_text        = text
    ) |>
    arrange(competency_area_id, statement_type, statement_id)
}

#' Build the work_role -> opm_code mapping (v2.2.0, Federal use)
build_role_opm_codes <- function(relationships, work_roles, opm_codes) {
  relationships |>
    filter(source_id %in% work_roles$element_id,
           dest_id %in% opm_codes$element_id) |>
    transmute(
      work_role_id = source_id,
      opm_code     = dest_id
    ) |>
    arrange(work_role_id)
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(json_path,
                                      work_roles_df,
                                      tasks_df,
                                      knowledge_df,
                                      skills_df,
                                      categories_df,
                                      comp_areas_df,
                                      opm_codes_df,
                                      associations_df,
                                      comp_area_ks_df,
                                      role_opm_df) {
  manifest_path <- file.path(nice_config$staging_dir, nice_config$manifest_filename)
  file_sha256 <- digest(file = json_path, algo = "sha256")
  retrieved_date <- resolve_retrieved_date(manifest_path,
                                           c(file_sha256 = file_sha256))

  manifest <- list(
    framework         = "NICE",
    framework_version = nice_config$framework_version,
    framework_date    = nice_config$version_date,
    source = list(
      type      = "official_cprt_json",
      authority = "NIST SP 800-181 Rev 1 (Components v2.2.0, released 2026-04-28)",
      publisher = nice_config$publisher,
      filename  = "v2.2.0/v2-2-0_nf_components.json",
      url       = "https://csrc.nist.gov/csrc/media/Projects/cprt/documents/nice/v2-2-0_nf_components.json"
    ),
    retrieval = list(
      retrieved_date  = retrieved_date,
      retrieved_by    = "scripts/010-ingest-nice.R",
      file_size_bytes = file.info(json_path)$size,
      file_sha256     = file_sha256,
      acquisition_note = paste(
        "Download the canonical NICE Framework Components v2.2.0 CPRT JSON",
        "from the NIST NICE Framework Resource Center Current Version page",
        "and stage it at data/raw/nice/v2.2.0/v2-2-0_nf_components.json",
        "before running this script. Note the doc_identifier changed from",
        "SP_800_181_rev_1 (v2.0.0 export) to SP_800_181_2_2_0."
      )
    ),
    extraction = list(
      work_roles_count       = nrow(work_roles_df),
      tasks_count            = nrow(tasks_df),
      knowledge_count        = nrow(knowledge_df),
      skills_count           = nrow(skills_df),
      categories_count       = nrow(categories_df),
      competency_areas_count = nrow(comp_areas_df),
      opm_codes_count        = nrow(opm_codes_df),
      unique_tks_count       = nrow(tasks_df) + nrow(knowledge_df) + nrow(skills_df),
      tks_associations_count = nrow(associations_df),
      competency_area_ks_associations_count = nrow(comp_area_ks_df),
      role_opm_mappings_count = nrow(role_opm_df)
    ),
    anomalies = list(
      s0768_orphan = paste(
        "S0768 appears in the v2.2.0 JSON (and CSV) skill catalog with zero",
        "work-role memberships but is absent from NIST's companion XLSX --",
        "a contradiction internal to NIST's own release. Retained per the",
        "package's orphan-retention policy, so the skills count is 556, one",
        "higher than the XLSX's 555."
      )
    ),
    errata = list(
      file          = "errata.csv",
      applied_count = nrow(nice_errata),
      note = paste(
        "Source-data corrections applied deterministically at ingest;",
        "see errata.csv for element ids, published vs corrected values,",
        "and rationale."
      )
    ),
    licensing = list(
      source_license = paste(
        "US public domain (17 U.S.C. 105); foreign rights reserved but granted",
        "royalty-free worldwide, incl. derivative works; attribute NIST as source"
      ),
      redistribution = paste(
        "NICE text is a US Government work in the US public domain",
        "(17 U.S.C. 105). NIST reserves foreign rights and then grants them",
        "back: 'foreign rights are reserved. To the extent NIST may assert",
        "rights outside of the United States, the public is granted the",
        "non-exclusive, perpetual, paid-up, royalty-free, worldwide right to",
        "reprint works in all formats including print, electronically, and",
        "online, and in all subsequent editions, and derivative works.'",
        "Attribute NIST as the source and do not imply NIST endorsement."
      )
    )
  )

  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== NICE v2.2.0 Ingestion ===")

  json_path <- file.path(nice_config$staging_dir, nice_config$json_subpath)
  if (!file.exists(json_path)) {
    stop("NICE v2.2.0 JSON not found at ", json_path)
  }

  message("Loading NIST CPRT JSON...")
  cprt <- load_nice_cprt(json_path)
  message("  Elements: ", length(cprt$elements))
  message("  Relationships: ", length(cprt$relationships))

  message("Extracting work roles...")
  work_roles_df <- extract_elements_of_type(cprt, "work_role")
  message("  Work roles: ", nrow(work_roles_df))

  message("Extracting TKS elements...")
  tasks_df     <- extract_elements_of_type(cprt, "task")
  knowledge_df <- extract_elements_of_type(cprt, "knowledge")
  skills_df    <- extract_elements_of_type(cprt, "skill")
  message(glue("  Tasks: {nrow(tasks_df)}, Knowledge: {nrow(knowledge_df)}, Skills: {nrow(skills_df)}"))

  message("Extracting categories...")
  categories_df <- extract_elements_of_type(cprt, "category")

  message("Extracting competency areas...")
  comp_areas_df <- extract_elements_of_type(cprt, "competency_area")

  message("Extracting OPM codes...")
  opm_codes_df <- extract_elements_of_type(cprt, "opm_code")

  message("Applying errata...")
  errata_path <- file.path(nice_config$staging_dir, nice_config$errata_filename)
  write_csv(nice_errata, errata_path)
  message("  Errata table written: ", errata_path)
  work_roles_df <- apply_errata(work_roles_df, nice_errata, "work-roles")
  tasks_df      <- apply_errata(tasks_df,      nice_errata, "tasks")
  knowledge_df  <- apply_errata(knowledge_df,  nice_errata, "knowledge")
  skills_df     <- apply_errata(skills_df,     nice_errata, "skills")
  categories_df <- apply_errata(categories_df, nice_errata, "categories")
  comp_areas_df <- apply_errata(comp_areas_df, nice_errata, "competency-areas")

  message("Building relationships...")
  relationships <- extract_relationships(cprt)

  message("Building role -> TKS associations...")
  tks_elements <- bind_rows(tasks_df, knowledge_df, skills_df)
  associations_df <- build_role_tks_associations(relationships, work_roles_df, tks_elements)
  message("  Associations: ", nrow(associations_df))

  message("Building role -> category mapping...")
  role_categories_df <- build_role_categories(relationships, work_roles_df, categories_df)

  message("Building competency area -> K/S associations...")
  comp_area_ks_df <- build_comp_area_ks_associations(relationships, comp_areas_df, tks_elements)
  message("  CA-KS associations: ", nrow(comp_area_ks_df))

  message("Building role -> OPM code mapping...")
  role_opm_df <- build_role_opm_codes(relationships, work_roles_df, opm_codes_df)
  message("  Role-OPM mappings: ", nrow(role_opm_df))

  tables_dir <- file.path(nice_config$staging_dir, nice_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(work_roles_df,      file.path(tables_dir, "work-roles.csv"))
  write_csv(tasks_df,           file.path(tables_dir, "tasks.csv"))
  write_csv(knowledge_df,       file.path(tables_dir, "knowledge.csv"))
  write_csv(skills_df,          file.path(tables_dir, "skills.csv"))
  write_csv(categories_df,      file.path(tables_dir, "categories.csv"))
  write_csv(comp_areas_df,      file.path(tables_dir, "competency-areas.csv"))
  write_csv(associations_df,    file.path(tables_dir, "role-tks-associations.csv"))
  write_csv(role_categories_df, file.path(tables_dir, "role-categories.csv"))
  # v2.2.0-additive tables
  write_csv(comp_area_ks_df,    file.path(tables_dir, "competency-area-ks-associations.csv"))
  write_csv(opm_codes_df,       file.path(tables_dir, "opm-codes.csv"))
  write_csv(role_opm_df,        file.path(tables_dir, "role-opm-codes.csv"))

  message("Writing provenance manifest...")
  write_provenance_manifest(
    json_path, work_roles_df, tasks_df, knowledge_df, skills_df,
    categories_df, comp_areas_df, opm_codes_df,
    associations_df, comp_area_ks_df, role_opm_df
  )

  message("\n=== Summary ===")
  message("  Work roles: ",            nrow(work_roles_df))
  message("  Tasks: ",                 nrow(tasks_df))
  message("  Knowledge statements: ",  nrow(knowledge_df))
  message("  Skill statements: ",      nrow(skills_df))
  message("  Categories: ",            nrow(categories_df))
  message("  Competency areas: ",      nrow(comp_areas_df))
  message("  OPM codes: ",             nrow(opm_codes_df))
  message("  Unique TKS total: ",      nrow(tasks_df) + nrow(knowledge_df) + nrow(skills_df))
  message("  Role-TKS associations: ", nrow(associations_df))
  message("  CompArea-KS associations: ", nrow(comp_area_ks_df))
  message("  Role-OPM mappings: ",     nrow(role_opm_df))
  message("\nOutput: ", tables_dir)
  message("Done.")

  invisible(list(
    work_roles      = work_roles_df,
    tasks           = tasks_df,
    knowledge       = knowledge_df,
    skills          = skills_df,
    categories      = categories_df,
    comp_areas      = comp_areas_df,
    opm_codes       = opm_codes_df,
    associations    = associations_df,
    role_categories = role_categories_df,
    comp_area_ks    = comp_area_ks_df,
    role_opm        = role_opm_df
  ))
}

if (sys.nframe() == 0) {
  main()
}
