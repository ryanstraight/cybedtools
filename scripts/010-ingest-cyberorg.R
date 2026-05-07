# 010-ingest-cyberorg.R
#
# Ingest the CYBER.ORG K-12 Cybersecurity Learning Standards v1.0 from the
# public PDF distribution.
#
# Source:
#   - PDF: K-12-Cybersecurity-Learning-Standards-v1.0.pdf (staged manually).
#   - Intermediate: extracted-text.md (via markitdown PDF -> markdown).
#   - Publication: CYBER.ORG + Cyber Innovation Center, 2021-08-04.
#
# License: CC BY-NC 4.0. Attribution required; non-commercial use. Toolkit
# release must respect the non-commercial clause; do not redistribute
# standard text in a commercial offering.
#
# Structure (from the PDF):
#   3 themes: Computing Systems (CS), Digital Citizenship (DC), Security (SEC)
#   29 sub-concepts across themes (e.g., CS.COMM, DC.ETH, SEC.ACC)
#   4 grade bands: K-2, 3-5, 6-8, 9-12
#   Each grade-band x sub-concept cell has 1-3 standards (~130-150 total).
#
# Standard ID format: {grade_band}.{theme}.{sub_code}[.{sequence}]
#   Examples: K-2.SEC.ACC, 6-8.CS.COMM.1, 9-12.DC.PPI.2
#
# Cyber.org K-12 differs from the workforce frameworks in two important
# respects: it is a learning-standards framework rather than a competency
# framework, and it targets K-12 learners rather than the adult workforce.
# Including it exercises the cross-type portability of the cybed: schema.
#
# Run: Rscript scripts/010-ingest-cyberorg.R

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

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

cyberorg_config <- list(
  framework_version = "Cyber.org K-12 Learning Standards v1.0",
  version_date      = "2021-09-09",
  original_release  = "2021-08-04",
  publisher         = "CYBER.ORG & Cyber Innovation Center",
  pdf_filename      = "K-12-Cybersecurity-Learning-Standards-v1.0.pdf",
  text_filename     = "extracted-text.md",
  staging_dir       = here("data", "raw", "cyberorg-k12"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml",
  license           = "CC BY-NC 4.0"
)

# Grade bands and themes (closed vocabulary per the standards document)
cyberorg_grade_bands <- c("K-2", "3-5", "6-8", "9-12")
cyberorg_themes <- c("CS", "DC", "SEC")

# Sub-concept taxonomy derived from the standards document.
# Theme -> named list of sub-concepts with their human-readable names.
cyberorg_sub_concepts <- list(
  CS = c(
    COMM = "Communication and Networking",
    HARD = "Hardware",
    SOFT = "Software",
    APPS = "Applications",
    CC   = "Cloud Computing",
    COMP = "Components",
    IOT  = "Internet of Things",
    LOSS = "Loss",
    OS   = "Operating Systems",
    PROG = "Programming",
    PROT = "Protocols"
  ),
  DC = c(
    AUP  = "Acceptable Use Policy",
    CYBL = "Cyberbullying",
    ETH  = "Ethics",
    FOOT = "Digital Footprint",
    IP   = "Intellectual Property",
    LAW  = "Law",
    PPI  = "Personally Identifiable Information",
    THRT = "Threats and Scams"
  ),
  SEC = c(
    ACC  = "Access Control",
    AUTH = "Authentication",
    CIA  = "Confidentiality, Integrity, Availability",
    COMP = "Compromise",
    CRYP = "Cryptography",
    CTRL = "Controls",
    DATA = "Data",
    INFO = "Information Security",
    NET  = "Network Security",
    PHYS = "Physical Security"
  )
)

# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------

#' Standard ID regex
#'
#' Matches patterns like K-2.SEC.ACC, 6-8.CS.COMM.1, 9-12.DC.PPI.2.
standard_id_regex <- "(K-2|3-5|6-8|9-12)\\.(CS|DC|SEC)\\.([A-Z]+[A-Z0-9]*?)(?:\\.(\\d+))?"

#' Extract standard IDs and their following text from the converted markdown
#'
#' Strategy: find every line matching a standard ID pattern, split text at
#' those boundaries, then clean the captured text (remove page markers,
#' line wraps, bullet characters).
#'
#' @param text_file_path Character path to the markitdown output.
#' @return Tibble with columns: standard_id, grade_band, theme, sub_concept,
#'   sequence, statement_text, source_line.
extract_standards <- function(text_file_path) {
  all_lines <- read_lines(text_file_path)

  # Index every line that contains a standard ID pattern.
  # Store the first match per line; multi-match lines are rare in this doc.
  matches_per_line <- str_extract_all(all_lines, standard_id_regex)

  # Collect locations where a standard starts
  locations <- tibble(
    line_num = seq_along(all_lines),
    matched  = map_chr(matches_per_line, \(m) if (length(m) > 0) m[[1]] else NA_character_)
  ) |>
    filter(!is.na(matched))

  # Filter out TOC-like references (very short lines that only contain the ID
  # followed by a page number, or lines that are section headers with just
  # the code). Heuristic: require that the line OR the next line contains
  # enough text to constitute a standard description.
  keep_flags <- locations$line_num |>
    map_lgl(\(ln) {
      surrounding <- all_lines[ln:min(ln + 2, length(all_lines))] |>
        paste(collapse = " ")
      nchar(surrounding) > 60  # filter out bare TOC entries
    })
  locations <- locations |> filter(keep_flags)

  # For each standard, capture text from this match line up to (but not
  # including) the next standard boundary or section break.
  standards <- locations |>
    mutate(
      next_line_num = lead(line_num, default = length(all_lines) + 1),
      raw_block     = pmap_chr(
        list(line_num, next_line_num),
        \(start, finish) {
          paste(all_lines[start:(finish - 1)], collapse = " ")
        }
      )
    )

  # Grade-band / section-header patterns that often leak into the captured
  # text when one standard ends and the next section begins. Truncate the
  # statement at the first of these.
  section_cutoff_pattern <- paste0(
    "(?i)\\s*(?:Kindergarten|\\d+(?:st|nd|rd|th))[\\s–—-]*",
    "(?:Grade)?[\\s–—-]*\\d*(?:st|nd|rd|th)?[\\s]*Grade.*$"
  )

  # Sub-concept header artifacts (e.g., "Programming and Scripting (PROG)")
  subconcept_header_pattern <- paste0(
    "\\s+(?:",
    paste(
      c(names(cyberorg_sub_concepts$CS),
        names(cyberorg_sub_concepts$DC),
        names(cyberorg_sub_concepts$SEC)),
      collapse = "|"
    ),
    ")\\s*\\)[^.]*$"
  )

  standards <- standards |>
    mutate(
      statement_text = raw_block |>
        # Remove the leading ID (it's captured separately in matched)
        str_remove(paste0("^[\\s•‣◦*-]*",
                          str_replace_all(matched, "[.-]", "[.-]"))) |>
        # Remove "Ver. 1.0" page footer artifacts
        str_remove_all("Ver\\.\\s*1\\.0") |>
        # Remove bullet chars
        str_replace_all("[•‣◦*]", " ") |>
        # Collapse whitespace first so cutoff patterns match reliably
        str_squish() |>
        # Cut at trailing sub-concept-header artifact
        str_remove(subconcept_header_pattern) |>
        # Cut at trailing grade-band header
        str_remove(section_cutoff_pattern) |>
        # Cut at the start of the Glossary of Terms (document-final marker)
        str_remove("(?i)\\s*Glossary\\s+of\\s+Terms.*$") |>
        # Remove trailing page-number-like runs
        str_remove("\\s+\\d{1,3}\\s*$") |>
        # Final whitespace collapse
        str_squish()
    )

  # Parse components from ID
  parsed <- standards |>
    mutate(
      standard_id   = matched,
      components    = str_match(matched, standard_id_regex)
    ) |>
    mutate(
      grade_band    = components[, 2],
      theme         = components[, 3],
      sub_concept   = components[, 4],
      sequence      = suppressWarnings(as.integer(components[, 5]))
    ) |>
    select(
      standard_id, grade_band, theme, sub_concept, sequence,
      statement_text, source_line = line_num
    )

  # Deduplicate: keep first occurrence per standard_id where statement_text
  # is non-trivial. Some IDs appear in the overview section with short
  # summaries and again in the main body with full text; prefer the longer.
  parsed |>
    group_by(standard_id) |>
    slice_max(nchar(statement_text), n = 1, with_ties = FALSE) |>
    ungroup() |>
    arrange(grade_band, theme, sub_concept, sequence)
}

#' Build the sub-concept catalog (29 rows)
build_subconcept_catalog <- function() {
  cyberorg_sub_concepts |>
    imap_dfr(\(subs, theme_code) {
      tibble(
        theme       = theme_code,
        sub_concept = names(subs),
        sub_concept_name = unname(subs)
      )
    })
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(pdf_path, text_path, standards_df, subconcepts_df) {
  manifest <- list(
    framework         = "Cyber.org K-12",
    framework_version = cyberorg_config$framework_version,
    original_release  = cyberorg_config$original_release,
    version_date      = cyberorg_config$version_date,
    source = list(
      type            = "pdf_with_markdown_intermediate",
      publisher       = cyberorg_config$publisher,
      pdf_filename    = cyberorg_config$pdf_filename,
      text_filename   = cyberorg_config$text_filename,
      conversion_tool = "markitdown MCP (PDF -> markdown)"
    ),
    retrieval = list(
      retrieved_date  = format(Sys.Date(), "%Y-%m-%d"),
      retrieved_by    = "scripts/010-ingest-cyberorg.R",
      pdf_size_bytes  = if (file.exists(pdf_path)) file.info(pdf_path)$size else NA_integer_,
      pdf_sha256      = if (file.exists(pdf_path)) digest(file = pdf_path, algo = "sha256") else NA_character_,
      text_size_bytes = file.info(text_path)$size,
      text_sha256     = digest(file = text_path, algo = "sha256")
    ),
    extraction = list(
      grade_bands          = length(cyberorg_grade_bands),
      themes               = length(cyberorg_themes),
      sub_concepts         = nrow(subconcepts_df),
      standards_total      = nrow(standards_df),
      standards_by_band    = standards_df |> count(grade_band) |> deframe() |> as.list(),
      standards_by_theme   = standards_df |> count(theme) |> deframe() |> as.list()
    ),
    licensing = list(
      source_license = cyberorg_config$license,
      redistribution_note = paste(
        "CC BY-NC 4.0 permits non-commercial redistribution with attribution.",
        "Toolkit release MUST NOT include standard text in any commercial",
        "offering. Analytical derivatives (code frequencies, cross-framework",
        "mappings) are safe to publish with attribution."
      )
    ),
    notes = list(
      framework_type = "pedagogical learning standards (not a workforce competency framework)",
      cybed_mapping_hint = paste(
        "Each grade_band x sub_concept cell functions as a cybed:Role analog.",
        "Each standard statement is a cybed:RoleElement."
      )
    )
  )

  manifest_path <- file.path(cyberorg_config$staging_dir, cyberorg_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== Cyber.org K-12 Standards Ingestion ===")

  pdf_path  <- file.path(cyberorg_config$staging_dir, cyberorg_config$pdf_filename)
  text_path <- file.path(cyberorg_config$staging_dir, cyberorg_config$text_filename)

  if (!file.exists(text_path)) {
    stop("Extracted markdown missing at ", text_path,
         ". Run markitdown PDF->markdown conversion first.")
  }

  message("Parsing standards from text...")
  standards_df <- extract_standards(text_path)
  message("  Standards extracted: ", nrow(standards_df))

  message("Building sub-concept catalog...")
  subconcepts_df <- build_subconcept_catalog()
  message("  Sub-concepts: ", nrow(subconcepts_df))

  tables_dir <- file.path(cyberorg_config$staging_dir, cyberorg_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(standards_df,   file.path(tables_dir, "standards.csv"))
  write_csv(subconcepts_df, file.path(tables_dir, "sub-concepts.csv"))

  message("Writing provenance manifest...")
  write_provenance_manifest(pdf_path, text_path, standards_df, subconcepts_df)

  message("\n=== Summary ===")
  message("  Standards: ", nrow(standards_df))
  message("  Grade-band breakdown:")
  print(standards_df |> count(grade_band))
  message("  Theme breakdown:")
  print(standards_df |> count(theme))
  message("\nOutput: ", tables_dir)
  message("Done.")

  invisible(list(
    standards_df   = standards_df,
    subconcepts_df = subconcepts_df
  ))
}

if (sys.nframe() == 0) {
  main()
}
