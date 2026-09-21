# 010-ingest-digcomp.R
#
# Ingest the European Digital Competence Framework for Citizens, DigComp
# 3.0, replacing DigComp 2.2 in place (owner decision D1, 2026-08-21: a
# framework upgrade, not a second framework alongside the old one).
#
# Source:
#   - The official DigComp 3.0 data supplement (JSON-LD + XLSX), staged
#     under data/raw/digcomp/v3.0/. Hash-anchored in
#     data/raw/digcomp/v3.0/provenance.yml. Never fetched live.
#   - Intermediate: data/raw/digcomp/v3.0/tables/*.csv, already parsed
#     verbatim from the JSON-LD's `@graph` (see that provenance.yml's
#     `source$conversion_tool`). This ingester verifies the JSON-LD's
#     recorded hash, then reads the staged tables the same way
#     010-ingest-otccf.R reads its extracted-text.md intermediate rather
#     than re-parsing the PDF on every run.
#   - Publisher: European Commission Joint Research Centre (JRC)
#   - Published: 2025-11-27, Fifth edition, JRC144121, doi:10.2760/0001149
#     (report), doi:10.2905/JRC.FR75K8R (dataset)
#
# Licensing: CC BY 4.0. Verified three ways in
# data/raw/digcomp/v3.0/provenance.yml. Attribution target: Cosgrove &
# Cachia (2025), DigComp 3.0, EUR 40491, doi:10.2760/0001149; dataset
# doi:10.2905/JRC.FR75K8R.
#
# Structure (from MAPPING-2.2-to-3.0.md and the data supplement):
#   5 competence areas, 21 competences, identical numbering and area
#   membership to 2.2 (see data/raw/digcomp/v3.0/MAPPING-2.2-to-3.0.md).
#   4/5 area names and 13/21 competence names revised. 362 Competence
#   Statements (coarse, per competence x 4-level proficiency band) and 523
#   Learning Outcomes (fine-grained, typed Knowledge/Skill/Attitude)
#   replace 2.2's un-staged "examples of knowledge, skills and attitudes".
#   Proficiency levels (8-level descriptors with a 4-level and a
#   CEFR-style 6-level crosswalk) and a 126-term glossary are staged but
#   not emitted into the graph (see build_digcomp_parts() in
#   scripts/020-assemble-jsonld.R) -- deferred, not lost.
#
# Errata: the supplement (24 Nov 2025) predates the official errata
# (updated 2026-01-27). data/raw/digcomp/v3.0/errata.csv lists 7
# data-affecting corrections. This ingester applies E1-E4 deliberately
# (see apply_learning_outcome_errata() below). After errata: 522 learning
# outcomes (competence 2.5 drops from 21 to 20). E5-E7 (LO4.3.22,
# LO5.2.12, LO5.4.13) are published as instructions without a quoted
# replacement sentence, so they are left unapplied -- the staged file's
# wording is carried unchanged rather than composing new sentence text in
# JRC's name. See docs/ingestion-summary.md.
#
# 2.2 raw stays archived at data/raw/digcomp/v2.2/ (not deleted). This
# script's OUTPUT tables replace data/raw/digcomp/tables/ and
# data/raw/digcomp/provenance.yml in place, per
# scripts/020-assemble-jsonld.R::read_framework_table()'s fixed
# data/raw/<slug>/tables/ convention.
#
# Run: Rscript scripts/010-ingest-digcomp.R

suppressPackageStartupMessages({
  library(here)
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

digcomp_config <- list(
  framework_version = "DigComp 3.0",
  version_date      = "2025-11-27",
  publisher         = "European Commission Joint Research Centre (JRC)",
  source_dir        = here("data", "raw", "digcomp", "v3.0"),
  source_tables_dir = here("data", "raw", "digcomp", "v3.0", "tables"),
  jsonld_filename   = "DigComp-3.0-Data-Supplement-24-Nov-2025.jsonld",
  errata_filename   = "errata.csv",
  staging_dir       = here("data", "raw", "digcomp"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml",
  license           = "CC BY 4.0 (European Union, 2025; Commission Decision 2011/833/EU)"
)

# ---------------------------------------------------------------------------
# Errata
# ---------------------------------------------------------------------------

#' Apply the 7 official DigComp 3.0 errata to the staged learning outcomes
#'
#' @description
#' Three corrections (E2-E4) reword a single outcome's text using the
#' exact replacement text the errata document quotes verbatim. Each is
#' applied by exact `outcome_id` match, before any renumbering, so a later
#' renumbering pass never has to track a moving target.
#'
#' E5, E6 and E7 (LO4.3.22, LO5.2.12, LO5.4.13) are published as
#' instructions naming only the phrase to insert, with no replacement
#' sentence quoted. Composing a new sentence from that instruction would
#' put cybedtools's words in JRC's mouth rather than JRC's own text, so
#' these three are left unapplied: the staged file's wording is carried
#' through unchanged. They are recorded as known-unapplied in the
#' provenance manifest and in docs/ingestion-summary.md.
#'
#' The seventh correction (E1) is structural: LO2.5.09 is a verbatim
#' duplicate of LO2.5.07 and is deleted, and competence 2.5's remaining
#' outcomes (originally 2.5.10-2.5.21) are renumbered down by one so 2.5
#' ends at 20 outcomes with no numbering gap. The official erratum text
#' ("...LOs from 2.5.09 to 2.5.21 should be re-numbered to 2.5.08 to
#' 2.5.20...") is internally inconsistent with deleting 09 (that would
#' renumber 10-21, not 09-21); this resolves it the way
#' data/raw/digcomp/v3.0/errata.csv's own note does: one duplicate
#' removed, 20 outcomes remain in 2.5, 523 -> 522 overall.
#'
#' @param outcomes Tibble read from `learning-outcomes.csv`.
#' @return The corrected tibble, 522 rows.
apply_learning_outcome_errata <- function(outcomes) {
  reword <- function(df, id, new_text) {
    idx <- which(df$outcome_id == id)
    if (length(idx) != 1L) {
      stop("Erratum target not found or not unique: ", id)
    }
    df$description[idx] <- new_text
    df
  }

  outcomes <- outcomes |>
    reword("LO2.5.15", paste(
      "Respond with effective and respectful communication and behaviour",
      "to difficult or complex situations in digital environments."
    )) |>
    reword("LO2.6.27", paste(
      "Stay informed about developments in digital technologies in",
      "relation to digital identity management and protection."
    )) |>
    reword("LO4.3.18", paste(
      "Describe strategies to help protect against and respond",
      "effectively to harmful behaviour, content and deceptive design in",
      "digital environments."
    ))
    # E5, E6 and E7 (LO4.3.22, LO5.2.12, LO5.4.13) are published as
    # instructions naming only a phrase to insert, with no replacement
    # sentence quoted. Composing new sentence text from that instruction
    # would be cybedtools's words, not JRC's, so these three are left
    # unapplied and the staged file's wording carries through verbatim.
    # See docs/ingestion-summary.md and the errata block in
    # write_provenance_manifest() below.

  dup_idx <- which(outcomes$outcome_id == "LO2.5.09")
  if (length(dup_idx) != 1L) {
    stop("Erratum E1 target not found or not unique: LO2.5.09")
  }
  outcomes <- outcomes[-dup_idx, ]

  is_25 <- outcomes$competence_id == "2.5"
  suffix <- as.integer(str_extract(outcomes$outcome_id, "(?<=\\.)[0-9]+$"))
  shift <- is_25 & suffix > 9L
  outcomes$outcome_id[shift] <- sprintf("LO2.5.%02d", suffix[shift] - 1L)

  outcomes |> arrange(competence_id, outcome_id)
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(source_prov, jsonld_sha256, tables) {
  manifest_path <- file.path(digcomp_config$staging_dir, digcomp_config$manifest_filename)
  hashes <- c(jsonld_sha256 = jsonld_sha256)
  retrieved_date <- resolve_retrieved_date(manifest_path, hashes)

  manifest <- list(
    framework         = "DigComp",
    framework_version = digcomp_config$framework_version,
    version_date      = digcomp_config$version_date,
    edition           = source_prov$edition,
    authors           = source_prov$authors,
    source = list(
      type            = "structured_data_supplement",
      publisher       = digcomp_config$publisher,
      jsonld_filename = digcomp_config$jsonld_filename,
      jrc_id          = source_prov$source$jrc_id,
      isbn_online     = source_prov$source$isbn_online,
      doi_report      = source_prov$source$doi_report,
      doi_dataset     = source_prov$source$doi_dataset,
      conversion_tool = "Rscript scripts/010-ingest-digcomp.R: reads data/raw/digcomp/v3.0/tables/ (verbatim JSON-LD @graph extraction, hash-verified against the supplement below), applies errata.csv"
    ),
    retrieval = list(
      retrieved_date = retrieved_date,
      retrieved_by   = "scripts/010-ingest-digcomp.R",
      jsonld_sha256  = jsonld_sha256
    ),
    extraction = list(
      competence_areas     = nrow(tables$areas),
      competences          = nrow(tables$competences),
      competence_statements = nrow(tables$statements),
      learning_outcomes_pre_errata  = 523L,
      learning_outcomes_post_errata = nrow(tables$outcomes),
      proficiency_levels_staged = nrow(tables$proficiency_levels),
      glossary_terms_staged     = nrow(tables$glossary),
      extraction_scope = "complete: every competence-area, competence, competence-statement and (post-errata) learning-outcome row from the official JSON-LD data supplement. Proficiency levels and glossary are staged verbatim but not emitted into the graph (deferred, see scripts/020-assemble-jsonld.R)."
    ),
    errata = list(
      status = "PARTIALLY_APPLIED",
      errata_file = "data/raw/digcomp/v3.0/errata.csv",
      applied = c("E1", "E2", "E3", "E4"),
      unapplied = c("E5", "E6", "E7"),
      note = "E1 (structural: delete LO2.5.09, renumber 2.5's outcomes down by one) and E2/E3/E4 (exact quoted replacement text) applied verbatim. Errata E5 to E7 are published as instructions without replacement text, so the staged wording is carried unchanged. The learning-outcome count (522) is unaffected: it comes from E1 alone."
    ),
    licensing = list(
      source_license = digcomp_config$license,
      citation = paste(
        "Cosgrove, J. and Cachia, R., DigComp 3.0: The Digital Competence",
        "Framework for Citizens, EUR 40491, Publications Office of the",
        "European Union, Luxembourg, 2025, ISBN 978-92-68-32677-0,",
        "doi:10.2760/0001149. Dataset: doi:10.2905/JRC.FR75K8R."
      ),
      redistribution_note = paste(
        "CC BY 4.0, verified three ways in",
        "data/raw/digcomp/v3.0/provenance.yml: the dataset's own",
        "copyright.txt, the JRC Data Catalogue record, and the DigComp 3.0",
        "resources page. The European Commission logo is excluded from",
        "reuse; cybedtools reproduces no logo."
      )
    ),
    notes = list(
      framework_type = "pedagogical digital-competence framework for citizens",
      replaces = "DigComp 2.2 (owner decision D1, 2026-08-21: replace in place, do not keep both). 2.2 raw stays archived at data/raw/digcomp/v2.2/.",
      unit_grain = "2.2 used only the 5 competence areas as cybed:OrganizingUnit, with the 21 competences as cybed:RoleElement. 3.0 moves elements down to the 362 competence statements, so the 21 competences become a second organizing-unit tier (cybed:Competence) alongside the 5 areas (cybed:CompetenceArea) -- 26 organizing units total, matching the 26 IRIs (5 areas + 21 competences) that data/raw/digcomp/v3.0/MAPPING-2.2-to-3.0.md's survival analysis identifies as surviving unchanged from 2.2.",
      cybersec_relevance = paste(
        "Competence Area 4, renamed 'Safety, wellbeing and responsible",
        "use', remains the most cybersec-adjacent: 4.1 Protecting devices,",
        "4.2 Protecting personal data and privacy, 4.3 Supporting",
        "wellbeing, 4.4 Environmental impacts of digital technologies."
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
  message("=== DigComp 3.0 Ingestion (replacing DigComp 2.2 in place) ===")

  source_prov <- read_yaml(file.path(digcomp_config$source_dir, "provenance.yml"))

  jsonld_path <- file.path(digcomp_config$source_dir, digcomp_config$jsonld_filename)
  if (!file.exists(jsonld_path)) stop("Data supplement missing at ", jsonld_path)
  jsonld_sha256 <- digest(file = jsonld_path, algo = "sha256")
  expected_sha256 <- source_prov$retrieval$jsonld_sha256
  if (!identical(jsonld_sha256, expected_sha256)) {
    stop(
      "DigComp 3.0 data supplement hash mismatch.\n  expected: ", expected_sha256,
      "\n  actual:   ", jsonld_sha256,
      "\nThis is a human-review event, not a tolerance to absorb: re-verify ",
      "the staged supplement against data/raw/digcomp/v3.0/provenance.yml ",
      "before re-running."
    )
  }
  message("Data supplement hash verified: ", jsonld_sha256)

  read_source_table <- function(name) {
    read_csv(file.path(digcomp_config$source_tables_dir, paste0(name, ".csv")),
             show_col_types = FALSE)
  }

  areas          <- read_source_table("competence-areas")
  area_descs     <- read_source_table("competence-area-descriptions")
  competences    <- read_source_table("competences")
  comp_descs     <- read_source_table("competence-descriptions")
  statements     <- read_source_table("competence-statements")
  outcomes_raw   <- read_source_table("learning-outcomes")
  proficiency    <- read_source_table("proficiency-levels")
  glossary       <- read_source_table("glossary")

  message("Applying learning-outcome errata (data/raw/digcomp/v3.0/errata.csv)...")
  outcomes <- apply_learning_outcome_errata(outcomes_raw)
  message("  Learning outcomes: ", nrow(outcomes_raw), " staged -> ",
          nrow(outcomes), " after errata")

  tables_dir <- file.path(digcomp_config$staging_dir, digcomp_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(areas,       file.path(tables_dir, "competence-areas.csv"))
  write_csv(area_descs,  file.path(tables_dir, "competence-area-descriptions.csv"))
  write_csv(competences, file.path(tables_dir, "competences.csv"))
  write_csv(comp_descs,  file.path(tables_dir, "competence-descriptions.csv"))
  write_csv(statements,  file.path(tables_dir, "competence-statements.csv"))
  write_csv(outcomes,    file.path(tables_dir, "learning-outcomes.csv"))
  write_csv(proficiency, file.path(tables_dir, "proficiency-levels.csv"))
  write_csv(glossary,    file.path(tables_dir, "glossary.csv"))

  write_provenance_manifest(
    source_prov, jsonld_sha256,
    list(areas = areas, competences = competences, statements = statements,
         outcomes = outcomes, proficiency_levels = proficiency, glossary = glossary)
  )

  message("\n=== Summary ===")
  message("  Competence areas: ",      nrow(areas))
  message("  Competences: ",           nrow(competences))
  message("  Competence statements: ", nrow(statements))
  message("  Learning outcomes: ",     nrow(outcomes), " (post-errata)")
  message("  Proficiency levels staged (not emitted): ", nrow(proficiency))
  message("  Glossary terms staged (not emitted): ",     nrow(glossary))
  message("\nDone.")
}

if (sys.nframe() == 0) {
  main()
}
