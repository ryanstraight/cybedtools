# 010-ingest-cyqual.R
#
# Ingest CyQUAL, the Czech national cybersecurity qualifications framework,
# from the official open-data JSON export. Flatten seven entity arrays and
# two association arrays into tidy CSVs for downstream JSON-LD assembly.
#
# Source:
#   - cyqual_open_data_en_1.2.0.json or cyqual_open_data_cs_1.2.0.json
#     (open-data export, staged in data/raw/cyqual/). The English export is
#     preferred when present; otherwise the Czech one is used.
#   - Publisher: CyQUAL / Masaryk University.
#   - Landing page: https://platform.cyqual.cz/
#   - Data version 1.2.0, retrieved 2026-09-16.
#
# Language: whichever export was ingested determines the language of the
# staged text, and provenance.yml records it. No translation or
# transliteration happens here; the CSVs carry the source strings verbatim,
# UTF-8 encoded, diacritics intact.
#
# Structure observed in the source (no fields are inferred or invented):
#   categories          code, title, description
#   competencyGroups    code, title, description
#   competencies        code, title, description, competencyGroup -> CG code
#   specializationAreas code, title, description, category -> WRC code
#   workRoles           code, title, description, specializationArea -> SA code
#   tasks               code, description
#   requirements        code, description, competency -> COM code
#   workRoleTasks       workRole, task                (join table, no payload)
#   workRoleRequirements workRole, requirement        (join table, no payload)
#
# So the hierarchy is category -> specialization area -> work role, with
# tasks and requirements attached to work roles through the two join tables,
# and requirements additionally classified by competency -> competency group.
# Neither join table carries a proficiency level, weight, importance, or
# mandatory flag; every association is an unqualified membership edge.
#
# Licensing: published as open data by CyQUAL (Masaryk University). A derived
# RDF/JSON-LD graph is permitted by written confirmation from the CyQUAL team,
# 2026-09-16. Attribution to CyQUAL and to Masaryk University is required.
#
# Run: Rscript scripts/010-ingest-cyqual.R

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

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Candidate exports in preference order. The English export carries the same
# schema and the same codes as the Czech one, so it is preferred when staged:
# downstream elementText is then English. Both exports have a recorded expected
# hash; a candidate with expected_sha256 = NA would be ingested with its
# computed hash recorded and an explicit unverified warning.
cyqual_config <- list(
  framework_version = "1.2.0",
  publisher         = "CyQUAL / Masaryk University",
  landing_url       = "https://platform.cyqual.cz/",
  source_candidates = list(
    list(
      language        = "en",
      filename        = "cyqual_open_data_en_1.2.0.json",
      expected_sha256 = "a8c1c64f574264181fb69a35dbb954648784cfedc4d5a117af9178f189741c41"
    ),
    list(
      language        = "cs",
      filename        = "cyqual_open_data_cs_1.2.0.json",
      expected_sha256 = "44733013e5fb255694dbf52f00da20055d555f999608a77f12e5616ca72e4148"
    )
  ),
  retrieved_date    = "2026-09-16",
  staging_dir       = here("data", "raw", "cyqual"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml"
)

# Expected top-level counts, from the published open-data export. A mismatch
# means the staged file is not the 1.2.0 export this script was written for.
cyqual_expected_counts <- c(
  categories           = 7,
  competencyGroups     = 4,
  competencies         = 59,
  specializationAreas  = 37,
  workRoles            = 102,
  tasks                = 1168,
  requirements         = 1320,
  workRoleTasks        = 1889,
  workRoleRequirements = 8838
)

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

#' Pick the staged export to ingest
#'
#' Walks the candidates in preference order and returns the first one present
#' on disk, so an English export supersedes the Czech one as soon as it is
#' staged without any edit here.
#'
#' @return List with path, filename, language, expected_sha256.
select_source_file <- function() {
  for (candidate in cyqual_config$source_candidates) {
    path <- file.path(cyqual_config$staging_dir, candidate$filename)
    if (file.exists(path)) {
      return(c(candidate, list(path = path)))
    }
  }
  stop(glue(
    "No CyQUAL open-data JSON staged in {cyqual_config$staging_dir}. ",
    "Expected one of: ",
    paste(map_chr(cyqual_config$source_candidates, "filename"), collapse = ", "), "."
  ))
}

#' Hash the staged file, verifying it when an expected digest is recorded
#'
#' A candidate with no recorded expected hash cannot be verified; its computed
#' hash is recorded in provenance and the caller is warned loudly rather than
#' the file being silently treated as trusted.
#'
#' @param json_path Character path to the staged JSON.
#' @param expected Character lowercase hex digest, or NA when none is known.
#' @return List with sha256 and verified (logical).
hash_source_file <- function(json_path, expected) {
  observed <- digest(file = json_path, algo = "sha256")
  if (is.na(expected)) {
    message("  !! UNVERIFIED: no expected SHA-256 is recorded for ",
            basename(json_path), ". Computed ", observed,
            ". Record it in cyqual_config$source_candidates once confirmed.")
    return(list(sha256 = observed, verified = FALSE))
  }
  if (!identical(tolower(observed), tolower(expected))) {
    stop(glue(
      "SHA-256 mismatch for {basename(json_path)}. ",
      "Expected {expected}, observed {observed}. ",
      "The staged file is not the export this script was written against."
    ))
  }
  message("  SHA-256 verified: ", observed)
  list(sha256 = observed, verified = TRUE)
}

#' Convert a top-level JSON array into a tibble
#'
#' Reads only the named fields, in the given order, so an unexpected extra
#' field in a future export is caught by check_source_fields() rather than
#' silently reshaping the output.
#'
#' @param records List of records from the parsed JSON.
#' @param fields Character vector of field names to extract.
#' @return Tibble with one row per record and one column per field.
records_to_tibble <- function(records, fields) {
  records |>
    map_dfr(\(record) {
      fields |>
        set_names() |>
        map(\(field) as.character(record[[field]] %||% NA_character_)) |>
        as_tibble()
    })
}

#' Confirm an array's field names are exactly what this script expects
#'
#' @param records List of records.
#' @param fields Character vector of expected field names.
#' @param label Character array name, for the error message.
check_source_fields <- function(records, fields, label) {
  observed <- unique(unlist(lapply(records, names)))
  missing <- setdiff(fields, observed)
  extra   <- setdiff(observed, fields)
  if (length(missing) > 0 || length(extra) > 0) {
    stop(glue(
      "Unexpected schema in `{label}`. ",
      "Missing: {paste(missing, collapse = ', ') %||% 'none'}. ",
      "Unexpected: {paste(extra, collapse = ', ')}. ",
      "Review the export before ingesting."
    ))
  }
  invisible(TRUE)
}

#' Confirm top-level array lengths match the published counts
#'
#' @param cyqual Parsed JSON list.
#' @param expected Named integer vector.
check_counts <- function(cyqual, expected) {
  for (key in names(expected)) {
    observed <- length(cyqual[[key]])
    if (!identical(as.integer(observed), as.integer(expected[[key]]))) {
      stop(glue("Count mismatch for `{key}`: expected {expected[[key]]}, observed {observed}."))
    }
  }
  message("  Top-level counts match the published export.")
  invisible(TRUE)
}

#' Stop if a code column contains duplicates
#'
#' @param tbl Tibble.
#' @param column Character column name holding the source code.
#' @param label Character table name, for the message.
check_unique_codes <- function(tbl, column, label) {
  dupes <- tbl[[column]][duplicated(tbl[[column]])]
  if (length(dupes) > 0) {
    stop(glue("Duplicate codes in {label}: {paste(unique(dupes), collapse = ', ')}."))
  }
  message(glue("  {label}: {nrow(tbl)} rows, codes unique."))
  invisible(TRUE)
}

#' Stop if a foreign key column has values absent from the parent codes
#'
#' @param child Tibble holding the foreign key.
#' @param fk Character foreign-key column name.
#' @param parent_codes Character vector of valid parent codes.
#' @param label Character description of the relationship.
check_foreign_key <- function(child, fk, parent_codes, label) {
  orphans <- setdiff(unique(child[[fk]]), parent_codes)
  if (length(orphans) > 0) {
    stop(glue("Unresolved foreign keys in {label}: {paste(orphans, collapse = ', ')}."))
  }
  message(glue("  {label}: all {nrow(child)} references resolve."))
  invisible(TRUE)
}

#' Read a written CSV back and confirm Czech diacritics survived the round trip
#'
#' Picks the first source string containing a Czech diacritic and compares it
#' byte for byte against the same cell read back from disk.
#'
#' @param csv_path Character path to the written CSV.
#' @param tbl Tibble as written.
#' @param column Character column to compare.
verify_diacritic_round_trip <- function(csv_path, tbl, column) {
  diacritic_pattern <- "[áčďéěíňóřšťúůýž]"
  idx <- which(str_detect(tbl[[column]], diacritic_pattern))[1]
  if (is.na(idx)) {
    stop(glue("No diacritic-bearing string found in {basename(csv_path)}${column}; cannot verify encoding."))
  }
  back <- read_csv(csv_path, show_col_types = FALSE,
                   locale = locale(encoding = "UTF-8"))
  source_value <- tbl[[column]][idx]
  round_value  <- back[[column]][idx]
  if (!identical(source_value, round_value)) {
    stop(glue(
      "Diacritic round trip failed in {basename(csv_path)} row {idx}. ",
      "Source: '{source_value}'. Read back: '{round_value}'."
    ))
  }
  message(glue("  Diacritics verified in {basename(csv_path)} row {idx}: {round_value}"))
  invisible(TRUE)
}

#' Report the min, median, and max association count per work role
#'
#' Roles with no associations are counted explicitly, since a left join style
#' tally would otherwise hide them.
#'
#' @param assoc Tibble association table.
#' @param fk Character work-role column name.
#' @param work_role_codes Character vector of every work-role code.
#' @param label Character description for the message.
report_per_role_distribution <- function(assoc, fk, work_role_codes, label) {
  tally <- tibble(work_role = work_role_codes) |>
    left_join(assoc |> count(.data[[fk]], name = "n"),
              by = c("work_role" = fk)) |>
    mutate(n = coalesce(n, 0L))
  zero <- tally |> filter(n == 0)
  message(glue(
    "  {label} per work role: min {min(tally$n)}, ",
    "median {median(tally$n)}, max {max(tally$n)}, ",
    "roles with zero: {nrow(zero)}",
    if (nrow(zero) > 0) glue(" ({paste(zero$work_role, collapse = ', ')})") else ""
  ))
  invisible(tally)
}

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

#' Load the CyQUAL open-data JSON
#'
#' @param json_path Character.
#' @return List with nine top-level arrays.
load_cyqual_json <- function(json_path) {
  fromJSON(json_path, simplifyVector = FALSE)
}

#' Build every entity and association table from the parsed export
#'
#' Field lists mirror the source exactly; source codes are the identifiers and
#' nothing is added, derived, or renamed.
#'
#' @param cyqual Parsed JSON list.
#' @return Named list of tibbles.
build_cyqual_tables <- function(cyqual) {
  schema <- list(
    categories           = c("code", "title", "description"),
    competencyGroups     = c("code", "title", "description"),
    competencies         = c("code", "title", "description", "competencyGroup"),
    specializationAreas  = c("code", "title", "description", "category"),
    workRoles            = c("code", "title", "description", "specializationArea"),
    tasks                = c("code", "description"),
    requirements         = c("code", "description", "competency"),
    workRoleTasks        = c("workRole", "task"),
    workRoleRequirements = c("workRole", "requirement")
  )

  schema |>
    imap(\(fields, key) {
      check_source_fields(cyqual[[key]], fields, key)
      records_to_tibble(cyqual[[key]], fields)
    })
}

# ---------------------------------------------------------------------------
# Integrity
# ---------------------------------------------------------------------------

#' Run every referential integrity check over the built tables
#'
#' Stops on the first violation.
#'
#' @param tables Named list of tibbles from build_cyqual_tables().
check_integrity <- function(tables) {
  message("Checking uniqueness of source codes...")
  check_unique_codes(tables$categories,          "code", "categories")
  check_unique_codes(tables$competencyGroups,    "code", "competency-groups")
  check_unique_codes(tables$competencies,        "code", "competencies")
  check_unique_codes(tables$specializationAreas, "code", "specialization-areas")
  check_unique_codes(tables$workRoles,           "code", "work-roles")
  check_unique_codes(tables$tasks,               "code", "tasks")
  check_unique_codes(tables$requirements,        "code", "requirements")

  message("Checking entity foreign keys...")
  check_foreign_key(tables$competencies, "competencyGroup",
                    tables$competencyGroups$code, "competency -> competency group")
  check_foreign_key(tables$specializationAreas, "category",
                    tables$categories$code, "specialization area -> category")
  check_foreign_key(tables$workRoles, "specializationArea",
                    tables$specializationAreas$code, "work role -> specialization area")
  check_foreign_key(tables$requirements, "competency",
                    tables$competencies$code, "requirement -> competency")

  message("Checking association foreign keys...")
  check_foreign_key(tables$workRoleTasks, "workRole",
                    tables$workRoles$code, "work-role-task -> work role")
  check_foreign_key(tables$workRoleTasks, "task",
                    tables$tasks$code, "work-role-task -> task")
  check_foreign_key(tables$workRoleRequirements, "workRole",
                    tables$workRoles$code, "work-role-requirement -> work role")
  check_foreign_key(tables$workRoleRequirements, "requirement",
                    tables$requirements$code, "work-role-requirement -> requirement")

  message("Checking association tables for duplicate edges...")
  for (item in list(
    list(tbl = tables$workRoleTasks,        label = "work-role-tasks"),
    list(tbl = tables$workRoleRequirements, label = "work-role-requirements")
  )) {
    n_dupe <- sum(duplicated(item$tbl))
    if (n_dupe > 0) {
      stop(glue("{n_dupe} duplicate edges in {item$label}."))
    }
    message(glue("  {item$label}: {nrow(item$tbl)} edges, no duplicates."))
  }

  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

#' Describe the staged exports that were not ingested
#'
#' Both language editions are code-for-code identical, so the one not chosen is
#' still a usable source and is recorded rather than left invisible.
#'
#' @param source The selected candidate, from select_source_file().
#' @return List of per-file descriptions, possibly empty.
describe_other_staged_sources <- function(source) {
  cyqual_config$source_candidates |>
    keep(\(candidate) !identical(candidate$filename, source$filename)) |>
    map(\(candidate) {
      path <- file.path(cyqual_config$staging_dir, candidate$filename)
      if (!file.exists(path)) return(NULL)
      observed <- digest(file = path, algo = "sha256")
      list(
        language        = candidate$language,
        filename        = candidate$filename,
        file_size_bytes = file.info(path)$size,
        file_sha256     = observed,
        sha256_verified = !is.na(candidate$expected_sha256) &&
                          identical(tolower(observed),
                                    tolower(candidate$expected_sha256)),
        ingested        = FALSE
      )
    }) |>
    compact()
}

write_provenance_manifest <- function(source, tables, hash, other_sources = list()) {
  manifest <- list(
    framework         = "CyQUAL",
    framework_version = cyqual_config$framework_version,
    language          = source$language,
    source = list(
      type      = "official_json_open_data_export",
      publisher = cyqual_config$publisher,
      filename  = source$filename,
      url       = cyqual_config$landing_url
    ),
    retrieval = list(
      retrieved_date  = cyqual_config$retrieved_date,
      retrieved_by    = "scripts/010-ingest-cyqual.R",
      file_size_bytes = file.info(source$path)$size,
      file_sha256     = hash$sha256,
      sha256_verified = hash$verified
    ),
    # The other language edition, staged but not ingested. Same codes and the
    # same nine arrays; only the text differs.
    other_staged_sources = other_sources,
    extraction = list(
      categories_count            = nrow(tables$categories),
      competency_groups_count     = nrow(tables$competencyGroups),
      competencies_count          = nrow(tables$competencies),
      specialization_areas_count  = nrow(tables$specializationAreas),
      work_roles_count            = nrow(tables$workRoles),
      tasks_count                 = nrow(tables$tasks),
      requirements_count          = nrow(tables$requirements),
      work_role_task_edges        = nrow(tables$workRoleTasks),
      work_role_requirement_edges = nrow(tables$workRoleRequirements)
    ),
    licensing = list(
      source_license = paste(
        "Published as open data by CyQUAL (Masaryk University).",
        "Derived RDF/JSON-LD graph permitted by written confirmation from",
        "the CyQUAL team, 2026-09-16. Attribution to CyQUAL and to Masaryk",
        "University required."
      ),
      redistribution = paste(
        "Source text and derived graph may be redistributed with attribution",
        "to CyQUAL and Masaryk University."
      )
    ),
    notes = list(
      associations = paste(
        "workRoleTasks and workRoleRequirements carry only the two foreign",
        "keys. The export attaches no proficiency level, weight, importance,",
        "or mandatory flag to either association."
      )
    )
  )

  manifest_path <- file.path(cyqual_config$staging_dir, cyqual_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== CyQUAL 1.2.0 Ingestion ===")

  source <- select_source_file()
  message("Source: ", source$filename, " (language ", source$language, ")")

  message("Verifying staged file...")
  hash <- hash_source_file(source$path, source$expected_sha256)

  message("Loading JSON...")
  cyqual <- load_cyqual_json(source$path)
  check_counts(cyqual, cyqual_expected_counts)

  message("Building tables...")
  tables <- build_cyqual_tables(cyqual)

  check_integrity(tables)

  tables_dir <- file.path(cyqual_config$staging_dir, cyqual_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  output_map <- c(
    categories           = "categories.csv",
    competencyGroups     = "competency-groups.csv",
    competencies         = "competencies.csv",
    specializationAreas  = "specialization-areas.csv",
    workRoles            = "work-roles.csv",
    tasks                = "tasks.csv",
    requirements         = "requirements.csv",
    workRoleTasks        = "work-role-tasks.csv",
    workRoleRequirements = "work-role-requirements.csv"
  )

  message("Writing CSVs...")
  for (key in names(output_map)) {
    out_path <- file.path(tables_dir, output_map[[key]])
    write_csv(tables[[key]], out_path)
    message(glue("  {output_map[[key]]}: {nrow(tables[[key]])} rows"))
  }

  # The diacritic round trip only means something for the Czech export; the
  # English one carries no Czech diacritics to check.
  if (identical(source$language, "cs")) {
    message("Verifying Czech diacritics round trip...")
    verify_diacritic_round_trip(
      file.path(tables_dir, "work-roles.csv"), tables$workRoles, "title"
    )
    verify_diacritic_round_trip(
      file.path(tables_dir, "tasks.csv"), tables$tasks, "description"
    )
  }

  message("Association distribution...")
  report_per_role_distribution(tables$workRoleTasks, "workRole",
                               tables$workRoles$code, "Tasks")
  report_per_role_distribution(tables$workRoleRequirements, "workRole",
                               tables$workRoles$code, "Requirements")

  message("Writing provenance manifest...")
  write_provenance_manifest(source, tables, hash, describe_other_staged_sources(source))

  message("\n=== Summary ===")
  message("  Categories: ",           nrow(tables$categories))
  message("  Competency groups: ",    nrow(tables$competencyGroups))
  message("  Competencies: ",         nrow(tables$competencies))
  message("  Specialization areas: ", nrow(tables$specializationAreas))
  message("  Work roles: ",           nrow(tables$workRoles))
  message("  Tasks: ",                nrow(tables$tasks))
  message("  Requirements: ",         nrow(tables$requirements))
  message("  Work-role-task edges: ", nrow(tables$workRoleTasks))
  message("  Work-role-requirement edges: ", nrow(tables$workRoleRequirements))
  message("\nOutput: ", tables_dir)
  message("Done.")

  invisible(tables)
}

if (sys.nframe() == 0) {
  main()
}
