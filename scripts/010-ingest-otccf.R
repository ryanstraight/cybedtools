# 010-ingest-otccf.R
#
# Ingest the Operational Technology Cybersecurity Competency Framework (OTCCF)
# from the Cyber Security Agency of Singapore (CSA) PDF.
#
# Source:
#   - OT-Cybersecurity-Competency-Framework_V5.pdf (113 pages)
#   - Intermediate: extracted-text.md (pdftools::pdf_text, page markers)
#   - Publisher: Cyber Security Agency of Singapore (CSA)
#   - Document self-description: "version 1.1", Effective Date 8 October 2021
#   - Jointly developed by CSA and Mercer Singapore, supported by SkillsFuture
#     Singapore (SSG) and Infocomm Media Development Authority (IMDA)
#
# Licensing: Copyright Cyber Security Agency of Singapore. CSA granted written
# permission on 2026-09-15 to reference and integrate the OTCCF structure for
# non-commercial academic and research purposes, on two conditions: a fixed
# attribution string (reproduced verbatim in the manifest), and that ingestion
# scripts and structural mappings must not misrepresent or alter the intent of
# the OTCCF's job roles, skills, or competency mappings as published by CSA.
#
# Fidelity is therefore a licence condition, not a style preference. This
# ingester copies source text verbatim. It does not paraphrase, merge, re-level,
# summarise, or silently correct the source. Source typographical errors are
# preserved as published. The only edits applied are PDF extraction artifact
# repairs, each enumerated in the manifest under notes$repair_rules.
#
# Structure (observed in the PDF, not assumed):
#   Section 2 Career Map (p4)   5 tracks, 16 boxes (15 with skills maps + CISO)
#   Section 3 Skills Map (p5 to p48)  15 job roles, each with:
#       Track, Occupation, Job Role, Job Role Description,
#       Critical Work Functions -> Key Tasks (nested),
#       Performance Expectations (for legislated/regulated occupations),
#       Technical Skills & Competencies with a required proficiency level,
#       Critical Core Skills with a Basic/Intermediate/Advanced level.
#   Section 4 TSC (p49 to p112)  30 TSCs, each with:
#       TSC Category, TSC Title, TSC Description,
#       a six-column proficiency grid (Level 1 to Level 6, sparsely populated),
#       per-level TSC Proficiency Description, Knowledge, Abilities,
#       and on ten TSCs a full width "Range of Application" row, of which
#       three carry content.
#   p113 Queries & Feedback contact page.
#
# SkillsFuture provenance: eight TSCs carry a "#" marker on the TSC Title, and
# the pages carrying them footnote "#Extracted from SkillsFuture ICT Framework".
# SkillsFuture Singapore is a separate body from CSA, so those eight are flagged
# with skillsfuture_derived = TRUE in tscs.csv.
#
# Identifiers: CSA publishes no codes for tracks, roles, or TSCs. Every key in
# these tables is a package-generated slug and is named accordingly
# (track_slug, role_slug, tsc_slug) so that no column can be mistaken for a
# CSA identifier.
#
# Run: Rscript scripts/010-ingest-otccf.R

suppressPackageStartupMessages({
  library(here)
  library(pdftools)
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

otccf_config <- list(
  framework          = "OTCCF",
  framework_name     = "Operational Technology Cybersecurity Competency Framework",
  framework_version  = "1.1",
  framework_date     = "2021-10-08",
  publisher          = "Cyber Security Agency of Singapore (CSA)",
  pdf_filename       = "OT-Cybersecurity-Competency-Framework_V5.pdf",
  text_filename      = "extracted-text.md",
  staging_dir        = here("data", "raw", "otccf"),
  tables_subdir      = "tables",
  manifest_filename  = "provenance.yml",
  landing_page       = "https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/",
  # Page ranges are observed from the document, verified by the structural scan
  # below rather than trusted blindly.
  skills_map_pages   = 5:48,
  tsc_pages          = 49:112,
  # Row clustering tolerance in PDF points. Bullet glyphs sit up to 5pt above
  # their first text line, so rows within 5pt are one logical line.
  row_tol            = 5,
  # Vertical gap in points above which two lines in the same column belong to
  # different elements.
  element_gap        = 20
)

# Verbatim notices located by a full-document scan for copyright, terms, reuse,
# and SkillsFuture provenance language. Reproduced exactly as published.
otccf_notices <- tibble::tribble(
  ~notice_type,            ~pages,                                    ~text_verbatim,
  "copyright",             "1 to 113 (every page footer)",            "© Cyber Security Agency of Singapore",
  "effective_date_footer", "1 to 113 (every page footer)",            "Effective Date: 8 October 2021 version 1.1",
  "disclaimer",            "7, 10, 15, 17, 20, 23, 26, 29, 32, 35, 38, 40, 43, 46, 50, 52, 54, 57, 59, 61, 63, 65, 67, 69, 71, 74, 76, 78, 80, 82, 84, 86, 88, 90, 92, 95, 97, 99, 101, 104, 106, 108, 110, 112", "The information contained in this document serves as a guide.",
  "skillsfuture_footnote", "97, 99, 101, 104, 106, 108, 110, 112",    "#Extracted from SkillsFuture ICT Framework",
  "development_credit",    "3",                                       "The OTCCF - jointly developed by CSA and Mercer Singapore, and supported by SkillsFuture Singapore (SSG) and Infocomm Media Development Authority (IMDA) - maps out the various OT cybersecurity job roles and the corresponding technical skills and core competencies required.",
  "critical_core_skills_pointer", "3",                                "*See https://www.skillsfuture.gov.sg/skills-framework/criticalcoreskills",
  "critical_core_skills_classification", "3",                         "(ii) Critical Core Skills (previously known as Generic Skills and Competencies) *."
)

# Running header, footers, and page furniture that bleed into the text layer.
# Rows matching any of these are dropped before parsing.
otccf_furniture <- c(
  "^OPERATIONAL TECHNOLOGY CYBERSECURITY COMPETENCY FRAMEWORK$",
  "^© Cyber Security Agency of Singapore$",
  "^Effective Date: 8 October 2021 version 1\\.1",
  "^Page [0-9]+$",
  "^The information contained in this document serves as a guide\\.$",
  "^# ?Extracted from SkillsFuture ICT Framework$"
)

# Repair rule L6. The "Performance Expectations (for legislated/regulated
# occupations)" column header wraps onto three lines that straddle the header
# row of the role table, so fragments of it fall inside the content region.
# Rows matching a header fragment within 45pt of the header row are dropped.
otccf_role_header_bits <- c(
  "^Critical Work Functions$", "^Critical Work$", "^Key Task$",
  "^Performance$", "^Performance Expectations.*$", "^Expectations \\(for$",
  "^\\(for$", "^legislated/regulated.*$", "^occupations\\)$"
)

# The skills maps and the TSC catalogue name several competencies differently.
# CSA published both spellings; neither is corrected here. This alias table only
# records which catalogue entry a skills-map listing points at, so that the
# role-to-TSC foreign key resolves. Both strings are retained in the output:
# role-tsc-map.csv keeps the skills-map spelling in tsc_title_as_listed and the
# catalogue spelling is reachable through tsc_slug. Populated from the observed
# unresolved set; see the integrity report if the document is ever revised.
otccf_title_aliases <- c(
  # skills map spelling                              = TSC catalogue spelling
  "Access and Control Management"                    = "Access Control Management",
  "OT Cybersecurity Risk Assessment and Mitigation"  = "OT Cyber Risk Assessment and Mitigation",
  "Vulnerability Assessments"                        = "Vulnerability Assessment",
  "OT Products and Solutions Evaluation"             = "OT Products and Solutions Security Evaluation",
  "OT Cyber Incident Response and Management"        = "Cyber Incident Response and Management",
  "OT Cyber Forensics"                               = "Cyber Forensics"
)

# ---------------------------------------------------------------------------
# Low level text helpers
# ---------------------------------------------------------------------------

#' Normalise PDF ligatures and stray control characters
#'
#' Repair rule L1. Ligature glyphs are an encoding artifact of the PDF font,
#' not authored characters, so expanding them does not alter the source text.
#'
#' @param x Character vector.
#' @return Character vector.
repair_ligatures <- function(x) {
  x |>
    str_replace_all("ﬀ", "ff") |>
    str_replace_all("ﬁ", "fi") |>
    str_replace_all("ﬂ", "fl") |>
    str_replace_all("ﬃ", "ffi") |>
    str_replace_all("ﬄ", "ffl") |>
    str_replace_all("ﬅ", "st") |>
    str_replace_all("ﬆ", "st") |>
    str_replace_all(" ", " ")
}

#' Join a run of PDF words into a single line of text
#'
#' Uses the pdf_data space flag, falling back to a positional gap test, so that
#' glyph runs split by the font engine are not glued together.
#'
#' @param words Tibble of pdf_data words for one row of one column, x ordered.
#' @return Character scalar.
join_words <- function(words) {
  if (nrow(words) == 0) return("")
  # Superscript markers such as the SkillsFuture "#" sit on a higher baseline,
  # so reading order has to be established by x, never by the incoming order.
  words <- words[order(words$x), , drop = FALSE]
  if (nrow(words) == 1) return(words$text[1])
  gaps <- words$x[-1] - (words$x[-nrow(words)] + words$width[-nrow(words)])
  sep  <- ifelse(words$space[-nrow(words)] | gaps > 3, " ", "")
  paste0(paste0(words$text[-nrow(words)], sep, collapse = ""), words$text[nrow(words)])
}

#' Join wrapped lines of one element into a single string
#'
#' Repair rule L2. A line ending in a hyphen followed by a lower case
#' continuation is a hyphenated compound broken by the line box, so the two
#' fragments are rejoined with the hyphen intact and no inserted space.
#' Repair rule L3. All other line breaks inside an element become one space,
#' and runs of whitespace are collapsed.
#'
#' @param lines Character vector of line texts in reading order.
#' @return Character scalar.
join_lines <- function(lines) {
  lines <- lines[str_squish(lines) != ""]
  if (length(lines) == 0) return("")
  out <- lines[1]
  for (i in seq_along(lines)[-1]) {
    nxt <- lines[i]
    if (str_detect(out, "-$") && str_detect(nxt, "^[a-z]")) {
      out <- paste0(out, nxt)
    } else {
      out <- paste(out, nxt)
    }
  }
  str_squish(out)
}

#' Strip a leading bullet glyph
#'
#' Repair rule L4. The bullet is list furniture, not part of the statement.
#'
#' @param x Character vector.
#' @return Character vector.
strip_bullet <- function(x) str_squish(str_remove(x, "^•\\s*"))

#' Package generated slug. Never a CSA identifier.
#'
#' @param x Character vector.
#' @return Character vector of lower case hyphenated slugs.
slugify <- function(x) {
  x |>
    repair_ligatures() |>
    str_replace_all("&", " and ") |>
    str_replace_all("[^A-Za-z0-9]+", "-") |>
    str_remove_all("^-+|-+$") |>
    str_to_lower()
}

# ---------------------------------------------------------------------------
# Page model
# ---------------------------------------------------------------------------

#' Build a word table for every page, clustered into logical rows
#'
#' @param pdf_path Character.
#' @return Tibble: page, row, y, x, width, height, space, text.
build_word_table <- function(pdf_path) {
  pages <- pdf_data(pdf_path)

  pages |>
    imap(\(w, i) {
      if (nrow(w) == 0) return(tibble())
      w <- w |> mutate(text = repair_ligatures(text)) |> arrange(y, x)
      ys  <- sort(unique(w$y))
      grp <- cumsum(c(1L, as.integer(diff(ys) > otccf_config$row_tol)))
      w$row <- setNames(grp, as.character(ys))[as.character(w$y)]
      w$page <- i
      w
    }) |>
    bind_rows() |>
    as_tibble() |>
    drop_furniture_rows()
}

#' Drop page furniture rows (repair rule L5)
#'
#' Applied once, on whole rows, before any column cutting. A row cut into
#' columns no longer matches the footer text, so this has to happen first.
#'
#' @param words Tibble from build_word_table().
#' @return Tibble.
drop_furniture_rows <- function(words) {
  junk <- words |>
    group_by(page, row) |>
    arrange(x, .by_group = TRUE) |>
    summarise(txt = str_squish(join_words(pick(everything()))), .groups = "drop") |>
    filter(map_lgl(txt, \(t) any(str_detect(t, otccf_furniture)))) |>
    select(page, row)
  message("  Furniture rows dropped (headers, footers, page numbers, disclaimer, footnote): ",
          nrow(junk))
  words |> anti_join(junk, by = c("page", "row"))
}

#' Collapse a word table into one text string per (page, row, column band)
#'
#' Repair rule L5. Running headers, copyright and effective date footers, page
#' numbers, the standing disclaimer, and the SkillsFuture footnote are page
#' furniture that bleeds into the text layer between table cells. Rows whose
#' full text matches a furniture pattern are dropped.
#'
#' @param words Tibble from build_word_table().
#' @param col_breaks Numeric vector of column left edges, ascending.
#' @return Tibble: page, row, col, y, text.
rows_by_column <- function(words, col_breaks) {
  if (nrow(words) == 0) {
    return(tibble(page = integer(), row = integer(), col = integer(),
                  y = integer(), text = character()))
  }
  # Columns are left aligned, so a word belongs to the rightmost column whose
  # left edge is at or before it. A small tolerance absorbs the sub point
  # jitter in bullet and first character placement.
  lefts <- if (length(col_breaks) == 0) 0 else col_breaks - 6
  lefts[1] <- -Inf
  words$col <- findInterval(words$x, lefts)
  words$col[words$col < 1] <- 1L

  # Text lines must be clustered within a column, never across the page. Column
  # baselines are offset from one another by a few points, so a page wide
  # clustering chains neighbouring columns together and interleaves their text.
  words |>
    group_by(page, col) |>
    arrange(y, x, .by_group = TRUE) |>
    mutate(line = {
      uy <- sort(unique(y))
      g  <- cumsum(c(1L, as.integer(diff(uy) > otccf_config$row_tol)))
      setNames(g, as.character(uy))[as.character(y)]
    }) |>
    group_by(page, col, line) |>
    arrange(x, .by_group = TRUE) |>
    summarise(y = min(y), text = join_words(pick(everything())), .groups = "drop") |>
    rename(row = line) |>
    filter(str_squish(text) != "") |>
    arrange(page, y, col)
}

#' Group consecutive lines of one column into elements
#'
#' Two rules mark a new element: a leading bullet glyph, or a vertical gap wider
#' than otccf_config$element_gap. A page turn also starts a new element unless
#' the first line of the new page is an unbulleted continuation inside a
#' bulleted block, in which case it appends to the running element.
#'
#' @param lines Tibble: page, y, text for a single column, document order.
#' @param bulleted Logical. TRUE when the block is a bullet list.
#' @return Tibble: element_index, element_text, pages, lines (list column).
group_into_elements <- function(lines, bulleted) {
  if (nrow(lines) == 0) {
    return(tibble(element_index = integer(), element_text = character(),
                  pages = character(), lines = list()))
  }
  lines <- lines |> arrange(page, y)
  new_el <- logical(nrow(lines))
  new_el[1] <- TRUE
  for (i in seq_along(new_el)[-1]) {
    is_bullet <- str_detect(lines$text[i], "^•")
    same_page <- lines$page[i] == lines$page[i - 1]
    gap_break  <- same_page && (lines$y[i] - lines$y[i - 1]) > otccf_config$element_gap
    if (bulleted) {
      new_el[i] <- is_bullet
    } else {
      new_el[i] <- is_bullet || gap_break || !same_page
    }
  }
  lines$el <- cumsum(new_el)

  lines |>
    group_by(el) |>
    summarise(
      element_text = strip_bullet(join_lines(text)),
      pages        = paste(sort(unique(page)), collapse = ","),
      lines        = list(text),
      .groups      = "drop"
    ) |>
    filter(element_text != "") |>
    mutate(element_index = row_number()) |>
    select(element_index, element_text, pages, lines)
}

#' Detect column left edges empirically within a table region
#'
#' The role tables are laid out with left aligned cell text, so the distinct
#' left edges of the content are the column anchors. Anchors closer than
#' min_gap points belong to the same column.
#'
#' @param words Tibble of words in the region.
#' @param min_x Numeric. Ignore the label gutter to the left of this.
#' @param min_gap Numeric.
#' @return Numeric vector of column left edges, ascending.
detect_columns <- function(words, min_x = 230, min_gap = 60, min_n = 1) {
  starts <- words |>
    filter(x >= min_x) |>
    group_by(page, row) |>
    arrange(x, .by_group = TRUE) |>
    mutate(gap = as.numeric(x) - lag(as.numeric(x) + as.numeric(width),
                                     default = -Inf)) |>
    filter(gap > 18) |>
    ungroup() |>
    pull(x) |>
    sort()
  if (length(starts) == 0) return(numeric(0))
  grp <- cumsum(c(1L, as.integer(diff(starts) > min_gap)))
  keep <- table(grp) >= min_n
  mins <- tapply(starts, grp, min)
  as.numeric(mins[keep])
}

# ---------------------------------------------------------------------------
# Extraction: intermediate text artifact
# ---------------------------------------------------------------------------

#' Write the page marked plain text intermediate
#'
#' @param pdf_path Character.
#' @param out_path Character.
#' @return Invisible out_path.
write_extracted_text <- function(pdf_path, out_path) {
  pages <- pdf_text(pdf_path)
  chunks <- imap(pages, \(txt, i) {
    c(glue("<!-- PDF PAGE {i} -->"), "", repair_ligatures(txt), "")
  })
  header <- c(
    "# OTCCF extracted text",
    "",
    glue("Source: {basename(pdf_path)}"),
    glue("Extractor: pdftools::pdf_text {utils::packageVersion('pdftools')}"),
    glue("Extracted: {format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')}"),
    "",
    "Verbatim text layer with PDF page markers. Column layout is flattened by",
    "pdf_text; the tidy tables under tables/ are parsed from pdf_data word",
    "coordinates instead, and this file is the human readable cross check.",
    ""
  )
  write_lines(c(header, unlist(chunks)), out_path)
  message("Extracted text written: ", out_path)
  invisible(out_path)
}

# ---------------------------------------------------------------------------
# Extraction: skills maps (job roles)
# ---------------------------------------------------------------------------

#' Locate the first page of each job role skills map
#'
#' @param words Tibble.
#' @return Tibble: page, track, occupation.
find_role_pages <- function(words) {
  words |>
    filter(page %in% otccf_config$skills_map_pages) |>
    group_by(page, row) |>
    arrange(x, .by_group = TRUE) |>
    summarise(first_word = first(text), n_words = n(), .groups = "drop") |>
    filter(first_word == "Track", n_words > 1) |>
    distinct(page) |>
    arrange(page)
}

#' Locate the gutter / content boundary on a role skills map page
#'
#' Role tables vary in indentation from role to role, so no fixed threshold
#' separates the row label gutter from the first content column. The table
#' header row gives the boundary: content begins at the left edge of the
#' "Critical Work Functions" header, less a margin that admits the slightly
#' wider cell text beneath it.
#'
#' @param pg Tibble of words for the role's first page.
#' @return List with min_x and the header row ordinate.
role_gutter <- function(pg) {
  hdr <- pg |>
    group_by(row) |>
    summarise(y = min(y), txt = str_squish(join_words(pick(everything()))),
              .groups = "drop") |>
    filter(str_detect(txt, "\\bKey Task\\b")) |>
    arrange(y) |>
    slice(1)
  stopifnot(nrow(hdr) == 1)

  # The Occupation row is the cleanest ruler on the page: one gutter label, one
  # content value, and the widest horizontal gap between them.
  occ <- pg |>
    filter(row == (pg |> group_by(row) |>
                     summarise(first_word = first(text[order(x)]), .groups = "drop") |>
                     filter(first_word == "Occupation") |> pull(row))[1]) |>
    arrange(x)
  gaps <- occ$x[-1] - (occ$x[-nrow(occ)] + occ$width[-nrow(occ)])
  content_left <- occ$x[which.max(gaps) + 1]

  list(min_x = content_left - 8, header_y = hdr$y)
}

#' Read the labelled header fields of a role block
#'
#' @param words Tibble for the role block.
#' @param first_page Integer.
#' @return Named list with track, occupation, job_role, description, and the
#'   y of the Critical Work Functions / Key Task header row.
parse_role_header <- function(words, first_page, gutter) {
  pg <- words |> filter(page == first_page)
  min_x <- gutter$min_x
  hdr_y <- gutter$header_y

  rows <- pg |>
    group_by(row) |>
    summarise(
      y     = min(y),
      label = str_squish(join_words(pick(everything())[x < min_x, ])),
      value = str_squish(join_words(pick(everything())[x >= min_x, ])),
      .groups = "drop"
    ) |>
    arrange(y)

  get_label <- function(pattern) {
    hit <- rows |> filter(str_detect(label, pattern), value != "")
    if (nrow(hit) == 0) return(NULL)
    hit[1, ]
  }

  track_row <- get_label("^Track$")
  occ_row   <- get_label("^Occupation$")
  role_row  <- get_label("^Job Role$")
  stopifnot(!is.null(track_row), !is.null(occ_row), !is.null(role_row))

  # The description occupies every content row between the job role title row
  # and the table header. Header fragments that wrap above the header row are
  # dropped by repair rule L6.
  desc_lines <- rows |>
    filter(y > role_row$y, y < hdr_y, value != "") |>
    filter(!map_lgl(value, \(t) any(str_detect(t, otccf_role_header_bits)))) |>
    pull(value)

  list(
    track       = track_row$value,
    occupation  = occ_row$value,
    job_role    = role_row$value,
    description = join_lines(desc_lines),
    header_y    = hdr_y
  )
}

#' Assign key tasks to critical work functions by cell centring
#'
#' In the source table each critical work function is a merged cell whose label
#' is vertically centred over the group of key tasks it governs. This solves for
#' the grouping that puts each label at the centre of its own task block, by
#' exhaustive search over ordered split points. It is an optimisation over the
#' document's own geometry, not an editorial judgement about which task belongs
#' to which function.
#'
#' @param cwf_centres Numeric vector, document ordinate of each CWF label centre.
#' @param task_spans Numeric matrix, two columns: first and last ordinate of each
#'   key task block.
#' @return Integer vector, parent CWF index per key task, plus attribute
#'   "residuals" giving the per CWF centring error in points.
assign_tasks_to_functions <- function(cwf_centres, task_spans) {
  n_cwf  <- length(cwf_centres)
  n_task <- nrow(task_spans)
  if (n_cwf == 0 || n_task == 0) return(integer(0))
  if (n_cwf > n_task) {
    # Cannot give every function its own task. Fall back to nearest centre and
    # make the anomaly visible rather than silently reshaping the table.
    warning("more critical work functions (", n_cwf, ") than key tasks (",
            n_task, "); falling back to nearest centre assignment")
    centres <- rowMeans(task_spans)
    out <- vapply(centres, \(c0) which.min(abs(cwf_centres - c0)), integer(1))
    attr(out, "residuals") <- rep(NA_real_, n_cwf)
    return(out)
  }
  if (n_cwf == 1) {
    out <- rep(1L, n_task)
    attr(out, "residuals") <- abs(mean(range(task_spans)) - cwf_centres[1])
    return(out)
  }

  # best[i, j] = minimal total centring error assigning the first j tasks to the
  # first i critical work functions. Each function must receive >= 1 task.
  INF  <- .Machine$double.xmax / 4
  best <- matrix(INF, nrow = n_cwf, ncol = n_task)
  back <- matrix(NA_integer_, nrow = n_cwf, ncol = n_task)
  cell_err <- function(i, a, b) {
    abs((task_spans[a, 1] + task_spans[b, 2]) / 2 - cwf_centres[i])
  }

  for (j in seq_len(n_task)) best[1, j] <- cell_err(1, 1, j)
  if (n_cwf > 1) {
    for (i in 2:n_cwf) {
      for (j in i:n_task) {
        for (k in (i - 1):(j - 1)) {
          cand <- best[i - 1, k] + cell_err(i, k + 1, j)
          if (cand < best[i, j]) {
            best[i, j] <- cand
            back[i, j] <- k
          }
        }
      }
    }
  }

  parent <- integer(n_task)
  resid  <- numeric(n_cwf)
  j <- n_task
  for (i in rev(seq_len(n_cwf))) {
    k <- if (i == 1) 0L else back[i, j]
    parent[(k + 1):j] <- i
    resid[i] <- cell_err(i, k + 1, j)
    j <- k
  }
  attr(parent, "residuals") <- resid
  parent
}

#' Parse one job role skills map
#'
#' @param words Tibble for the role block pages.
#' @param first_page Integer.
#' @return List: role (1 row tibble), elements (long tibble), tscs, ccs.
parse_role_block <- function(words, first_page) {
  gutter <- role_gutter(words |> filter(page == first_page))
  hdr <- parse_role_header(words, first_page, gutter)
  min_x <- gutter$min_x
  role_slug <- slugify(hdr$job_role)

  # Region 1: critical work functions / key tasks / performance expectations.
  skills_hdr <- words |>
    group_by(page, row) |>
    summarise(y = min(y),
              txt = str_squish(join_words(pick(everything()))),
              .groups = "drop") |>
    filter(str_detect(txt, "Technical Skills & Competencies")) |>
    arrange(page, y) |>
    slice(1)
  stopifnot(nrow(skills_hdr) == 1)

  # A page continuous ordinate: the printed text block is about 820pt tall, so
  # this keeps the geometry of a table that spans a page turn close to true.
  ord <- function(p, y) p * 820 + y

  # Drop the wrapped Performance Expectations header fragments (repair rule L6)
  # before the content region is cut.
  header_frag_rows <- words |>
    filter(page == first_page,
           y > hdr$header_y - 45, y < hdr$header_y + 45) |>
    group_by(row) |>
    summarise(y = min(y), txt = str_squish(join_words(pick(everything()))),
              .groups = "drop") |>
    filter(map_lgl(txt, \(t) any(str_detect(t, otccf_role_header_bits)))) |>
    pull(row)

  table_words <- words |>
    filter(!(page == first_page & row %in% header_frag_rows)) |>
    filter(ord(page, y) > ord(first_page, hdr$header_y),
           ord(page, y) < ord(skills_hdr$page, skills_hdr$y),
           x >= min_x)

  cols <- detect_columns(table_words, min_x = min_x)
  col_lines <- rows_by_column(table_words, cols)

  take_col <- function(k, bulleted = FALSE) {
    if (length(cols) < k) return(group_into_elements(tibble(), bulleted))
    col_lines |> filter(col == k) |> select(page, y, text) |>
      group_into_elements(bulleted)
  }

  cwf  <- take_col(1)
  task <- take_col(2)
  perf <- take_col(3)

  # Ordinates for the centring solve.
  span_of <- function(el_tbl, col_k) {
    if (nrow(el_tbl) == 0) return(matrix(numeric(0), ncol = 2))
    lines <- col_lines |> filter(col == col_k) |> arrange(page, y)
    lines$el <- rep(seq_len(nrow(el_tbl)), times = lengths(el_tbl$lines))
    lines |>
      mutate(o = ord(page, y)) |>
      group_by(el) |>
      summarise(a = min(o), b = max(o), .groups = "drop") |>
      select(a, b) |>
      as.matrix()
  }

  cwf_spans  <- span_of(cwf, 1)
  task_spans <- span_of(task, 2)
  cwf_centres <- if (nrow(cwf_spans)) rowMeans(cwf_spans) else numeric(0)

  parent <- assign_tasks_to_functions(cwf_centres, task_spans)
  residuals <- attr(parent, "residuals")

  elements <- bind_rows(
    cwf |> transmute(role_slug, element_type = "critical_work_function",
                     parent_index = NA_integer_, element_index, element_text,
                     source_pages = pages, lines),
    task |> transmute(role_slug, element_type = "key_task",
                      parent_index = if (length(parent)) parent else NA_integer_,
                      element_index, element_text, source_pages = pages, lines),
    perf |> transmute(role_slug, element_type = "performance_expectation",
                      parent_index = NA_integer_, element_index, element_text,
                      source_pages = pages, lines)
  )

  # Region 2: skills and competencies.
  skills_words <- words |>
    filter(ord(page, y) > ord(skills_hdr$page, skills_hdr$y + 5), x >= min_x)
  scols <- detect_columns(skills_words, min_x = min_x)
  slines <- rows_by_column(skills_words, scols)

  # Column 1 TSC title, column 2 required proficiency level,
  # column 3 critical core skill, column 4 its proficiency label.
  tsc_names <- slines |> filter(col == 1) |> select(page, y, text) |>
    group_into_elements(bulleted = FALSE)
  tsc_lvls  <- slines |> filter(col == 2) |> select(page, y, text)

  tsc_spans <- if (nrow(tsc_names)) {
    ln <- slines |> filter(col == 1) |> arrange(page, y)
    ln$el <- rep(seq_len(nrow(tsc_names)), times = lengths(tsc_names$lines))
    ln |> mutate(o = ord(page, y)) |> group_by(el) |>
      summarise(a = min(o), b = max(o), .groups = "drop")
  } else tibble(el = integer(), a = numeric(), b = numeric())

  tsc_map <- tsc_names |>
    mutate(a = tsc_spans$a, b = tsc_spans$b) |>
    rowwise() |>
    mutate(proficiency_level = {
      hit <- tsc_lvls |> filter(ord(page, y) >= a - 8, ord(page, y) <= b + 8)
      if (nrow(hit) == 0) NA_character_ else str_squish(paste(hit$text, collapse = " "))
    }) |>
    ungroup() |>
    transmute(role_slug,
              tsc_title_as_listed = element_text,
              proficiency_level_as_listed = str_squish(proficiency_level),
              source_pages        = pages)

  ccs <- if (length(scols) >= 4) {
    nm <- slines |> filter(col == 3) |> select(page, y, text) |>
      group_into_elements(bulleted = FALSE)
    lv <- slines |> filter(col == 4) |> select(page, y, text)
    nl <- slines |> filter(col == 3) |> arrange(page, y)
    if (nrow(nm)) {
      nl$el <- rep(seq_len(nrow(nm)), times = lengths(nm$lines))
      sp <- nl |> mutate(o = ord(page, y)) |> group_by(el) |>
        summarise(a = min(o), b = max(o), .groups = "drop")
      nm |> mutate(a = sp$a, b = sp$b) |> rowwise() |>
        mutate(proficiency_level = {
          hit <- lv |> filter(ord(page, y) >= a - 8, ord(page, y) <= b + 8)
          if (nrow(hit) == 0) NA_character_ else str_squish(paste(hit$text, collapse = " "))
        }) |>
        ungroup() |>
        transmute(role_slug, skill_name = element_text, proficiency_level,
                  source_pages = pages)
    } else tibble()
  } else tibble()

  list(
    role = tibble(
      role_slug          = role_slug,
      job_role           = hdr$job_role,
      occupation         = hdr$occupation,
      track_as_listed    = hdr$track,
      role_description   = hdr$description,
      first_page         = first_page,
      last_page          = max(words$page),
      n_critical_work_functions = nrow(cwf),
      n_key_tasks        = nrow(task),
      n_performance_expectations = nrow(perf),
      max_centring_residual_pt = if (length(residuals)) round(max(residuals), 1) else NA_real_
    ),
    elements = elements,
    tsc_map  = tsc_map,
    ccs      = ccs
  )
}

# ---------------------------------------------------------------------------
# Extraction: TSC catalogue
# ---------------------------------------------------------------------------

#' Locate the first page of each TSC block
#'
#' @param words Tibble.
#' @return Integer vector of pages.
find_tsc_pages <- function(words) {
  words |>
    filter(page %in% otccf_config$tsc_pages) |>
    group_by(page, row) |>
    summarise(label = str_squish(join_words(pick(everything())[x < 210, ])),
              .groups = "drop") |>
    filter(label == "TSC Category") |>
    pull(page) |>
    unique() |>
    sort()
}

#' Parse one TSC block
#'
#' @param words Tibble for the block pages.
#' @param first_page Integer.
#' @return List: tsc (1 row), levels (long tibble).
parse_tsc_block <- function(words, first_page) {
  pg <- words |> filter(page == first_page)
  rows <- pg |>
    group_by(row) |>
    summarise(y = min(y),
              label = str_squish(join_words(pick(everything())[x < 210, ])),
              value = str_squish(join_words(pick(everything())[x >= 210, ])),
              .groups = "drop") |>
    arrange(y) |>
    rename(row_id = row)

  cat_row  <- rows |> filter(label == "TSC Category") |> slice(1)
  ttl_row  <- rows |> filter(label == "TSC Title") |> slice(1)
  lvl_row  <- rows |> filter(str_detect(value, "^Level 1\\b")) |> slice(1)
  stopifnot(nrow(cat_row) == 1, nrow(ttl_row) == 1, nrow(lvl_row) == 1)

  # The "#" marker is a separate glyph trailing the title.
  raw_title <- ttl_row$value
  skillsfuture_derived <- str_detect(raw_title, "#")
  title <- str_squish(str_remove_all(raw_title, "#"))

  # The description text sometimes renders above its own row label, so the
  # window runs from the title row to the level header rather than from the
  # label.
  desc_lines <- rows |>
    filter(y > ttl_row$y, y < lvl_row$y - 5, value != "") |>
    pull(value)
  description <- join_lines(desc_lines)

  # Level column geometry. The "Level N" headers are centred over their column,
  # and the offset between a header and its data varies with the column width
  # from one TSC to the next, so the data columns are detected empirically and
  # then matched to their nearest header rather than assumed at a fixed offset.
  lvl_words <- pg |> filter(y >= lvl_row$y - 3, y <= lvl_row$y + 3,
                            text == "Level") |> arrange(x)
  lvl_nums <- pg |> filter(y >= lvl_row$y - 3, y <= lvl_row$y + 3,
                           str_detect(text, "^[1-6]$")) |> arrange(x)
  stopifnot(nrow(lvl_words) == nrow(lvl_nums))
  lvl_x <- lvl_words$x
  level_num <- as.integer(lvl_nums$text)

  ord <- function(p, y) p * 820 + y

  # Section boundaries. Section labels sit in the left gutter, vertically
  # centred on a cell that begins about 12pt above the label baseline.
  label_rows <- words |>
    group_by(page, row) |>
    summarise(y = min(y),
              label = str_squish(join_words(pick(everything())[x < 210, ])),
              .groups = "drop") |>
    filter(label %in% c("TSC Proficiency Description", "Knowledge", "Abilities",
                        "Range of Application")) |>
    mutate(section = recode(label,
                            "TSC Proficiency Description" = "level_description",
                            "Knowledge" = "knowledge",
                            "Abilities" = "ability",
                            "Range of Application" = "range_of_application"),
           boundary = ord(page, y - 12)) |>
    arrange(boundary)

  # "Range of Application" is a full width row beneath the proficiency grid, not
  # a level column, so it is cut away before the grid is parsed and collected
  # separately.
  roa_rows <- label_rows |> filter(section == "range_of_application")
  roa_start <- if (!nrow(roa_rows)) {
    Inf
  } else {
    # The cell opens at the first line that starts in the full width left
    # margin, which is unambiguous, rather than at a guessed offset from the
    # label. A trailing line of the level grid can otherwise bleed in.
    approach <- min(roa_rows$boundary) - 20
    first <- words |>
      filter(ord(page, y) >= approach, x >= 210, x < 400) |>
      mutate(o = ord(page, y)) |>
      pull(o)
    if (length(first)) min(first) else min(roa_rows$boundary)
  }

  range_of_application <- if (is.finite(roa_start)) {
    roa_words <- words |> filter(ord(page, y) >= roa_start, x >= 210)
    if (nrow(roa_words) == 0) {
      tibble()
    } else {
      rows_by_column(roa_words, min(roa_words$x)) |>
        select(page, y, text) |>
        group_into_elements(bulleted = TRUE) |>
        transmute(tsc_slug = slugify(title), element_index, element_text,
                  source_pages = pages)
    }
  } else tibble()

  content <- words |>
    filter(x >= min(lvl_x) - 80) |>
    filter(ord(page, y) > ord(first_page, lvl_row$y + 3),
           ord(page, y) < roa_start)

  # Data columns are detected on the block's first page, where the Level headers
  # make the geometry authoritative, and then applied to the whole block. A
  # continuation page keeps the same column edges, and detecting on it
  # separately only admits noise from short ragged lines. A level whose content
  # begins only on a later page is picked up by the second pass.
  col_scan <- function(w, min_n) detect_columns(w, min_x = min(lvl_x) - 80,
                                                min_gap = 60, min_n = min_n)
  data_cols <- col_scan(content |> filter(page == first_page), min_n = 3)
  covered <- level_num[map_int(data_cols, \(a) which.min(abs(lvl_x - a)))]
  for (pp in setdiff(sort(unique(content$page)), first_page)) {
    extra <- col_scan(content |> filter(page == pp), min_n = 3)
    for (a in extra) {
      lv <- level_num[which.min(abs(lvl_x - a))]
      if (!lv %in% covered) {
        data_cols <- c(data_cols, a)
        covered   <- c(covered, lv)
      }
    }
  }
  if (length(data_cols) == 0) {
    return(list(tsc = tibble(), levels = tibble(),
                range_of_application = range_of_application))
  }
  ordering  <- order(data_cols)
  data_cols <- data_cols[ordering]
  col_level <- covered[ordering]
  if (any(duplicated(col_level))) {
    warning("TSC starting on page ", first_page,
            ": two data columns matched proficiency level ",
            paste(unique(col_level[duplicated(col_level)]), collapse = ", "))
  }

  lines <- rows_by_column(content, data_cols) |>
    mutate(level = col_level[col])

  if (nrow(lines) == 0) {
    return(list(tsc = tibble(), levels = tibble(),
                range_of_application = range_of_application))
  }
  lines <- lines |> mutate(o = ord(page, y))

  # Refine each bulleted section's boundary onto the first bullet at or after
  # the label, so that a continuation line of the last statement of the previous
  # section is not cut off by the nominal label offset.
  bullet_ords <- lines |> filter(str_detect(text, "^•")) |> pull(o) |> sort()
  label_rows <- label_rows |>
    mutate(boundary = if_else(
      section %in% c("knowledge", "ability"),
      map_dbl(boundary, \(b) {
        hit <- bullet_ords[bullet_ords >= b - 2]
        if (length(hit)) hit[1] else b
      }),
      boundary
    )) |>
    arrange(boundary)

  # Carry the section forward across page turns where the label is not repeated.
  lines$section <- map_chr(lines$o, \(o) {
    hit <- label_rows |> filter(boundary <= o)
    if (nrow(hit) == 0) "level_description" else tail(hit$section, 1)
  })

  levels_long <- lines |>
    filter(section != "range_of_application") |>
    group_split(level, section) |>
    map_dfr(\(chunk) {
      if (nrow(chunk) == 0) return(tibble())
      sect <- chunk$section[1]
      els  <- chunk |> arrange(page, y) |> select(page, y, text) |>
        group_into_elements(bulleted = sect %in% c("knowledge", "ability"))
      if (nrow(els) == 0) return(tibble())
      els |> transmute(
        proficiency_level = chunk$level[1],
        element_type      = sect,
        element_index,
        element_text,
        source_pages      = pages,
        lines
      )
    }) |>
    arrange(proficiency_level, element_type, element_index)

  list(
    tsc = tibble(
      tsc_slug             = slugify(title),
      title                = title,
      category             = cat_row$value,
      description          = description,
      skillsfuture_derived = skillsfuture_derived,
      first_page           = first_page,
      last_page            = max(words$page),
      levels_populated     = paste(sort(unique(levels_long$proficiency_level)), collapse = ","),
      n_level_statements   = nrow(levels_long)
    ),
    levels = if (nrow(levels_long)) mutate(levels_long, tsc_slug = slugify(title)) else tibble(),
    range_of_application = range_of_application
  )
}

# ---------------------------------------------------------------------------
# Integrity checks
# ---------------------------------------------------------------------------

#' Report integrity findings via message()
#'
#' @return Integer count of problems found.
run_integrity_checks <- function(tracks, roles, role_elements, tscs, tsc_levels,
                                 role_tsc_map, role_ccs) {
  problems <- 0L
  flag <- function(ok, msg) {
    if (!ok) {
      problems <<- problems + 1L
      message("  FAIL  ", msg)
    } else {
      message("  ok    ", msg)
    }
  }

  message("\n--- Integrity checks ---")

  flag(!any(duplicated(roles$role_slug)),
       glue("job role slugs unique ({nrow(roles)} roles)"))
  flag(!any(duplicated(tscs$tsc_slug)),
       glue("TSC slugs unique ({nrow(tscs)} TSCs)"))
  flag(!any(duplicated(tracks$track_slug)),
       glue("track slugs unique ({nrow(tracks)} tracks)"))

  # Each populated proficiency level of each TSC should carry exactly one
  # TSC Proficiency Description. This is the document's own internal total.
  populated <- tscs |>
    mutate(n = lengths(str_split(levels_populated, ","))) |>
    pull(n) |> sum()
  n_desc <- sum(tsc_levels$element_type == "level_description")
  flag(populated == n_desc,
       glue("one level description per populated level ({n_desc} descriptions, {populated} populated levels)"))

  # The document states its own totals in the career map and the section 4
  # heading numbering; the career map shows 16 boxes of which CISO carries no
  # skills map.
  flag(nrow(roles) == 15,
       glue("job role count is 15 as drawn in the career map minus CISO (got {nrow(roles)})"))

  orphan_tsc <- role_tsc_map |> filter(is.na(tsc_slug))
  flag(nrow(orphan_tsc) == 0,
       glue("every role-to-TSC reference resolves ({nrow(orphan_tsc)} unresolved)"))
  if (nrow(orphan_tsc)) {
    orphan_tsc |> distinct(tsc_title_as_listed) |> pull() |>
      walk(\(t) message("          unresolved title: ", t))
  }

  bad_role_fk <- role_tsc_map |> filter(!role_slug %in% roles$role_slug)
  flag(nrow(bad_role_fk) == 0, "role-to-TSC map role keys resolve")

  bad_el_fk <- role_elements |> filter(!role_slug %in% roles$role_slug)
  flag(nrow(bad_el_fk) == 0, "role element role keys resolve")

  bad_lvl_fk <- tsc_levels |> filter(!tsc_slug %in% tscs$tsc_slug)
  flag(nrow(bad_lvl_fk) == 0, "TSC level statement keys resolve")

  bad_parent <- role_elements |>
    filter(element_type == "key_task") |>
    left_join(role_elements |> filter(element_type == "critical_work_function") |>
                count(role_slug, name = "n_cwf"), by = "role_slug") |>
    filter(is.na(parent_index) | is.na(n_cwf) | parent_index > n_cwf)
  flag(nrow(bad_parent) == 0,
       glue("every key task resolves to a critical work function ({nrow(bad_parent)} bad)"))

  flag(!any(str_squish(role_elements$element_text) == ""), "no empty role element text")
  flag(!any(str_squish(tsc_levels$element_text) == ""), "no empty TSC level statement text")
  flag(!any(str_squish(tscs$title) == ""), "no empty TSC titles")
  flag(!any(str_squish(tscs$description) == ""), "no empty TSC descriptions")
  flag(!any(str_squish(roles$role_description) == ""), "no empty role descriptions")

  flag(all(role_tsc_map$proficiency_level %in% 1:6),
       "every role-to-TSC proficiency level is in 1..6")
  flag(all(tsc_levels$proficiency_level %in% 1:6),
       "every TSC level statement level is in 1..6")

  short_el <- bind_rows(
    role_elements |> transmute(src = "role_elements", element_text),
    tsc_levels    |> transmute(src = "tsc_levels", element_text)
  ) |> filter(str_length(element_text) < 15)
  long_el <- bind_rows(
    role_elements |> transmute(src = "role_elements", element_text),
    tsc_levels    |> transmute(src = "tsc_levels", element_text)
  ) |> filter(str_length(element_text) > 800)
  message(glue("  note  elements under 15 characters: {nrow(short_el)}"))
  if (nrow(short_el)) walk(short_el$element_text, \(t) message("          short: ", t))
  message(glue("  note  elements over 800 characters: {nrow(long_el)}"))
  if (nrow(long_el)) walk(str_trunc(long_el$element_text, 90), \(t) message("          long: ", t))

  # A key task or level statement that opens lower case is a likely page turn
  # split.
  lc <- bind_rows(
    role_elements |> transmute(src = "role_elements", element_text),
    tsc_levels    |> transmute(src = "tsc_levels", element_text)
  ) |> filter(str_detect(element_text, "^[a-z]"))
  message(glue("  note  elements opening lower case (possible split across a page turn): {nrow(lc)}"))
  if (nrow(lc)) walk(str_trunc(lc$element_text, 90), \(t) message("          lc: ", t))

  worst <- roles |> arrange(desc(max_centring_residual_pt)) |> slice(1)
  message(glue("  note  worst critical work function centring residual: {worst$max_centring_residual_pt} pt ({worst$job_role})"))

  message(glue("--- {problems} check(s) failed ---"))
  invisible(problems)
}

# ---------------------------------------------------------------------------
# Fidelity spot check
# ---------------------------------------------------------------------------

#' Compare parsed elements against an independent text extraction
#'
#' pdf_text and pdf_data are separate extraction paths. Every parsed element is
#' built from pdf_data word coordinates; this checks each of its source lines
#' against the pdf_text rendering of the same page. A line that does not appear
#' verbatim in the page text is a discrepancy, not a rounding difference.
#'
#' @param pdf_path Character.
#' @param role_elements Tibble with a lines list column.
#' @param tsc_levels Tibble with a lines list column.
#' @return Tibble of results.
fidelity_spot_check <- function(pdf_path, role_elements, tsc_levels) {
  set.seed(2026)
  page_text <- pdf_text(pdf_path) |> repair_ligatures() |> str_replace_all("\\s+", " ")

  check_one <- function(lines, pages, label) {
    pgs <- as.integer(str_split(pages, ",")[[1]])
    hay <- paste(page_text[pgs], collapse = " ")
    needles <- str_squish(unlist(lines))
    needles <- needles[needles != ""]
    hits <- map_lgl(needles, \(n) str_detect(hay, fixed(n)))
    tibble(item = label, lines_checked = length(needles),
           lines_matched = sum(hits),
           status = if (all(hits)) "exact" else "discrepancy",
           first_miss = if (all(hits)) NA_character_ else needles[which(!hits)[1]])
  }

  roles_sampled <- sample(unique(role_elements$role_slug),
                          min(5, n_distinct(role_elements$role_slug)))
  role_rows <- role_elements |>
    filter(role_slug %in% roles_sampled) |>
    group_by(role_slug) |>
    slice_sample(n = 3) |>
    ungroup()

  tscs_sampled <- sample(unique(tsc_levels$tsc_slug),
                         min(5, n_distinct(tsc_levels$tsc_slug)))
  tsc_rows <- tsc_levels |>
    filter(tsc_slug %in% tscs_sampled) |>
    group_by(tsc_slug) |>
    slice_sample(n = 2) |>
    ungroup()

  res <- bind_rows(
    pmap_dfr(list(role_rows$lines, role_rows$source_pages,
                  glue("role {role_rows$role_slug} / {role_rows$element_type} #{role_rows$element_index}")),
             check_one),
    pmap_dfr(list(tsc_rows$lines, tsc_rows$source_pages,
                  glue("tsc {tsc_rows$tsc_slug} / L{tsc_rows$proficiency_level} {tsc_rows$element_type} #{tsc_rows$element_index}")),
             check_one)
  )

  message("\n--- Fidelity spot check (set.seed(2026); 5 roles x 3 elements, 5 TSCs x 2 level statements) ---")
  walk2(res$item, res$status, \(i, s) message(glue("  {s}  {i}")))
  message(glue("  exact: {sum(res$status == 'exact')} / {nrow(res)}"))
  if (any(res$status != "exact")) {
    res |> filter(status != "exact") |>
      pwalk(\(item, lines_checked, lines_matched, status, first_miss)
            message(glue("  DISCREPANCY {item}: {lines_matched}/{lines_checked} lines matched; first miss: {first_miss}")))
  }
  invisible(res)
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

#' Read the acquisition step's provenance facts so they survive this rewrite
#'
#' @param manifest_path Character.
#' @return Named list of acquisition facts, or NULL.
read_prior_provenance <- function(manifest_path) {
  if (!file.exists(manifest_path)) return(NULL)
  prior <- suppressWarnings(yaml::read_yaml(manifest_path))
  if (!is.null(prior$acquisition)) return(prior$acquisition)
  prior
}

write_provenance_manifest <- function(pdf_path, text_path, prior, tracks, roles,
                                      role_elements, tscs, tsc_levels,
                                      role_tsc_map, role_ccs, tsc_roa, spot_check) {
  file_facts <- if (!is.null(prior$files)) prior$files[[1]] else list()

  manifest <- list(
    framework         = otccf_config$framework,
    framework_name    = otccf_config$framework_name,
    framework_version = otccf_config$framework_version,
    framework_date    = otccf_config$framework_date,
    publisher         = otccf_config$publisher,

    source = list(
      type          = "official_pdf",
      landing_page  = otccf_config$landing_page,
      source_url    = file_facts$source_url %||% NA_character_,
      filename      = otccf_config$pdf_filename,
      media_type    = "application/pdf",
      # pdf_info()$pages is already the page count, so length() around it
      # would record 1 whenever the acquisition record is missing.
      pages         = file_facts$pages %||% pdf_info(pdf_path)$pages,
      text_filename = otccf_config$text_filename
    ),

    retrieval = list(
      retrieved_at_utc = file_facts$retrieved_at_utc %||% NA_character_,
      retrieved_by     = prior$retrieved_by %||% "cybedtools acquisition job",
      file_size_bytes  = as.numeric(file.info(pdf_path)$size),
      # Lower case as digest() returns it. The verifier compares this against a
      # fresh digest() of the same file, so any case normalisation here reads
      # as a mismatch. The acquisition record's own upper case hash is carried
      # through unchanged below.
      file_sha256      = digest(file = pdf_path, algo = "sha256"),
      sha256_at_acquisition = file_facts$sha256 %||% NA_character_,
      ingested_at_utc  = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      ingested_by      = "scripts/010-ingest-otccf.R",
      text_sha256      = digest(file = text_path, algo = "sha256")
    ),

    document_version = list(
      filename_version           = "V5",
      in_document_version_string = "version 1.1",
      effective_date             = "2021-10-08",
      cover_date                 = "October 2021",
      pdf_creation_date          = file_facts$pdf_creation_date %||% NA_character_,
      note = paste(
        "The filename asserts V5 while every page footer of the document body",
        "asserts \"Effective Date: 8 October 2021 version 1.1\". The framework",
        "version recorded here is the document's own self-description, 1.1,",
        "dated 2021-10-08. V5 is treated as a publisher side file revision label",
        "and is not used as the framework version."
      )
    ),

    extraction = list(
      extractor   = paste0("pdftools ", as.character(utils::packageVersion("pdftools")),
                           " (pdf_data word coordinates; pdf_text for the intermediate and the spot check)"),
      method      = paste(
        "Column geometry is read from the document itself: role tables by the",
        "empirical left edges of their cell text, TSC proficiency grids by the",
        "x position of each centred Level header. Key tasks are attached to",
        "their critical work function by solving for the grouping that centres",
        "each merged cell label over its own block of tasks, which is the",
        "document's own layout rule rather than an editorial judgement."
      ),
      tracks      = nrow(tracks),
      job_roles   = nrow(roles),
      role_elements = nrow(role_elements),
      role_element_breakdown = role_elements |> count(element_type) |>
        deframe() |> as.list(),
      tscs                  = nrow(tscs),
      tsc_category_breakdown = tscs |> count(category) |> deframe() |> as.list(),
      tsc_level_statements  = nrow(tsc_levels),
      tsc_level_breakdown   = tsc_levels |> count(element_type) |> deframe() |> as.list(),
      tsc_statements_by_level = tsc_levels |> count(proficiency_level) |>
        mutate(proficiency_level = paste0("level_", proficiency_level)) |>
        deframe() |> as.list(),
      tsc_range_of_application_rows = nrow(tsc_roa),
      tsc_range_of_application_tscs = n_distinct(tsc_roa$tsc_slug),
      role_tsc_map_rows       = nrow(role_tsc_map),
      role_critical_core_skills_rows = nrow(role_ccs),
      tables_written = list("tracks.csv", "job-roles.csv", "role-tracks.csv",
                            "role-elements-long.csv", "tscs.csv",
                            "tsc-levels-long.csv", "tsc-range-of-application.csv",
                            "role-tsc-map.csv", "role-critical-core-skills.csv"),
      spot_check_exact        = sum(spot_check$status == "exact"),
      spot_check_total        = nrow(spot_check)
    ),

    skillsfuture_provenance = list(
      marker_verbatim = "#Extracted from SkillsFuture ICT Framework",
      note = paste(
        "SkillsFuture Singapore (SSG) is a separate body from CSA. The eight",
        "TSCs listed below carry a \"#\" on their TSC Title and appear on pages",
        "footnoted with the extraction marker, so they are not CSA original",
        "content. They are flagged with skillsfuture_derived = TRUE in",
        "tables/tscs.csv. Every other TSC carries no marker."
      ),
      skillsfuture_derived_tsc_count = sum(tscs$skillsfuture_derived),
      csa_original_tsc_count         = sum(!tscs$skillsfuture_derived),
      skillsfuture_derived_tscs = tscs |>
        filter(skillsfuture_derived) |>
        transmute(title, category,
                  pages = paste0(first_page, "-", last_page)) |>
        pmap(\(title, category, pages) list(title = title, category = category,
                                            pdf_pages = pages)),
      footnote_pages = "97, 99, 101, 104, 106, 108, 110, 112",
      role_references_to_skillsfuture_derived_tscs =
        role_tsc_map |>
          filter(tsc_slug %in% (tscs |> filter(skillsfuture_derived) |> pull(tsc_slug))) |>
          nrow()
    ),

    licensing = list(
      source_license = "Copyright Cyber Security Agency of Singapore. Used with written permission of CSA, 2026-09-15, for non-commercial, academic and research purposes.",
      attribution = "Derived from the Operational Technology Cybersecurity Competency Framework (OTCCF), published by the Cyber Security Agency of Singapore (CSA). Available at: https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/",
      permission_granted = "2026-09-15",
      permission_conditions = list(
        "The attribution string above must be reproduced verbatim and unaltered.",
        "Ingestion scripts and structural mappings must not misrepresent or alter the intent of the OTCCF's job roles, skills, or competency mappings as published by CSA."
      ),
      redistribution = paste(
        "Non-commercial academic and research use only. Any other use requires",
        "fresh permission from CSA."
      ),
      terms_of_use_url = prior$terms_of_use_url %||% "https://www.csa.gov.sg/terms-of-use/",
      landing_page_copyright_verbatim = prior$copyright_notice_landing_page_verbatim %||% "© 2026 Government of Singapore"
    ),

    verbatim_notices = otccf_notices |>
      pmap(\(notice_type, pages, text_verbatim)
           list(notice_type = notice_type, pdf_pages = pages,
                text_verbatim = text_verbatim)),

    contact_page_verbatim = prior$contact_page_verbatim %||%
      "QUERIES & FEEDBACK\nQuestions and feedback on this document may be submitted to:\nsimon_eng@csa.gov.sg\nraymond_ung@csa.gov.sg\ncorrine_peng@csa.gov.sg",

    notes = list(
      currently_being_updated = paste(
        "CSA has stated that the OTCCF is currently being updated. The tables",
        "here describe version 1.1 of 8 October 2021 and should be re-cut when a",
        "successor is published."
      ),
      identifiers = paste(
        "CSA publishes no codes for tracks, job roles, or TSCs. track_slug,",
        "role_slug, and tsc_slug are package generated from the published titles",
        "and are named so they cannot be mistaken for CSA identifiers. Where the",
        "document does supply a value, such as a proficiency level, the",
        "document's own value is used unchanged."
      ),
      fidelity = paste(
        "No source text is paraphrased, merged, re-levelled, or summarised.",
        "Source typographical errors are preserved as published; observed",
        "examples include \"consideraration\", \"systens\", \"testingfor\", and",
        "\"operation n to be\". Correcting them would alter the published text."
      ),
      repair_rules = list(
        L1 = "Ligature glyphs (fi, fl, ff, ffi, ffl, st) and non-breaking spaces expanded to their component characters. Font encoding artifact, not authored text.",
        L2 = "A line ending in a hyphen followed by a lower case continuation is rejoined with the hyphen intact and no inserted space, recovering compounds such as future-readiness that the line box split.",
        L3 = "Other line breaks inside one cell become a single space; runs of whitespace are collapsed.",
        L4 = "A leading bullet glyph is removed from knowledge, ability, and list statements. List furniture, not statement text.",
        L5 = "Page furniture is dropped before parsing: the running header OPERATIONAL TECHNOLOGY CYBERSECURITY COMPETENCY FRAMEWORK, the copyright footer, the Effective Date footer, the printed page number, the standing disclaimer line, and the SkillsFuture footnote line. These bleed into the text layer between table cells."
      ),
      title_aliases = paste(
        "The skills maps and the TSC catalogue spell several competencies",
        "differently; CSA published both spellings and neither is corrected.",
        "role-tsc-map.csv keeps the skills-map spelling verbatim in",
        "tsc_title_as_listed, and tsc_slug points at the catalogue entry so the",
        "foreign key resolves. Aliases applied: ",
        paste(glue("{names(otccf_title_aliases)} -> {unname(otccf_title_aliases)}"),
              collapse = "; ")
      ),
      range_of_application = paste(
        "Ten TSC blocks carry a \"Range of Application\" row. Seven are empty;",
        "three carry content and are recorded in",
        "tables/tsc-range-of-application.csv: Network Security and Segmentation",
        "(PDF page 57), Supply Chain Management (71), and Emerging Technology",
        "Synthesis (101). The cell is a full width left aligned list beneath the",
        "proficiency grid, not a level column. On page 57 the cell holds three",
        "sub lists side by side under their own lead ins, and the flattening",
        "runs the tail of one lead in into the head of the next on three rows;",
        "those rows are faithful to the words on the page but not to its two",
        "dimensional grouping."
      ),
      career_map = paste(
        "The career map on page 4 draws 16 boxes across 5 tracks. CISO appears in",
        "the map but has no skills map, so 15 job roles carry parsed content.",
        "The map's entry point examples (governance, risk analysts, maintenance",
        "engineer, and so on) are illustrative job functions, not OTCCF roles,",
        "and are not ingested."
      ),
      critical_core_skills = paste(
        "Critical Core Skills, previously Generic Skills and Competencies, are",
        "CSA references out to the SkillsFuture Critical Core Skills framework",
        "and carry Basic/Intermediate/Advanced labels rather than numeric levels.",
        "They are recorded in tables/role-critical-core-skills.csv and are not",
        "TSCs."
      ),
      extraction_weak_points = paste(
        "Key task to critical work function nesting is inferred from cell",
        "centring geometry rather than from ruling lines, which pdftools does not",
        "expose; the per role residual is reported in job-roles.csv as",
        "max_centring_residual_pt and is near zero where the grouping is certain.",
        "An element that runs across a page turn is split unless it continues an",
        "open bullet; the integrity report lists any element opening lower case",
        "so such splits are visible."
      )
    ),

    acquisition = prior
  )

  manifest_path <- file.path(otccf_config$staging_dir, otccf_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== OTCCF v1.1 Ingestion ===")

  pdf_path  <- file.path(otccf_config$staging_dir, otccf_config$pdf_filename)
  text_path <- file.path(otccf_config$staging_dir, otccf_config$text_filename)
  manifest_path <- file.path(otccf_config$staging_dir, otccf_config$manifest_filename)

  if (!file.exists(pdf_path)) stop("OTCCF PDF not found at ", pdf_path)

  prior <- read_prior_provenance(manifest_path)
  if (is.null(prior)) {
    message("No prior provenance found; acquisition facts will be recorded as NA.")
  } else {
    message("Prior acquisition provenance read and will be carried forward.")
  }

  message("Writing extracted text intermediate...")
  write_extracted_text(pdf_path, text_path)

  message("Building word table from PDF coordinates...")
  words <- build_word_table(pdf_path)
  message("  Pages: ", n_distinct(words$page), "   Words: ", nrow(words))

  # --- Job roles ----------------------------------------------------------
  message("Locating job role skills maps...")
  role_pages <- find_role_pages(words)
  message("  Skills maps found: ", nrow(role_pages))

  role_bounds <- role_pages |>
    mutate(end_page = lead(page, default = max(otccf_config$skills_map_pages) + 1L) - 1L)

  message("Parsing job roles...")
  parsed_roles <- pmap(list(role_bounds$page, role_bounds$end_page), \(p0, p1) {
    blk <- words |> filter(page >= p0, page <= p1)
    parse_role_block(blk, p0)
  })

  roles <- map_dfr(parsed_roles, "role")
  role_elements <- map_dfr(parsed_roles, "elements")
  role_tsc_raw  <- map_dfr(parsed_roles, "tsc_map")
  role_ccs      <- map_dfr(parsed_roles, "ccs")
  message("  Roles: ", nrow(roles), "   Role elements: ", nrow(role_elements))

  # --- Tracks -------------------------------------------------------------
  # A role's Track cell may name more than one track, separated by " / ".
  tracks <- roles |>
    pull(track_as_listed) |>
    str_split(" / ") |>
    unlist() |>
    str_squish() |>
    unique() |>
    sort() |>
    (\(x) tibble(track_slug = slugify(x), track_name = x))()
  message("  Tracks: ", nrow(tracks))

  role_tracks <- roles |>
    select(role_slug, track_as_listed) |>
    mutate(track_name = str_split(track_as_listed, " / ")) |>
    tidyr::unnest(track_name) |>
    mutate(track_name = str_squish(track_name),
           track_slug = slugify(track_name)) |>
    select(role_slug, track_slug, track_name, track_as_listed)

  # --- TSC catalogue ------------------------------------------------------
  message("Locating TSC blocks...")
  tsc_starts <- find_tsc_pages(words)
  message("  TSC blocks found: ", length(tsc_starts))

  tsc_bounds <- tibble(page = tsc_starts) |>
    mutate(end_page = lead(page, default = max(otccf_config$tsc_pages) + 1L) - 1L)

  message("Parsing TSCs...")
  parsed_tscs <- pmap(list(tsc_bounds$page, tsc_bounds$end_page), \(p0, p1) {
    blk <- words |> filter(page >= p0, page <= p1)
    parse_tsc_block(blk, p0)
  })

  tscs       <- map_dfr(parsed_tscs, "tsc")
  tsc_levels <- map_dfr(parsed_tscs, "levels")
  tsc_roa    <- map_dfr(parsed_tscs, "range_of_application")
  message("  Range of Application statements: ", nrow(tsc_roa),
          " across ", n_distinct(tsc_roa$tsc_slug), " TSCs")
  message("  TSCs: ", nrow(tscs), "   Level statements: ", nrow(tsc_levels))
  message("  SkillsFuture derived TSCs: ", sum(tscs$skillsfuture_derived))

  # --- Role to TSC map ----------------------------------------------------
  lookup <- tscs |> select(tsc_slug, title)
  # A skills map cell may require more than one proficiency level, printed as
  # "3, 4". The verbatim cell is kept and one row is emitted per level so the
  # numeric column stays usable without collapsing CSA's own requirement.
  role_tsc_map <- role_tsc_raw |>
    mutate(
      canonical_title = coalesce(unname(otccf_title_aliases[tsc_title_as_listed]),
                                 tsc_title_as_listed),
      tsc_slug        = lookup$tsc_slug[match(canonical_title, lookup$title)],
      proficiency_level = str_extract_all(proficiency_level_as_listed, "[1-6]")
    ) |>
    tidyr::unnest_longer(proficiency_level, keep_empty = TRUE) |>
    mutate(proficiency_level = suppressWarnings(as.integer(proficiency_level))) |>
    select(role_slug, tsc_slug, tsc_title_as_listed, proficiency_level,
           proficiency_level_as_listed, source_pages)

  # --- Write tables -------------------------------------------------------
  tables_dir <- file.path(otccf_config$staging_dir, otccf_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(tracks, file.path(tables_dir, "tracks.csv"))
  write_csv(roles |>
              left_join(role_tracks |> group_by(role_slug) |>
                          summarise(track_slugs = paste(track_slug, collapse = "|"),
                                    .groups = "drop"),
                        by = "role_slug") |>
              relocate(track_slugs, .after = track_as_listed),
            file.path(tables_dir, "job-roles.csv"))
  write_csv(role_tracks, file.path(tables_dir, "role-tracks.csv"))
  write_csv(role_elements |> select(-lines),
            file.path(tables_dir, "role-elements-long.csv"))
  write_csv(tscs, file.path(tables_dir, "tscs.csv"))
  write_csv(tsc_levels |> select(tsc_slug, proficiency_level, element_type,
                                 element_index, element_text, source_pages),
            file.path(tables_dir, "tsc-levels-long.csv"))
  write_csv(role_tsc_map, file.path(tables_dir, "role-tsc-map.csv"))
  write_csv(role_ccs, file.path(tables_dir, "role-critical-core-skills.csv"))
  write_csv(tsc_roa |> select(any_of(c("tsc_slug", "element_index",
                                       "element_text", "source_pages"))),
            file.path(tables_dir, "tsc-range-of-application.csv"))

  # --- Checks -------------------------------------------------------------
  problems <- run_integrity_checks(tracks, roles, role_elements, tscs,
                                   tsc_levels, role_tsc_map, role_ccs)
  spot <- fidelity_spot_check(pdf_path, role_elements, tsc_levels)
  # The build driver gates on exit status, so a failed check has to stop the
  # script. Fidelity to the source is a condition of CSA's permission.
  if (problems > 0) {
    stop(problems, " OTCCF integrity check(s) failed. See the messages above.")
  }

  # --- Provenance ---------------------------------------------------------
  message("\nWriting provenance manifest...")
  write_provenance_manifest(pdf_path, text_path, prior, tracks, roles,
                            role_elements, tscs, tsc_levels, role_tsc_map,
                            role_ccs, tsc_roa, spot)

  message("\n=== Summary ===")
  message("  Tracks: ", nrow(tracks))
  message("  Job roles: ", nrow(roles))
  cat("  Role element breakdown:\n"); print(role_elements |> count(element_type))
  message("  TSCs: ", nrow(tscs), " (SkillsFuture derived: ",
          sum(tscs$skillsfuture_derived), ")")
  cat("  TSC category breakdown:\n"); print(tscs |> count(category))
  cat("  TSC level statement breakdown:\n"); print(tsc_levels |> count(element_type))
  message("  Role to TSC map rows: ", nrow(role_tsc_map))
  message("  Role critical core skill rows: ", nrow(role_ccs))
  message("\nOutput: ", tables_dir)
  message("Done.")

  invisible(list(tracks = tracks, roles = roles, role_elements = role_elements,
                 tscs = tscs, tsc_levels = tsc_levels,
                 role_tsc_map = role_tsc_map, role_ccs = role_ccs))
}

if (!exists("%||%")) {
  `%||%` <- function(a, b) if (is.null(a)) b else a
}

if (sys.nframe() == 0) {
  main()
}
