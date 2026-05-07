# 010-ingest-nice.R
#
# Ingest the NICE Framework v2 (NIST SP 800-181 Rev 1 components) from the
# NIST Cybersecurity and Privacy Reference Tool (CPRT) JSON distribution.
#
# Source:
#   - nice-v2-framework.json (NIST CPRT export, staged in data/raw/nice/).
#   - Publisher: National Institute of Standards and Technology (NIST).
#   - Authority: NIST SP 800-181 Rev 1.
#
# Licensing: US Government work, public domain. Safe to redistribute.
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

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

nice_config <- list(
  framework_version = "NICE v2 (NIST SP 800-181 Rev 1 components)",
  version_source    = "NIST CPRT v2 export",
  version_date      = "2024",
  publisher         = "NIST (National Institute of Standards and Technology)",
  json_filename     = "nice-v2-framework.json",
  staging_dir       = here("data", "raw", "nice"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml"
)

# Element types in the NIST CPRT JSON
nice_element_types <- list(
  work_role       = "work_role",
  task            = "task",
  knowledge       = "knowledge",
  skill           = "skill",
  category        = "category",
  competency_area = "competency_area"
)

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

#' Load the NIST CPRT JSON export
load_nice_cprt <- function(json_path) {
  fromJSON(json_path, simplifyVector = FALSE)
}

#' Extract elements of a specific type into a tibble
extract_elements_of_type <- function(cprt, element_type) {
  cprt$elements |>
    keep(\(e) identical(e$element_type, element_type)) |>
    map_dfr(\(e) tibble(
      element_id   = e$element_identifier %||% NA_character_,
      element_type = e$element_type       %||% NA_character_,
      title        = e$title               %||% NA_character_,
      text         = e$text                %||% NA_character_,
      doc_id       = e$doc_identifier      %||% NA_character_
    )) |>
    mutate(across(where(is.character), \(x) str_squish(x)))
}

#' Build the work-role → TKS association table
#'
#' NICE CPRT uses `projection` relationships. A work_role is the source,
#' a task/knowledge/skill is the destination.
build_role_tks_associations <- function(cprt, work_roles, tks_elements) {
  wr_ids <- work_roles$element_id
  tks_ids <- tks_elements$element_id

  relationships <- cprt$relationships |>
    map_dfr(\(r) tibble(
      source_id    = r$source_element_identifier %||% NA_character_,
      dest_id      = r$dest_element_identifier   %||% NA_character_,
      rel_id       = r$relationship_identifier   %||% NA_character_
    ))

  relationships |>
    filter(source_id %in% wr_ids, dest_id %in% tks_ids) |>
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

#' Build the work-role → category mapping
build_role_categories <- function(cprt, work_roles, categories) {
  wr_ids <- work_roles$element_id
  cat_ids <- categories$element_id

  rels <- cprt$relationships |>
    map_dfr(\(r) tibble(
      source_id = r$source_element_identifier %||% NA_character_,
      dest_id   = r$dest_element_identifier   %||% NA_character_
    ))

  rels |>
    filter(source_id %in% cat_ids, dest_id %in% wr_ids) |>
    transmute(
      work_role_id = dest_id,
      category_id  = source_id
    )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(json_path,
                                      work_roles_df,
                                      tasks_df,
                                      knowledge_df,
                                      skills_df,
                                      categories_df,
                                      associations_df) {
  manifest <- list(
    framework         = "NICE",
    framework_version = nice_config$framework_version,
    framework_date    = nice_config$version_date,
    source = list(
      type      = "official_cprt_json",
      authority = "NIST SP 800-181 Rev 1",
      publisher = nice_config$publisher,
      filename  = nice_config$json_filename
    ),
    retrieval = list(
      retrieved_date  = format(Sys.Date(), "%Y-%m-%d"),
      retrieved_by    = "scripts/010-ingest-nice.R",
      file_size_bytes = file.info(json_path)$size,
      file_sha256     = digest(file = json_path, algo = "sha256"),
      acquisition_note = paste(
        "Download the canonical NICE v2 CPRT JSON from the NIST",
        "Cybersecurity and Privacy Reference Tool and stage it at",
        "data/raw/nice/nice-v2-framework.json before running this script."
      )
    ),
    extraction = list(
      work_roles_count       = nrow(work_roles_df),
      tasks_count            = nrow(tasks_df),
      knowledge_count        = nrow(knowledge_df),
      skills_count           = nrow(skills_df),
      categories_count       = nrow(categories_df),
      unique_tks_count       = nrow(tasks_df) + nrow(knowledge_df) + nrow(skills_df),
      tks_associations_count = nrow(associations_df)
    ),
    licensing = list(
      source_license = "US Government work, public domain",
      redistribution = "Safe to redistribute NICE text and derivative analysis"
    )
  )

  manifest_path <- file.path(nice_config$staging_dir, nice_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== NICE v2 Ingestion ===")

  json_path <- file.path(nice_config$staging_dir, nice_config$json_filename)
  if (!file.exists(json_path)) {
    stop("NICE JSON not found at ", json_path)
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

  message("Building role -> TKS associations...")
  tks_elements <- bind_rows(tasks_df, knowledge_df, skills_df)
  associations_df <- build_role_tks_associations(cprt, work_roles_df, tks_elements)
  message("  Associations: ", nrow(associations_df))

  message("Building role -> category mapping...")
  role_categories_df <- build_role_categories(cprt, work_roles_df, categories_df)

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

  message("Writing provenance manifest...")
  write_provenance_manifest(
    json_path, work_roles_df, tasks_df, knowledge_df, skills_df,
    categories_df, associations_df
  )

  message("\n=== Summary ===")
  message("  Work roles: ",            nrow(work_roles_df))
  message("  Tasks: ",                 nrow(tasks_df))
  message("  Knowledge statements: ",  nrow(knowledge_df))
  message("  Skill statements: ",      nrow(skills_df))
  message("  Categories: ",            nrow(categories_df))
  message("  Competency areas: ",      nrow(comp_areas_df))
  message("  Unique TKS total: ",      nrow(tasks_df) + nrow(knowledge_df) + nrow(skills_df))
  message("  Role-TKS associations: ", nrow(associations_df))
  message("\nOutput: ", tables_dir)
  message("Done.")

  invisible(list(
    work_roles     = work_roles_df,
    tasks          = tasks_df,
    knowledge      = knowledge_df,
    skills         = skills_df,
    categories     = categories_df,
    comp_areas     = comp_areas_df,
    associations   = associations_df
  ))
}

if (sys.nframe() == 0) {
  main()
}
