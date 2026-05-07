# 010-ingest-ecsf.R
#
# Ingest the European Cybersecurity Skills Framework (ECSF) from the ENISA
# JSON distribution. Flatten 12 role profiles into tidy CSVs for downstream
# JSON-LD assembly.
#
# Source: ENISA ECSF v1 JSON (manually staged at data/raw/ecsf/ECSF_v1.json).
#   Companion XLSX: data/raw/ecsf/ECSF.xlsx.
#   Publication: ENISA, European Cybersecurity Skills Framework Role Profiles,
#                September 2022 (PDF last updated August 2024).
#
# Licensing: ENISA publications are typically CC BY 4.0. Verify before toolkit
# release; analytical derivatives are safe to publish regardless.
#
# Run: Rscript scripts/010-ingest-ecsf.R

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

ecsf_config <- list(
  framework_version = "ECSF v1",
  version_date      = "2022-09-19",
  revision_date     = "2024-08-02",
  publisher         = "ENISA (European Union Agency for Cybersecurity)",
  json_filename     = "ECSF_v1.json",
  xlsx_filename     = "ECSF.xlsx",
  staging_dir       = here("data", "raw", "ecsf"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

#' Generate a stable profile_id from a profile title
#'
#' @param title Character.
#' @return Character slug.
slugify_profile_title <- function(title) {
  title |>
    str_remove_all("\\(.*?\\)") |>
    str_trim() |>
    str_replace_all("[^A-Za-z0-9]+", "-") |>
    str_remove_all("^-|-$") |>
    str_to_lower()
}

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

#' Load the ECSF JSON as a list of profiles
#'
#' @param json_path Character.
#' @return List of 12 profile lists.
load_ecsf_json <- function(json_path) {
  fromJSON(json_path, simplifyVector = FALSE)
}

#' Build the profile catalog (one row per profile)
#'
#' @param profiles List from load_ecsf_json().
#' @return Tibble with columns: profile_id, title, alternative_titles,
#'   summary_statement, mission.
build_profile_catalog <- function(profiles) {
  profiles |>
    map_dfr(\(profile) {
      tibble(
        profile_id         = slugify_profile_title(profile$title),
        title              = profile$title,
        alternative_titles = paste(unlist(profile$alternative_titles) %||% "",
                                   collapse = " | "),
        summary_statement  = profile$summary_statement %||% NA_character_,
        mission            = profile$mission %||% NA_character_
      )
    })
}

#' Flatten elements (main_tasks, key_skills, key_knowledge, deliverables)
#' into long format
#'
#' @param profiles List.
#' @return Tibble with columns: profile_id, element_type, element_index,
#'   element_text.
flatten_profile_elements <- function(profiles) {
  element_fields <- c("main_tasks", "key_skills", "key_knowledge", "deliverables")

  profiles |>
    map_dfr(\(profile) {
      profile_id <- slugify_profile_title(profile$title)

      element_fields |>
        map_dfr(\(field_name) {
          values <- profile[[field_name]]
          if (is.null(values) || length(values) == 0) return(tibble())
          tibble(
            profile_id     = profile_id,
            element_type   = field_name,
            element_index  = seq_along(values),
            element_text   = unlist(values, use.names = FALSE)
          )
        })
    })
}

#' Flatten ecompetences (e-CF cross-reference) into long format
#'
#' ECSF embeds references to e-CF 4.0 competences. Each entry is a triple:
#' [ecf_code, ecf_competence_name, proficiency_level].
#'
#' @param profiles List.
#' @return Tibble with columns: profile_id, ecf_code, ecf_competence_name,
#'   proficiency_level.
flatten_ecompetences <- function(profiles) {
  profiles |>
    map_dfr(\(profile) {
      profile_id <- slugify_profile_title(profile$title)
      ecomps <- profile$ecompetences
      if (is.null(ecomps) || length(ecomps) == 0) return(tibble())

      ecomps |>
        map_dfr(\(triple) {
          tibble(
            profile_id           = profile_id,
            ecf_code             = triple[[1]] %||% NA_character_,
            ecf_competence_name  = triple[[2]] %||% NA_character_,
            proficiency_level    = suppressWarnings(as.integer(triple[[3]]))
          )
        })
    })
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(json_path, profile_catalog, elements_long, ecompetences_long) {
  manifest <- list(
    framework         = "ECSF",
    framework_version = ecsf_config$framework_version,
    framework_date    = ecsf_config$version_date,
    revision_date     = ecsf_config$revision_date,
    source = list(
      type          = "official_json",
      publisher     = ecsf_config$publisher,
      filename      = ecsf_config$json_filename,
      xlsx_companion = ecsf_config$xlsx_filename
    ),
    retrieval = list(
      retrieved_date = format(Sys.Date(), "%Y-%m-%d"),
      retrieved_by   = "scripts/010-ingest-ecsf.R",
      file_size_bytes = file.info(json_path)$size,
      file_sha256    = digest(file = json_path, algo = "sha256")
    ),
    extraction = list(
      profile_count          = nrow(profile_catalog),
      element_count          = nrow(elements_long),
      ecompetence_references = nrow(ecompetences_long),
      element_type_breakdown = elements_long |>
        count(element_type) |>
        deframe() |>
        as.list()
    ),
    licensing = list(
      source_license = "ENISA publications are typically CC BY 4.0. Verify for this artifact before toolkit release.",
      redistribution = "Analytical derivatives safe. Source-text redistribution pending license verification."
    ),
    notes = list(
      ecf_cross_references = paste(
        "ECSF embeds references to e-CF 4.0 competences. Even with e-CF",
        "out of direct-ingest scope, the ecompetences table preserves",
        "these cross-walk pointers for potential future work."
      )
    )
  )

  manifest_path <- file.path(ecsf_config$staging_dir, ecsf_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== ECSF v1 Ingestion ===")

  json_path <- file.path(ecsf_config$staging_dir, ecsf_config$json_filename)
  if (!file.exists(json_path)) {
    stop("ECSF JSON not found at ", json_path)
  }

  message("Loading JSON...")
  profiles <- load_ecsf_json(json_path)
  message("  Profiles loaded: ", length(profiles))

  message("Building profile catalog...")
  profile_catalog <- build_profile_catalog(profiles)

  message("Flattening element statements...")
  elements_long <- flatten_profile_elements(profiles)

  message("Flattening e-CF cross-references...")
  ecompetences_long <- flatten_ecompetences(profiles)

  tables_dir <- file.path(ecsf_config$staging_dir, ecsf_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(profile_catalog,   file.path(tables_dir, "profiles.csv"))
  write_csv(elements_long,     file.path(tables_dir, "profile-elements-long.csv"))
  write_csv(ecompetences_long, file.path(tables_dir, "ecf-cross-references.csv"))

  message("Writing provenance manifest...")
  write_provenance_manifest(json_path, profile_catalog, elements_long, ecompetences_long)

  message("\n=== Summary ===")
  message("  Profiles: ", nrow(profile_catalog))
  message("  Elements (tasks/skills/knowledge/deliverables): ", nrow(elements_long))
  cat("  Element type breakdown:\n")
  print(elements_long |> count(element_type))
  message("  e-CF cross-references: ", nrow(ecompetences_long))
  message("\nOutput: ", tables_dir)
  message("Done.")

  invisible(list(
    profiles          = profiles,
    profile_catalog   = profile_catalog,
    elements_long     = elements_long,
    ecompetences_long = ecompetences_long
  ))
}

# `%||%` fallback if dplyr/rlang isn't providing it
if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

if (sys.nframe() == 0) {
  main()
}
