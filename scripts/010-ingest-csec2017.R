# 010-ingest-csec2017.R
#
# Ingest the ACM/IEEE CSEC2017 Cybersecurity Curricula Guidelines from the
# Joint Task Force's 2017 PDF.
#
# Source:
#   - CSEC2017-Curricular-Guidelines.pdf
#   - Intermediate: extracted-text.md (via markitdown PDF -> markdown)
#   - Publisher: ACM / IEEE / AIS SIGSEC / IFIP WG 11.8
#   - Published: 31 December 2017, Version 1.0
#
# Licensing: Copyright 2017 ACM/IEEE/AIS/IFIP. Permission granted for
# development of educational materials; other use requires specific
# permission. Analytical derivatives generally publishable with attribution.
#
# Structure (from the PDF):
#   8 Knowledge Areas (KAs): 4.1 Data Security through 4.8 Societal Security
#   Each KA contains: Knowledge Units (KUs), Topics, Essentials, Learning Outcomes
#
# Extraction scope for this ingester (best-effort, marked in provenance):
#   - 8 KAs with their names and defining descriptions
#   - Essentials bulleted lists per KA (clean structural extraction possible)
#   - KUs and Topics: table-flattened in markitdown output; skeleton-only
#     extraction here. Fine-grained learning outcomes live in the source PDF
#     and require manual curation or LLM-assisted pass for full fidelity.
#
# CSEC2017 contributes a higher-education cybersecurity-curriculum
# framework to the supported set, complementing the K-12 learning-standards
# frameworks (Cyber.org, CSTA) and the adult workforce frameworks.
#
# Run: Rscript scripts/010-ingest-csec2017.R

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

csec_config <- list(
  framework_version = "CSEC2017 Curricular Guidelines v1.0",
  version_date      = "2017-12-31",
  publisher         = "ACM / IEEE / AIS SIGSEC / IFIP WG 11.8",
  pdf_filename      = "CSEC2017-Curricular-Guidelines.pdf",
  text_filename     = "extracted-text.md",
  staging_dir       = here("data", "raw", "csec2017"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml",
  license           = "Copyright 2017 ACM/IEEE/AIS/IFIP. Permission granted for educational development."
)

# The 8 Knowledge Areas are a closed vocabulary. Confirmed against PDF.
csec_knowledge_areas <- tibble::tribble(
  ~ka_id,    ~section, ~name,                     ~short_name,
  "KA-DATA", "4.1",    "Data Security",           "Data",
  "KA-SW",   "4.2",    "Software Security",       "Software",
  "KA-COMP", "4.3",    "Component Security",      "Component",
  "KA-CONN", "4.4",    "Connection Security",     "Connection",
  "KA-SYS",  "4.5",    "System Security",         "System",
  "KA-HUM",  "4.6",    "Human Security",          "Human",
  "KA-ORG",  "4.7",    "Organizational Security", "Organizational",
  "KA-SOC",  "4.8",    "Societal Security"        , "Societal"
)

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

#' Extract bulleted Essentials list for each KA
#'
#' The "Essentials" sections follow a consistent pattern: each KA has a block
#' labeled "ESSENTIALS" or "Essentials" followed by a dash-prefixed list of
#' competency essentials. We match this pattern and associate with the KA.
extract_essentials <- function(text_file_path) {
  lines <- read_lines(text_file_path)

  essentials_rows <- list()

  for (i in seq_len(nrow(csec_knowledge_areas))) {
    ka <- csec_knowledge_areas[i, ]

    # Look in the 4.N.1 body section, where Essentials appear as a clean
    # bullet list immediately under an "Essentials" header. TOC entries
    # appear early in the document (< line 500); the body comes later.
    section_marker_1 <- paste0(ka$section, ".1 Knowledge Units and Topics")
    start_candidates <- which(str_detect(lines, fixed(section_marker_1)))
    body_instances <- start_candidates[start_candidates > 500]
    if (length(body_instances) == 0) next
    start <- body_instances[1]

    # End at the next KA's §.N.1 body (or the start of §.N.2)
    stop_marker_2 <- paste0(ka$section, ".2 Essentials and Learning Outcomes")
    stop_candidates <- which(str_detect(lines, fixed(stop_marker_2)))
    stop_body <- stop_candidates[stop_candidates > start]
    end <- if (length(stop_body) > 0) stop_body[1] - 1 else min(start + 500, length(lines))

    section_text <- lines[start:end]

    # Within this section, find the "Essentials" header and collect the
    # bullets between it and the next structural heading.
    essentials_hdr <- which(str_detect(section_text, "^\\s*Essentials\\s*$"))
    if (length(essentials_hdr) == 0) next
    hdr_line <- essentials_hdr[1]

    # Bullets start after the Essentials header; end at the next non-bullet
    # non-empty line that isn't itself an essential continuation.
    bullet_region <- section_text[(hdr_line + 1):length(section_text)]

    # Find the first "Topics" header or "Knowledge Units" heading that ends
    # the bullet region.
    end_of_bullets <- which(str_detect(bullet_region,
      "^\\s*(Topics|Knowledge\\s+Units|Description/Curricular)"))
    if (length(end_of_bullets) > 0) {
      bullet_region <- bullet_region[1:(end_of_bullets[1] - 1)]
    }

    bullets <- bullet_region |>
      str_extract("^\\s*[●•*\\-]\\s+(.+)$", group = 1) |>
      discard(is.na) |>
      str_squish() |>
      keep(\(x) nchar(x) > 10)

    if (length(bullets) == 0) next

    for (j in seq_along(bullets)) {
      essentials_rows[[length(essentials_rows) + 1]] <- tibble(
        element_id     = paste0(ka$ka_id, "-E", sprintf("%02d", j)),
        ka_id          = ka$ka_id,
        ka_section     = ka$section,
        ka_name        = ka$name,
        element_type   = "Essential",
        element_text   = bullets[j] |> str_remove(",\\s*$")
      )
    }
  }

  bind_rows(essentials_rows)
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(pdf_path, text_path, kas, essentials) {
  manifest <- list(
    framework         = "CSEC2017",
    framework_version = csec_config$framework_version,
    version_date      = csec_config$version_date,
    source = list(
      type            = "pdf_with_markdown_intermediate",
      publisher       = csec_config$publisher,
      pdf_filename    = csec_config$pdf_filename,
      text_filename   = csec_config$text_filename,
      conversion_tool = "markitdown MCP (PDF -> markdown)"
    ),
    retrieval = list(
      retrieved_date  = format(Sys.Date(), "%Y-%m-%d"),
      retrieved_by    = "scripts/010-ingest-csec2017.R",
      pdf_size_bytes  = if (file.exists(pdf_path)) file.info(pdf_path)$size else NA_integer_,
      pdf_sha256      = if (file.exists(pdf_path)) digest(file = pdf_path, algo = "sha256") else NA_character_,
      text_sha256     = digest(file = text_path, algo = "sha256")
    ),
    extraction = list(
      knowledge_areas     = nrow(kas),
      essentials_total    = nrow(essentials),
      essentials_by_ka    = essentials |> count(ka_id) |> deframe() |> as.list(),
      extraction_scope    = "best-effort: KAs + Essentials bullets. KU/Topic/Learning-Outcome level not automated."
    ),
    licensing = list(
      source_license = csec_config$license,
      redistribution_note = paste(
        "ACM/IEEE/AIS/IFIP copyright. Permission granted for educational",
        "development. Analytical derivatives generally publishable with",
        "attribution. Request permission before redistributing source text",
        "in a commercial offering."
      )
    ),
    notes = list(
      framework_type = "higher-education curriculum guideline",
      extraction_limitations = paste(
        "Markitdown PDF conversion flattens KU+Topic tables into interleaved",
        "bullets. This ingester extracts 8 KAs + Essentials. Full KU/Topic/LO",
        "structure requires manual curation or LLM-assisted extraction pass.",
        "Future: add scripts/010-ingest-csec2017-deep.R once that path exists."
      )
    )
  )

  manifest_path <- file.path(csec_config$staging_dir, csec_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== CSEC2017 Ingestion ===")

  pdf_path  <- file.path(csec_config$staging_dir, csec_config$pdf_filename)
  text_path <- file.path(csec_config$staging_dir, csec_config$text_filename)

  if (!file.exists(text_path)) stop("Extracted markdown missing at ", text_path)

  message("Extracting Essentials per Knowledge Area...")
  essentials <- extract_essentials(text_path)
  message("  Essentials extracted: ", nrow(essentials))

  tables_dir <- file.path(csec_config$staging_dir, csec_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(csec_knowledge_areas, file.path(tables_dir, "knowledge-areas.csv"))
  write_csv(essentials,           file.path(tables_dir, "essentials.csv"))

  write_provenance_manifest(pdf_path, text_path, csec_knowledge_areas, essentials)

  message("\n=== Summary ===")
  message("  Knowledge Areas: ", nrow(csec_knowledge_areas))
  message("  Essentials: ", nrow(essentials))
  cat("\nEssentials by KA:\n")
  print(essentials |> count(ka_id, ka_name))
  message("\nDone.")
}

if (sys.nframe() == 0) {
  main()
}
