# 010-ingest-csta2026.R
#
# Ingest the 2026 CSTA PK-12 Computer Science Standards from the staged JSON
# behind CSTA's official interactive Standards Explorer.
#
# Source: csta-2026-standards-api.json (331 records), staged under
# data/raw/csta-2026/ together with the full standards PDF and a hand-written
# provenance.yml that records each staged file's SHA256. This script never
# fetches anything: it reads the staged JSON, and it stops unless every file
# provenance.yml declares is present with the declared hash.
# License: CC BY-NC-SA 4.0 (attribution, non-commercial, share-alike), read
# from the PDF's own licence page (p. iv).
#
# csta-2026 is a framework of its own, not a revision of csta-2017. The two
# editions share no identifier scheme and CSTA's crosswalk between them is
# many-to-many, so both are kept side by side under separate prefixes.
#
# Structure. Every record is one standard with a structured code,
# LEVEL-CONCEPT-SUBCONCEPT-NN (e.g. MS-ALG-PS-01, S1-CYB-ND-01).
#   Foundational tier: levels EK, E1..E5, MS, HS x 5 concepts x 18 subconcepts.
#   Specialty tier:    levels S1, S2 x 7 specialty areas (six areas plus X+CS,
#                      which has Specialty I only) x 28 subareas.
# For specialty records the explorer puts the area name in `concept` and the
# subarea in `specialtySubArea`, leaving `subconcept` empty. This script
# normalises both tiers onto one concept / subconcept pair.
#
# Tables written to data/raw/csta-2026/tables/:
#   standards.csv   one row per standard (331)
#   boundaries.csv  one row per boundary-statement paragraph
#   examples.csv    one row per implementation example
#   units.csv       observed (level, concept) groups that become units
#
# Practices, dispositions, progressions and interdisciplinary connections are
# staged in the JSON but not carried into these tables' graph path yet. The
# practice and disposition codes stay on standards.csv as published lists.
#
# Run: Rscript scripts/010-ingest-csta2026.R

suppressPackageStartupMessages({
  library(here)
  library(jsonlite)
  library(dplyr)
  library(readr)
  library(yaml)
  library(purrr)
  library(tibble)
  library(stringr)
  library(digest)
})

csta2026_config <- list(
  staging_dir       = here("data", "raw", "csta-2026"),
  json_filename     = "csta-2026-standards-api.json",
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml"
)

# Level codes are the first segment of every CSTA identifier. The explorer's
# `grade` field says the same thing in a second vocabulary; both are read and
# checked against each other.
csta2026_levels <- tibble::tribble(
  ~level, ~grade,         ~tier,
  "EK",   "PK/K",         "foundational",
  "E1",   "1",            "foundational",
  "E2",   "2",            "foundational",
  "E3",   "3",            "foundational",
  "E4",   "4",            "foundational",
  "E5",   "5",            "foundational",
  "MS",   "MS",           "foundational",
  "HS",   "HS",           "foundational",
  "S1",   "Specialty-I",  "specialty",
  "S2",   "Specialty-II", "specialty"
)

# ---------------------------------------------------------------------------
# Provenance anchor
# ---------------------------------------------------------------------------

#' Stop unless every file the manifest declares matches its recorded hash.
verify_staged_hashes <- function(manifest, staging_dir) {
  files <- manifest$source$files
  if (is.null(files) || length(files) == 0) {
    stop("provenance.yml declares no source files to verify.")
  }
  for (f in files) {
    path <- file.path(staging_dir, f$filename)
    if (!file.exists(path)) stop("Declared source file missing: ", path)
    actual <- digest(file = path, algo = "sha256")
    if (!identical(actual, f$file_sha256)) {
      stop("SHA256 mismatch for ", f$filename, ": declared ", f$file_sha256,
           ", found ", actual)
    }
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

chr_or_empty <- function(x) if (is.null(x) || length(x) == 0) "" else as.character(x)

# Practice codes as the standards document prints them (ESR1, IC3, CT6,
# HCD10): the explorer gives the practice number in front of its statement
# and the category name as the label.
csta2026_practice_categories <- c(
  "Ethics & Social Responsibility" = "ESR",
  "Inclusive Collaboration"        = "IC",
  "Computational Thinking"         = "CT",
  "Human-Centered Design"          = "HCD"
)

practice_code <- function(pillar) {
  abbrev <- unname(csta2026_practice_categories[pillar$label])
  number <- str_extract(pillar$description, "^[0-9]+")
  if (is.na(abbrev) || is.na(number)) {
    stop("Unrecognised practice alignment: ", pillar$label, " / ", pillar$description)
  }
  paste0(abbrev, number)
}

#' One row per standard, both tiers normalised onto concept / subconcept.
extract_csta2026_standards <- function(records) {
  standards <- records |>
    map(\(r) tibble(
      code             = chr_or_empty(r$code),
      grade            = chr_or_empty(r$grade),
      concept_raw      = chr_or_empty(r$concept),
      subconcept_raw   = chr_or_empty(r$subconcept),
      specialty_area   = chr_or_empty(r$specialtyArea),
      specialty_subarea = chr_or_empty(r$specialtySubArea),
      title            = chr_or_empty(r$title),
      ai_standard_raw  = chr_or_empty(r$ai_standard),
      practices        = paste(map_chr(r$pillars %||% list(), practice_code),
                               collapse = ";"),
      dispositions     = paste(unlist(r$dispositions %||% list()), collapse = ";")
    )) |>
    list_rbind()

  standards |>
    mutate(
      level               = str_extract(code, "^[^-]+"),
      specialty_area_code = if_else(nzchar(specialty_area),
                                    str_split_i(code, "-", 2), NA_character_),
      concept             = if_else(nzchar(specialty_area), specialty_area, concept_raw),
      subconcept          = if_else(nzchar(specialty_area), specialty_subarea, subconcept_raw),
      ai_standard         = ai_standard_raw == "Yes",
      source_section      = paste(level, concept, subconcept, sep = ".")
    ) |>
    left_join(csta2026_levels |> rename(grade_expected = grade), by = "level") |>
    select(code, level, grade, grade_expected, tier, concept, subconcept,
           specialty_area_code, title, ai_standard, ai_standard_raw,
           practices, dispositions, source_section) |>
    arrange(code)
}

#' Boundary statements: one row per published paragraph, in source order.
extract_csta2026_boundaries <- function(records) {
  records |>
    map(\(r) {
      txt <- unlist(r$boundaries %||% list())
      tibble(code = rep(chr_or_empty(r$code), length(txt)),
             ordinal = seq_along(txt),
             text = as.character(txt))
    }) |>
    list_rbind() |>
    arrange(code, ordinal)
}

#' Implementation examples: one row per example, in source order.
extract_csta2026_examples <- function(records) {
  records |>
    map(\(r) {
      exs <- r$examples %||% list()
      tibble(code = rep(chr_or_empty(r$code), length(exs)),
             ordinal = seq_along(exs),
             example_type = map_chr(exs, \(e) chr_or_empty(e$type)),
             text = map_chr(exs, \(e) chr_or_empty(e$description)))
    }) |>
    list_rbind() |>
    arrange(code, ordinal)
}

#' Organizing units from the (level, concept) pairs actually observed, never
#' from a crossing: X+CS has Specialty I only, and a crossing would mint an
#' empty S2 unit for it. Foundational units are level x concept; specialty
#' units are tier level (S1/S2) x specialty area. The unit id reuses CSTA's
#' own identifier segments, so MS-ALG groups MS-ALG-*-* and S1-CYB groups
#' S1-CYB-*-*.
build_csta2026_units <- function(standards) {
  standards |>
    mutate(concept_code = str_split_i(code, "-", 2)) |>
    group_by(level, tier, concept, concept_code, specialty_area_code) |>
    summarise(standards_count = n(), .groups = "drop") |>
    mutate(unit_id = paste(level, concept_code, sep = "-")) |>
    select(unit_id, level, tier, concept, concept_code, specialty_area_code,
           standards_count) |>
    arrange(match(level, csta2026_levels$level), concept_code)
}

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

check_csta2026_extraction <- function(standards, boundaries, examples, units, manifest) {
  ext <- manifest$extraction
  problems <- c(
    if (nrow(standards) != ext$standards_count)
      paste("standards:", nrow(standards), "vs declared", ext$standards_count),
    if (anyDuplicated(standards$code)) "duplicate standard codes",
    if (any(is.na(standards$tier))) "unknown level prefix in a standard code",
    if (any(standards$grade != standards$grade_expected, na.rm = TRUE))
      "code level prefix disagrees with the explorer grade field",
    if (sum(standards$tier == "foundational") != ext$foundational_count)
      "foundational count differs from provenance",
    if (sum(standards$tier == "specialty") != ext$specialty_count)
      "specialty count differs from provenance",
    if (any(!nzchar(standards$title))) "empty standard text",
    if (any(!nzchar(standards$subconcept))) "empty subconcept",
    if (!all(standards$ai_standard_raw %in% c("Yes", "No"))) "unexpected ai_standard value",
    if (any(!standards$code %in% boundaries$code)) "a standard without a boundary statement",
    if (any(!nzchar(str_trim(boundaries$text)))) "empty boundary statement",
    if (any(!nzchar(str_trim(examples$text)))) "empty implementation example",
    if (length(unique(standards$level)) != ext$levels_count) "level count differs from provenance",
    if (n_distinct(standards$specialty_area_code, na.rm = TRUE) != ext$specialty_areas)
      "specialty area count differs from provenance"
  )
  if (length(problems) > 0) {
    stop("csta-2026 extraction failed its checks:\n  ",
         paste(problems, collapse = "\n  "))
  }
  invisible(TRUE)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== CSTA PK-12 CS Standards (2026) Ingestion ===")

  manifest_path <- file.path(csta2026_config$staging_dir, csta2026_config$manifest_filename)
  if (!file.exists(manifest_path)) stop("provenance.yml not found at ", manifest_path)
  manifest <- read_yaml(manifest_path)

  message("Verifying staged files against provenance.yml hashes...")
  verify_staged_hashes(manifest, csta2026_config$staging_dir)

  json_path <- file.path(csta2026_config$staging_dir, csta2026_config$json_filename)
  records <- fromJSON(json_path, simplifyVector = FALSE)
  message("  Records: ", length(records))

  standards  <- extract_csta2026_standards(records)
  boundaries <- extract_csta2026_boundaries(records)
  examples   <- extract_csta2026_examples(records)
  units      <- build_csta2026_units(standards)

  check_csta2026_extraction(standards, boundaries, examples, units, manifest)

  tables_dir <- file.path(csta2026_config$staging_dir, csta2026_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(standards |> select(-grade_expected, -ai_standard_raw),
            file.path(tables_dir, "standards.csv"), na = "")
  write_csv(boundaries, file.path(tables_dir, "boundaries.csv"))
  write_csv(examples,   file.path(tables_dir, "examples.csv"))
  write_csv(units,      file.path(tables_dir, "units.csv"), na = "")

  # The hand-written manifest is the provenance anchor and is kept as staged.
  # Only the counts this script measures are added under `extraction`, so the
  # ingestion summary can report them.
  manifest$extraction$organizing_units         <- nrow(units)
  manifest$extraction$foundational_units       <- sum(units$tier == "foundational")
  manifest$extraction$specialty_units          <- sum(units$tier == "specialty")
  manifest$extraction$boundary_statements      <- nrow(boundaries)
  manifest$extraction$implementation_examples  <- nrow(examples)
  manifest$extraction$standards_with_examples  <- n_distinct(examples$code)
  manifest$extraction$ai_standards             <- sum(standards$ai_standard)
  write_yaml(manifest, manifest_path)

  message("\n=== Summary ===")
  message("  Standards: ", nrow(standards),
          " (", sum(standards$tier == "foundational"), " foundational, ",
          sum(standards$tier == "specialty"), " specialty)")
  message("  Organizing units: ", nrow(units),
          " (", sum(units$tier == "foundational"), " foundational, ",
          sum(units$tier == "specialty"), " specialty)")
  message("  Boundary statement paragraphs: ", nrow(boundaries))
  message("  Implementation examples: ", nrow(examples),
          " across ", n_distinct(examples$code), " standards")
  message("  Cybersecurity (CYB) standards: ",
          sum(standards$specialty_area_code %in% "CYB"))
  message("\nDone.")

  invisible(list(standards = standards, boundaries = boundaries,
                 examples = examples, units = units))
}

if (sys.nframe() == 0) {
  main()
}
