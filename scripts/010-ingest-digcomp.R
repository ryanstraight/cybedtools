# 010-ingest-digcomp.R
#
# Ingest the European Digital Competence Framework for Citizens (DigComp 2.2)
# from the JRC Publications Office PDF.
#
# Source:
#   - DigComp-2.2-JRC128415.pdf (JRC Publications Repository JRC128415)
#   - Intermediate: extracted-text.md (via markitdown)
#   - Publisher: European Commission Joint Research Centre (JRC)
#   - Published: 2022-03-17, Version 2.2
#
# Licensing: EU open re-use policy. Verify specific terms at JRC Publications
# Repository before redistribution. Analytical derivatives publishable with
# attribution.
#
# Structure (confirmed from extracted TOC):
#   5 competence areas:
#     1. Information and data literacy (3 competences)
#     2. Communication and collaboration (6 competences)
#     3. Digital content creation (4 competences)
#     4. Safety (4 competences)  -- cybersec-relevant area
#     5. Problem solving (4 competences)
#   21 competences total (numbered X.Y format).
#   Each competence has 8 proficiency levels with descriptors.
#
# Extraction scope for this ingester (best-effort):
#   - 5 Competence Areas as structural roots
#   - 21 Competences with their descriptive titles
#   - Proficiency-level descriptors NOT automated (fragmented in markitdown
#     output across multiple columns). Marked as future enrichment.
#
# DigComp rounds out the EU-side pedagogical coverage as a citizen-oriented
# digital-competence framework, complementing ECSF on the workforce side.
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

digcomp_config <- list(
  framework_version = "DigComp 2.2",
  version_date      = "2022-03-17",
  publisher         = "European Commission Joint Research Centre (JRC)",
  pdf_filename      = "DigComp-2.2-JRC128415.pdf",
  text_filename     = "extracted-text.md",
  staging_dir       = here("data", "raw", "digcomp"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml",
  license           = "EU open re-use (verify specific terms before redistribution)"
)

# Closed vocabulary of 5 competence areas and 21 competences.
# Hand-curated from the DigComp 2.2 TOC (verified 2026-04-23).
digcomp_areas <- tibble::tribble(
  ~area_id,       ~area_number, ~area_name,
  "AREA-INFO",    1,            "Information and data literacy",
  "AREA-COMM",    2,            "Communication and collaboration",
  "AREA-CONTENT", 3,            "Digital content creation",
  "AREA-SAFETY",  4,            "Safety",
  "AREA-PROB",    5,            "Problem solving"
)

digcomp_competences <- tibble::tribble(
  ~competence_id, ~area_id,       ~competence_name,
  "1.1", "AREA-INFO",    "Browsing, searching and filtering data, information and digital content",
  "1.2", "AREA-INFO",    "Evaluating data, information and digital content",
  "1.3", "AREA-INFO",    "Managing data, information and digital content",
  "2.1", "AREA-COMM",    "Interacting through digital technologies",
  "2.2", "AREA-COMM",    "Sharing through digital technologies",
  "2.3", "AREA-COMM",    "Engaging citizenship through digital technologies",
  "2.4", "AREA-COMM",    "Collaborating through digital technologies",
  "2.5", "AREA-COMM",    "Netiquette",
  "2.6", "AREA-COMM",    "Managing digital identity",
  "3.1", "AREA-CONTENT", "Developing digital content",
  "3.2", "AREA-CONTENT", "Integrating and re-elaborating digital content",
  "3.3", "AREA-CONTENT", "Copyright and licences",
  "3.4", "AREA-CONTENT", "Programming",
  "4.1", "AREA-SAFETY",  "Protecting devices",
  "4.2", "AREA-SAFETY",  "Protecting personal data and privacy",
  "4.3", "AREA-SAFETY",  "Protecting health and well-being",
  "4.4", "AREA-SAFETY",  "Protecting the environment",
  "5.1", "AREA-PROB",    "Solving technical problems",
  "5.2", "AREA-PROB",    "Identifying needs and technological responses",
  "5.3", "AREA-PROB",    "Creatively using digital technology",
  "5.4", "AREA-PROB",    "Identifying digital competence gaps"
)

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

#' Extract the descriptive paragraph following each competence header in the
#' body of the framework document.
#'
#' DigComp 2.2 has section blocks like "1.1 Browsing, searching..." as the
#' body heading, followed by a descriptive paragraph. We locate the body
#' instance (not the TOC entry) and take the first non-trivial paragraph.
extract_competence_descriptions <- function(text_file_path) {
  lines <- read_lines(text_file_path)

  description_rows <- list()

  for (i in seq_len(nrow(digcomp_competences))) {
    comp <- digcomp_competences[i, ]

    # Build header pattern for both TOC and body. The body usually has
    # "X.Y CompetenceName" followed by descriptive paragraphs.
    # Body instances appear after line 400 (past TOC and intro).
    heading_pattern <- paste0("^", str_replace_all(comp$competence_id, "\\.", "\\\\."),
                              "\\s+")
    matches <- which(str_detect(lines, heading_pattern))
    body_matches <- matches[matches > 400]

    description <- NA_character_

    if (length(body_matches) > 0) {
      start <- body_matches[1]
      # Grab the next ~30 lines, skipping blanks, take first non-trivial
      window <- lines[start:min(start + 30, length(lines))]
      # Remove the heading line itself
      window <- window[-1]
      # Filter blanks and trivial lines
      non_blank <- window[str_trim(window) != "" &
                           str_length(str_trim(window)) > 30]
      if (length(non_blank) > 0) {
        description <- non_blank[1] |> str_squish()
      }
    }

    description_rows[[i]] <- tibble(
      element_id       = paste0("COMP-", comp$competence_id),
      competence_id    = comp$competence_id,
      area_id          = comp$area_id,
      competence_name  = comp$competence_name,
      description      = description
    )
  }

  bind_rows(description_rows)
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(pdf_path, text_path, areas, competences, descriptions) {
  manifest <- list(
    framework         = "DigComp",
    framework_version = digcomp_config$framework_version,
    version_date      = digcomp_config$version_date,
    source = list(
      type            = "pdf_with_markdown_intermediate",
      publisher       = digcomp_config$publisher,
      pdf_filename    = digcomp_config$pdf_filename,
      text_filename   = digcomp_config$text_filename,
      jrc_id          = "JRC128415",
      conversion_tool = "markitdown MCP (PDF -> markdown)"
    ),
    retrieval = list(
      retrieved_date  = format(Sys.Date(), "%Y-%m-%d"),
      retrieved_by    = "scripts/010-ingest-digcomp.R",
      pdf_size_bytes  = if (file.exists(pdf_path)) file.info(pdf_path)$size else NA_integer_,
      pdf_sha256      = if (file.exists(pdf_path)) digest(file = pdf_path, algo = "sha256") else NA_character_,
      text_sha256     = digest(file = text_path, algo = "sha256")
    ),
    extraction = list(
      competence_areas    = nrow(areas),
      competences         = nrow(competences),
      descriptions_found  = sum(!is.na(descriptions$description)),
      extraction_scope    = "best-effort: areas + competences (hand-curated from TOC) + first-paragraph description. Proficiency-level descriptors not automated."
    ),
    licensing = list(
      source_license = digcomp_config$license,
      redistribution_note = paste(
        "JRC publications are generally open. Verify specific terms at the",
        "JRC Publications Repository (publications.jrc.ec.europa.eu) before",
        "redistributing framework text in toolkit releases. Analytical",
        "derivatives publishable with attribution."
      )
    ),
    notes = list(
      framework_type = "pedagogical digital-competence framework for citizens",
      extraction_limitations = paste(
        "Markitdown PDF conversion produces column-flattened output.",
        "Hand-curated 5 areas + 21 competences from the TOC; body",
        "descriptions extracted as first substantial paragraph after each",
        "competence heading. Full proficiency-level descriptors (8 levels",
        "per competence) would require manual curation or table-aware PDF",
        "extraction (Tabula, pdfplumber) on the original PDF."
      ),
      cybersec_relevance = paste(
        "Competence Area 4 (Safety) is the most cybersec-adjacent: 4.1",
        "Protecting devices, 4.2 Protecting personal data and privacy,",
        "4.3 Protecting health and well-being, 4.4 Protecting the",
        "environment. The schema represents all 21 competences across",
        "all five areas, not only the cybersec-relevant Safety area."
      )
    )
  )

  manifest_path <- file.path(digcomp_config$staging_dir, digcomp_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== DigComp 2.2 Ingestion ===")

  pdf_path  <- file.path(digcomp_config$staging_dir, digcomp_config$pdf_filename)
  text_path <- file.path(digcomp_config$staging_dir, digcomp_config$text_filename)

  if (!file.exists(text_path)) stop("Extracted markdown missing at ", text_path)

  message("Extracting competence descriptions...")
  descriptions <- extract_competence_descriptions(text_path)
  message("  Descriptions located: ", sum(!is.na(descriptions$description)), " / ",
          nrow(descriptions))

  tables_dir <- file.path(digcomp_config$staging_dir, digcomp_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(digcomp_areas,       file.path(tables_dir, "competence-areas.csv"))
  write_csv(digcomp_competences, file.path(tables_dir, "competences.csv"))
  write_csv(descriptions,        file.path(tables_dir, "competence-descriptions.csv"))

  write_provenance_manifest(pdf_path, text_path, digcomp_areas, digcomp_competences, descriptions)

  message("\n=== Summary ===")
  message("  Competence areas: ", nrow(digcomp_areas))
  message("  Competences: ",      nrow(digcomp_competences))
  message("  Descriptions: ",     sum(!is.na(descriptions$description)))
  message("\nDone.")
}

if (sys.nframe() == 0) {
  main()
}
