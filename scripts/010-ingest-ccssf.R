# 010-ingest-ccssf.R
#
# Ingest the Canadian Cyber Security Skills Framework (CCSSF) from the
# Canadian Centre for Cyber Security's 2022 PDF (ITSM.00.039).
#
# Source:
#   - "Canadian Cyber Security Skills Framework 2022 -ENG.pdf" (as supplied)
#   - Space-free working copy: ccssf-2022-eng.pdf (byte-identical copy)
#   - Intermediate: extracted-text.md (via pdftools::pdf_text, page markers)
#   - Publisher: Canadian Centre for Cyber Security (Cyber Centre)
#   - Catalogue: ISBN 978-0-660-46231-8, Cat. No. D97-4/00-039-2022E-PDF
#   - Effective date printed in the PDF: April 19, 2023 (revision 1)
#
# Provenance of this copy: supplied directly by the Cyber Centre's Cyber
# Skills Development Team on 2026-09-16, including Annexes A through F, with
# permission to use the material on condition that it is referenced when used.
#
# Structure (confirmed by reading the whole document):
#   Four activity areas / work categories, one per annex:
#     Annex A Oversee & govern      (A.1 - A.3,  3 core roles)
#     Annex B Design & develop      (B.1 - B.9,  9 core roles)
#     Annex C Operate & maintain    (C.1 - C.3,  3 core roles)
#     Annex D Protect & defend      (D.1 - D.7,  7 core roles)
#   = 22 core cyber security roles, each a two-column label/value page block.
#   Annex E Cyber adjacent roles is a single wide five-column table.
#   Annex F Cyber talent alliance is a membership list (not a role structure).
#
# Each core role block carries the document's own field labels, which this
# ingester preserves as element_type values: NICE framework reference,
# Functional description, Consequence of error or risk, Development pathway,
# Other titles, Related NOCs, Tasks, Required qualifications for education,
# Required training, Required work experience, Tools & technology,
# Competencies, Future trends affecting key competencies.
#
# The framework is an explicit adaptation of the U.S. NICE Workforce Framework
# for Cybersecurity, and cites NICE work role IDs (for example OV-EXL-001)
# in both the core role blocks and the Annex E table. Those citations are
# captured as their own crosswalk table.
#
# Licensing: Copyright Government of Canada. Used with written permission of
# the Canadian Centre for Cyber Security (Cyber Skills Development Team),
# 2026-09-16, on condition that the material is referenced when used.
#
# Run: Rscript scripts/010-ingest-ccssf.R

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
  library(pdftools)
})

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

ccssf_config <- list(
  framework         = "CCSSF",
  framework_version = "2022",
  version_date      = "2023-04-19",
  publisher         = "Canadian Centre for Cyber Security",
  pdf_filename      = "Canadian Cyber Security Skills Framework 2022 -ENG.pdf",
  pdf_copy_filename = "ccssf-2022-eng.pdf",
  text_filename     = "extracted-text.md",
  staging_dir       = here("data", "raw", "ccssf"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml",
  retrieved_date    = "2026-09-16",
  publication_id    = "ITSM.00.039",
  isbn              = "978-0-660-46231-8",
  catalogue_number  = "D97-4/00-039-2022E-PDF",
  license           = paste(
    "Copyright Government of Canada. Used with written permission of the",
    "Canadian Centre for Cyber Security (Cyber Skills Development Team),",
    "2026-09-16, on condition that the material is referenced when used."
  )
)

# The four activity areas / work categories, one annex each. Closed vocabulary,
# read from the annex headings in the source.
ccssf_activity_areas <- tibble::tribble(
  ~annex, ~activity_area,        ~first_page,
  "A",    "Oversee & govern",    24L,
  "B",    "Design & develop",    33L,
  "C",    "Operate & maintain",  58L,
  "D",    "Protect & defend",    65L
)

# Field labels used inside the core role blocks, exactly as printed, paired
# with the element_type slug written to the long table.
ccssf_field_labels <- tibble::tribble(
  ~label,                                  ~element_type,
  "NICE framework reference",              "nice_framework_reference",
  # C.1 prints this field as "NICE framework role"; same field, same meaning.
  "NICE framework role",                   "nice_framework_reference",
  "Functional description",                "functional_description",
  "Consequence of error or risk",          "consequence_of_error_or_risk",
  "Development pathway",                   "development_pathway",
  "Other titles",                          "other_titles",
  "Related NOCs",                          "related_nocs",
  "Tasks",                                 "tasks",
  "Required qualifications for education", "required_qualifications_for_education",
  "Required training",                     "required_training",
  "Required work experience",              "required_work_experience",
  "Tools & technology",                    "tools_and_technology",
  "Competencies",                          "competencies",
  "Future trends affecting key competencies", "future_trends_affecting_key_competencies"
)

# Boilerplate that bleeds into every page from the header and footer.
ccssf_boilerplate <- c(
  "UNCLASSIFIED / NON CLASSIFIE",
  "UNCLASSIFIED / NON CLASSIFIÉ",
  "TLP:CLEAR",
  "TLP: CLEAR",
  "ITSM.00.039"
)

# Glyphs poppler emits for the source's bullet characters.
ccssf_bullet_glyphs <- c("▪", "•", "●", "", "",
                         "", "§", "o", "−")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

#' Generate a stable slug from a title
#'
#' Same shape as slugify_profile_title() in 010-ingest-ecsf.R. Used only where
#' the source supplies no identifier of its own, which is the case for the
#' Annex E adjacent roles.
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

#' Repair PDF extraction artifacts in a run of text
#'
#' Repair rules applied here, and listed in provenance notes:
#'   1. ligature normalization (fi, fl, ff, ffi, ffl to ASCII letters)
#'   2. soft hyphen removal
#'   3. hyphenation at a line break rejoined (word- + word becomes word)
#'   4. non-breaking and zero-width spaces normalized to a plain space
#'   5. whitespace squished to single spaces, leading and trailing trimmed
#'   6. leading bullet glyph stripped
#' No other change is made. Curly quotes, accented characters, and the
#' source's own punctuation are left exactly as printed.
#'
#' @param x Character vector.
#' @return Character vector.
repair_pdf_text <- function(x) {
  x |>
    str_replace_all("ﬁ", "fi") |>
    str_replace_all("ﬂ", "fl") |>
    str_replace_all("ﬀ", "ff") |>
    str_replace_all("ﬃ", "ffi") |>
    str_replace_all("ﬄ", "ffl") |>
    str_replace_all("­", "") |>
    str_replace_all("[   ​]", " ") |>
    str_squish()
}

#' Rejoin a word hyphenated across a line break
#'
#' Applied when appending a continuation line to an element. A trailing hyphen
#' on the accumulated text followed by a lowercase letter is treated as
#' hyphenation and closed up; anything else is joined with a space.
#'
#' @param acc Character(1) accumulated so far.
#' @param nxt Character(1) next line.
#' @return Character(1).
join_continuation <- function(acc, nxt) {
  if (str_detect(acc, "[a-z]-$") && str_detect(nxt, "^[a-z]")) {
    paste0(str_sub(acc, 1, -2), nxt)
  } else {
    paste(acc, nxt)
  }
}

#' Strip header and footer boilerplate from a line
#'
#' Bare page numbers are dropped a line at a time elsewhere, not here: a cell
#' can legitimately hold a bare three-digit run, such as the second half of a
#' NICE work role id wrapped as "OV-LGA-" then "001".
#'
#' @param line Character(1).
#' @return Character(1), possibly empty.
strip_boilerplate <- function(line) {
  out <- line
  for (b in ccssf_boilerplate) out <- str_remove_all(out, fixed(b))
  str_squish(out)
}

#' Is this token one of the source's bullet glyphs?
#'
#' @param tok Character(1).
#' @return Logical(1).
is_bullet_glyph <- function(tok) {
  if (is.na(tok) || !nzchar(tok)) return(FALSE)
  tok %in% ccssf_bullet_glyphs || (nchar(tok) == 1 && !str_detect(tok, "[[:alnum:]]"))
}

# ---------------------------------------------------------------------------
# Extraction: intermediate text
# ---------------------------------------------------------------------------

#' Ensure the space-free working copy of the PDF exists
#'
#' The supplied filename contains spaces. Nothing is renamed; a byte-identical
#' copy with a space-free name is made beside it for tooling convenience, and
#' both names are recorded in provenance.
#'
#' @param staging_dir Character.
#' @return Character path to the working copy.
ensure_pdf_copy <- function(staging_dir) {
  src <- file.path(staging_dir, ccssf_config$pdf_filename)
  dst <- file.path(staging_dir, ccssf_config$pdf_copy_filename)
  if (!file.exists(src)) stop("Source PDF not found at ", src)
  if (!file.exists(dst)) file.copy(src, dst)
  dst
}

#' Write the page-marked intermediate text file
#'
#' @param pdf_path Character.
#' @param text_path Character.
#' @return Invisibly, the number of pages.
write_intermediate_text <- function(pdf_path, text_path) {
  pages <- pdf_text(pdf_path)
  out <- unlist(map2(seq_along(pages), pages, \(i, p) {
    c("", "", paste0("<!-- PAGE ", i, " -->"), "", p)
  }))
  writeLines(out, text_path, useBytes = TRUE)
  invisible(length(pages))
}

# ---------------------------------------------------------------------------
# Extraction: core role blocks (Annexes A through D)
# ---------------------------------------------------------------------------

#' Collapse a page's word table into positioned lines
#'
#' pdftools::pdf_data gives one row per word with x/y pixel coordinates. Words
#' sharing a baseline (within a small tolerance) are one visual line.
#'
#' @param page Data frame from pdf_data().
#' @return Tibble with columns: y, x_min, tokens (list), text.
page_lines <- function(page) {
  if (nrow(page) == 0) return(tibble(y = integer(), x_min = integer(),
                                     tokens = list(), text = character()))
  p <- page |>
    as_tibble() |>
    arrange(y, x) |>
    mutate(line_key = cumsum(c(1L, as.integer(diff(y) > 3))))

  # Within a line the reading order is left to right. A bullet glyph often
  # carries a baseline a pixel off its own text, so tokens are re-sorted by x
  # after grouping; without this a bullet lands after the words it introduces.
  p |>
    group_by(line_key) |>
    summarise(
      y      = min(y),
      x_min  = min(x),
      tokens = list(tibble(x = x, text = text) |> arrange(x)),
      text   = paste(text[order(x)], collapse = " "),
      .groups = "drop"
    ) |>
    arrange(y) |>
    select(y, x_min, tokens, text)
}

#' Locate the core role blocks and the pages each spans
#'
#' Role headings look like "A.1  Chief information security officer (CISO)" and
#' are the first line of their page. The block runs to the page before the next
#' role heading (or the next annex heading).
#'
#' @param pages List of pdf_data() page tables.
#' @return Tibble: role_id, title, annex, page_start, page_end.
locate_core_roles <- function(pages) {
  annex_starts <- map_int(seq_along(pages), \(i) {
    ln <- page_lines(pages[[i]])
    ln <- ln |> filter(!str_detect(text, "UNCLASSIFIED|TLP:"))
    if (nrow(ln) == 0) return(NA_integer_)
    if (str_detect(ln$text[1], "^Annex [A-F]\\b")) i else NA_integer_
  })
  annex_starts <- annex_starts[!is.na(annex_starts)]
  body_start <- if (length(annex_starts) > 0) min(annex_starts) else 1L

  headings <- map_dfr(seq_along(pages), \(i) {
    if (i < body_start) return(tibble())
    ln <- page_lines(pages[[i]])
    ln <- ln |> filter(!str_detect(text, "UNCLASSIFIED|TLP:"))
    if (nrow(ln) == 0) return(tibble())
    first <- ln$text[1]
    # Table-of-annexes entries carry dot leaders and a trailing page number.
    if (str_detect(first, "\\.{4,}")) return(tibble())
    m <- str_match(first, "^([A-D])\\.(\\d+)\\s+(.+)$")
    if (is.na(m[1, 1])) return(tibble())
    tibble(
      page    = i,
      role_id = paste0(m[1, 2], ".", m[1, 3]),
      annex   = m[1, 2],
      title   = repair_pdf_text(m[1, 4])
    )
  })

  headings |>
    distinct(role_id, .keep_all = TRUE) |>
    mutate(
      next_boundary = map_int(page, \(p) {
        cand <- c(headings$page[headings$page > p], annex_starts[annex_starts > p],
                  length(pages) + 1L)
        min(cand)
      }),
      page_start = page,
      page_end   = next_boundary - 1L
    ) |>
    select(role_id, title, annex, page_start, page_end)
}

#' Assemble the value lines of one core role block
#'
#' The block is a two-column table: printed field label on the left (x below
#' the split), value on the right. Two layout facts drive this:
#'
#'   1. A label's baseline sits a few pixels below the first line of its own
#'      value, so a label-only line is folded back into the value line just
#'      above it when they are within `label_offset` pixels.
#'   2. Labels wrap over several lines, and the wrapped fragments can sit
#'      beside later value lines of the same cell. Fragments are therefore
#'      accumulated until they match a known label, and the cell is anchored
#'      at the line where the first fragment appeared.
#'
#' Continuation pages carry value text across the full width with no label
#' column at all, which is why a left-column run that never matches a known
#' label is treated as ordinary value text.
#'
#' The label/value split is measured per page rather than assumed, because the
#' value column starts at a different offset in different role blocks.
#'
#' @param pages List of pdf_data() page tables.
#' @param role Single-row tibble from locate_core_roles().
#' @param label_offset Numeric vertical tolerance for folding a label line up.
#' @return List with rows (positioned lines) and labels (label per row, or NA).
core_role_lines <- function(pages, role, label_offset = 9) {
  known_labels <- ccssf_field_labels$label
  rows <- list()

  for (pg in role$page_start[1]:role$page_end[1]) {
    lines <- page_lines(pages[[pg]]) |>
      filter(!str_detect(text, "^UNCLASSIFIED|^TLP:|^ITSM\\.00\\.039")) |>
      filter(!str_detect(text, paste0("^", role$annex[1], "\\.\\d+\\s")))
    if (nrow(lines) == 0) next

    split <- value_column_x(lines)

    left_txt  <- character(nrow(lines))
    val_toks  <- vector("list", nrow(lines))
    for (i in seq_len(nrow(lines))) {
      toks <- lines$tokens[[i]]
      left_txt[i] <- str_squish(paste(toks$text[toks$x < split], collapse = " "))
      val_toks[[i]] <- toks |> filter(x >= split)
    }
    # A line with nothing in the value column is a label-only line; fold it
    # into the value line immediately above when they are close enough.
    keep <- rep(TRUE, nrow(lines))
    for (i in seq_len(nrow(lines))) {
      if (nrow(val_toks[[i]]) == 0 && nzchar(left_txt[i]) && i > 1) {
        j <- i - 1
        while (j >= 1 && !keep[j]) j <- j - 1
        if (j >= 1 && (lines$y[i] - lines$y[j]) <= label_offset) {
          left_txt[j] <- str_squish(paste(left_txt[j], left_txt[i]))
          keep[i] <- FALSE
        }
      }
    }

    idx <- which(keep)
    for (i in idx) {
      rows[[length(rows) + 1]] <- list(
        page = pg, y = lines$y[i], left = left_txt[i],
        full_toks  = lines$tokens[[i]],
        value_toks = val_toks[[i]]
      )
    }
  }

  if (length(rows) == 0) return(list())

  # Anchor each label at the line where its first fragment appeared. Only the
  # rows of a run that actually completes a known label give up their left
  # column; every other row keeps its full line as value text, which is what
  # makes continuation pages (no label column at all) parse correctly.
  labels   <- rep(NA_character_, length(rows))
  consumed <- rep(FALSE, length(rows))
  pending <- ""
  run <- integer(0)
  for (i in seq_along(rows)) {
    lt <- rows[[i]]$left
    if (!nzchar(lt)) next
    cand <- str_squish(paste(pending, lt))
    # Matching ignores case because the source prints one label two ways
    # ("Functional description" and "Functional Description").
    cand_l <- str_to_lower(cand)
    known_l <- str_to_lower(known_labels)
    if (any(str_starts(known_l, fixed(cand_l)))) {
      run <- c(run, i)
      if (cand_l %in% known_l) {
        labels[run[1]] <- known_labels[match(cand_l, known_l)]
        consumed[run] <- TRUE
        pending <- ""; run <- integer(0)
      } else {
        pending <- cand
      }
    } else {
      pending <- ""; run <- integer(0)
    }
  }

  for (i in seq_along(rows)) {
    rows[[i]]$toks <- if (consumed[i]) rows[[i]]$value_toks else rows[[i]]$full_toks
  }

  list(rows = rows, labels = labels)
}

#' Measure where a role block page's value column begins
#'
#' Labels sit in a narrow left column; the value column starts at the x offset
#' shared by most lines on the page. A continuation page has no label column,
#' in which case no offset qualifies and the whole width is value text.
#'
#' @param lines Tibble from page_lines().
#' @return Numeric x threshold.
value_column_x <- function(lines) {
  xs <- unlist(map(lines$tokens, \(t) t$x))
  if (length(xs) == 0) return(-Inf)
  label_x <- min(xs)
  cand <- xs[xs > label_x + 60]
  if (length(cand) == 0) return(-Inf)
  tab <- table(cand)
  tab <- tab[tab >= 4]
  if (length(tab) == 0) return(-Inf)
  min(as.numeric(names(tab))) - 5
}

# Pages where sub-bullet nesting could not be read off the indentation with
# confidence. Populated by assign_parent_index() and reported at the end of the
# run so the uncertainty is visible rather than silent.
ccssf_nesting_env <- new.env(parent = emptyenv())
ccssf_nesting_env$unclear_pages <- integer(0)

#' Record one level of sub-bullet nesting from x-coordinate indentation
#'
#' The source prints sub-bullets under a colon-terminated parent bullet (for
#' example D.7's "... which may include the following forensics for:" followed
#' by "computer", "network and active directory", ...). The text of those
#' sub-items is faithful as extracted; what the long table loses is which bullet
#' they hang under. This restores that link without touching any text.
#'
#' Read conservatively, one page and one field at a time. Fields are kept apart
#' because a parent can only be a bullet of the same field, and because two
#' fields on one page routinely indent their top-level bullets a few pixels
#' differently (page 69 prints Other titles at x 154 and Tasks at x 163, with no
#' nesting in either). Within a field on a page the bullet glyph x offsets are
#' clustered; nesting is recorded only when they fall cleanly into two clusters
#' separated by a real gap. One cluster means a flat field. Three or more means
#' the indentation does not read as a single level of nesting, so parent_index
#' is left NA there and the page is reported.
#'
#' @param el Tibble of elements in document order, with element_type,
#'   element_index, page, and bullet_x (NA for unbulleted elements).
#' @param cluster_tol Numeric; bullet x offsets within this many pixels are the
#'   same indentation level.
#' @param min_gap Numeric; minimum separation between the two levels.
#' @return The tibble with an integer parent_index column added.
assign_parent_index <- function(el, cluster_tol = 6, min_gap = 10) {
  el$parent_index <- NA_integer_
  keys <- el |>
    filter(!is.na(page), !is.na(bullet_x)) |>
    distinct(page, element_type) |>
    arrange(page, element_type)
  for (r in seq_len(nrow(keys))) {
    pg <- keys$page[r]
    idx <- which(el$page == pg & el$element_type == keys$element_type[r] &
                   !is.na(el$bullet_x))
    if (length(idx) < 2) next
    xs <- sort(unique(el$bullet_x[idx]))
    level <- cumsum(c(1L, as.integer(diff(xs) > cluster_tol)))
    level_min <- vapply(split(xs, level), min, numeric(1))
    if (length(level_min) == 1) next
    if (length(level_min) > 2 || (level_min[2] - level_min[1]) < min_gap) {
      ccssf_nesting_env$unclear_pages <- union(ccssf_nesting_env$unclear_pages, pg)
      next
    }
    is_sub <- el$bullet_x[idx] >= level_min[2] - cluster_tol
    for (k in seq_along(idx)) {
      if (!is_sub[k]) next
      earlier <- idx[seq_len(k - 1)][!is_sub[seq_len(k - 1)]]
      earlier <- earlier[el$element_type[earlier] == el$element_type[idx[k]]]
      if (length(earlier) > 0) {
        el$parent_index[idx[k]] <- el$element_index[max(earlier)]
      }
    }
  }
  el
}

#' Parse one core role block into label/value elements
#'
#' Element boundaries inside a value follow the source's own bulleting: a
#' bullet glyph starts a new element; an unbulleted line starts a new element
#' when it is outdented relative to the current bullet text, or when it follows
#' a vertical gap, or when the previous element ended with a colon. Everything
#' else is a continuation of the element above it.
#'
#' @param pages List of pdf_data() page tables.
#' @param role Single-row tibble from locate_core_roles().
#' @return Tibble: role_id, element_type, element_index, element_text.
parse_core_role <- function(pages, role) {
  parsed <- core_role_lines(pages, role)
  if (length(parsed) == 0) return(tibble())
  rows <- parsed$rows
  labels <- parsed$labels

  elements <- list()
  current_label <- NA_character_
  cur_text <- NA_character_
  cur_bullet_x <- NA_real_
  prev_y <- NA_real_
  prev_page <- NA_integer_
  # Indentation and page of the line that opened the current element, kept so
  # one level of sub-bullet nesting can be recovered later. NA where the
  # element opened on an unbulleted line.
  cur_indent <- NA_real_
  cur_page   <- NA_integer_

  flush <- function() {
    if (!is.na(cur_text) && nzchar(cur_text) && !is.na(current_label)) {
      elements[[length(elements) + 1]] <<- tibble(
        label        = current_label,
        element_text = repair_pdf_text(cur_text),
        bullet_x     = cur_indent,
        page         = cur_page
      )
    }
    cur_text <<- NA_character_
  }

  for (i in seq_along(rows)) {
    if (!is.na(labels[i])) {
      flush()
      current_label <- labels[i]
      cur_bullet_x  <- NA_real_
    }

    value_toks <- rows[[i]]$toks
    if (nrow(value_toks) == 0) next

    vtext <- strip_boilerplate(str_squish(paste(value_toks$text, collapse = " ")))
    if (!nzchar(vtext) || str_detect(vtext, "^\\d{1,3}$")) next

    bulleted <- is_bullet_glyph(value_toks$text[1]) && nrow(value_toks) > 1
    line_x   <- min(value_toks$x)

    gap <- if (!is.na(prev_y) && identical(prev_page, rows[[i]]$page)) {
      rows[[i]]$y - prev_y
    } else {
      NA_real_
    }
    big_gap <- !is.na(gap) && gap > 19

    starts_new <- if (bulleted) {
      TRUE
    } else if (is.na(cur_text)) {
      TRUE
    } else if (!is.na(cur_bullet_x) && line_x < cur_bullet_x - 3) {
      TRUE
    } else if (str_detect(str_trim(cur_text), ":$")) {
      TRUE
    } else if (big_gap) {
      TRUE
    } else {
      FALSE
    }

    if (bulleted) {
      body <- str_squish(paste(value_toks$text[-1], collapse = " "))
      cur_bullet_x <- value_toks$x[2]
    } else {
      body <- vtext
    }

    if (starts_new) {
      flush()
      cur_text   <- body
      cur_indent <- if (bulleted) as.numeric(value_toks$x[1]) else NA_real_
      cur_page   <- as.integer(rows[[i]]$page)
    } else {
      cur_text <- join_continuation(cur_text, body)
    }

    prev_y <- rows[[i]]$y; prev_page <- rows[[i]]$page
  }
  flush()

  if (length(elements) == 0) return(tibble())

  bind_rows(elements) |>
    filter(nzchar(element_text)) |>
    left_join(ccssf_field_labels, by = "label") |>
    mutate(role_id = role$role_id) |>
    group_by(element_type) |>
    mutate(element_index = row_number()) |>
    ungroup() |>
    assign_parent_index() |>
    select(role_id, element_type, element_index, element_text, parent_index)
}

# ---------------------------------------------------------------------------
# Extraction: Annex E adjacent roles table
# ---------------------------------------------------------------------------

#' Find the pages carrying the Annex E table
#'
#' @param pages List of pdf_data() page tables.
#' @return Integer vector of page numbers.
locate_annex_e_pages <- function(pages) {
  starts <- map_int(seq_along(pages), \(i) {
    ln <- page_lines(pages[[i]]) |> filter(!str_detect(text, "UNCLASSIFIED|TLP:"))
    if (nrow(ln) == 0) return(NA_integer_)
    if (str_detect(ln$text[1], "^Annex E\\b")) i else NA_integer_
  })
  starts <- starts[!is.na(starts)]
  if (length(starts) == 0) return(integer())

  ends <- map_int(seq_along(pages), \(i) {
    ln <- page_lines(pages[[i]]) |> filter(!str_detect(text, "UNCLASSIFIED|TLP:"))
    if (nrow(ln) == 0) return(NA_integer_)
    if (str_detect(ln$text[1], "^Annex F\\b")) i else NA_integer_
  })
  ends <- ends[!is.na(ends)]
  last_page <- if (length(ends) > 0) min(ends) - 1L else length(pages)
  starts[1]:last_page
}

#' Derive the Annex E column boundaries from the repeated header row
#'
#' The five-column header ("Activity area/work category", "Common title or work
#' role", "NICE ID", "NOC", "Major cyber security responsibility", "Key cyber
#' security competencies") is reprinted on every page of the table, and its
#' word positions give the column x offsets for that page.
#'
#' @param page Data frame from pdf_data().
#' @return Named numeric vector of column left edges, or NULL.
annex_e_columns <- function(page) {
  p <- as_tibble(page)
  hdr_y <- p |> filter(text == "Activity") |> pull(y)
  if (length(hdr_y) == 0) return(NULL)
  hdr_y <- hdr_y[1]
  row <- p |> filter(abs(y - hdr_y) <= 3)
  getx <- function(w) {
    v <- row |> filter(text == w) |> pull(x)
    if (length(v) == 0) NA_real_ else v[1]
  }
  cols <- c(
    activity_area  = getx("Activity"),
    title          = getx("Common"),
    nice_id        = getx("NICE"),
    noc            = getx("NOC"),
    responsibility = getx("Major"),
    competencies   = getx("Key")
  )
  if (any(is.na(cols))) return(NULL)
  cols
}

#' Parse the Annex E adjacent roles table
#'
#' Each page is cut into the five data columns using that page's own header
#' positions. A run of consecutive lines with content in the title column is
#' one role; a title run carrying neither a NICE ID nor a NOC is treated as the
#' continuation of the previous role's wrapped title rather than a new role.
#'
#' @param pages List of pdf_data() page tables.
#' @param page_nums Integer vector from locate_annex_e_pages().
#' @return List with two tibbles: roles and competencies.
parse_annex_e <- function(pages, page_nums) {
  cells <- list()

  for (pg in page_nums) {
    cols <- annex_e_columns(pages[[pg]])
    if (is.null(cols)) next
    bounds <- c(cols[["activity_area"]] - 25, cols[["title"]] - 25,
                cols[["nice_id"]] - 25, cols[["noc"]] - 25,
                cols[["responsibility"]] - 25, cols[["competencies"]] - 25, Inf)
    names(bounds) <- c("activity_area", "title", "nice_id", "noc",
                       "responsibility", "competencies", "end")

    hdr_y <- as_tibble(pages[[pg]]) |> filter(text == "Activity") |> pull(y)
    hdr_bottom <- if (length(hdr_y) > 0) hdr_y[1] + 40 else 0

    lines <- page_lines(pages[[pg]]) |>
      filter(y > hdr_bottom) |>
      filter(!str_detect(text, "^UNCLASSIFIED|^TLP:|^ITSM\\.00\\.039")) |>
      filter(!str_detect(str_squish(text), "^\\d{1,3}$"))

    for (i in seq_len(nrow(lines))) {
      toks <- lines$tokens[[i]]
      if (nrow(toks) == 0) next
      cut_text <- function(lo, hi) {
        s <- toks |> filter(x >= lo, x < hi)
        if (nrow(s) == 0) return("")
        strip_boilerplate(str_squish(paste(s$text, collapse = " ")))
      }
      cells[[length(cells) + 1]] <- tibble(
        page           = pg,
        y              = lines$y[i],
        activity_area  = cut_text(bounds[["activity_area"]], bounds[["title"]]),
        title          = cut_text(bounds[["title"]], bounds[["nice_id"]]),
        nice_id        = cut_text(bounds[["nice_id"]], bounds[["noc"]]),
        noc            = cut_text(bounds[["noc"]], bounds[["responsibility"]]),
        responsibility = cut_text(bounds[["responsibility"]], bounds[["competencies"]]),
        comp_line      = cut_text(bounds[["competencies"]], bounds[["end"]]),
        comp_x         = {
          s <- toks |> filter(x >= bounds[["competencies"]])
          if (nrow(s) == 0) NA_real_ else min(s$x)
        }
      )
    }
  }

  if (length(cells) == 0) return(list(roles = tibble(), competencies = tibble()))
  grid <- bind_rows(cells) |> arrange(page, y)

  # The activity area is printed once for a whole group of roles and wraps
  # across lines, so fragments from the activity column are collected in a
  # rolling buffer and matched against the document's own area names. The
  # matched name is then carried forward until the next one appears.
  known_areas <- ccssf_activity_areas$activity_area
  area_block <- rep(NA_character_, nrow(grid))
  buf <- character(0)
  buf_start <- NA_integer_
  last_frag <- NA_integer_
  anchors <- list()
  for (i in seq_len(nrow(grid))) {
    if (!nzchar(grid$activity_area[i])) next
    # Only a contiguous run of activity-column lines can spell one area name;
    # a fragment that arrives after a gap starts a fresh buffer.
    if (length(buf) == 0 || is.na(last_frag) || (i - last_frag) > 2) {
      buf <- character(0)
      buf_start <- i
    }
    last_frag <- i
    buf <- tail(c(buf, grid$activity_area[i]), 6)
    joined <- str_to_lower(str_squish(paste(buf, collapse = " ")))
    hit <- known_areas[map_lgl(known_areas, \(a) {
      str_detect(joined, fixed(str_to_lower(a)))
    })]
    if (length(hit) > 0) {
      # The name is anchored where its first fragment appeared, not where it
      # finished wrapping, or the first role of the group is left behind.
      anchors[[length(anchors) + 1]] <- list(at = buf_start, area = hit[length(hit)])
      buf <- character(0); buf_start <- NA_integer_
    }
  }
  for (a in anchors) area_block[a$at] <- a$area
  current_area <- NA_character_
  for (i in seq_len(nrow(grid))) {
    if (!is.na(area_block[i])) current_area <- area_block[i]
    area_block[i] <- current_area
  }
  # The first area name is printed level with the first role's own row, so the
  # lines above the match carry it backwards.
  first_known <- which(!is.na(area_block))
  if (length(first_known) > 0 && first_known[1] > 1) {
    area_block[1:(first_known[1] - 1)] <- area_block[first_known[1]]
  }
  grid$area_carried <- area_block

  # A role starts where its NICE ID cell starts. A wrapped id continues on the
  # next line as a bare numeric fragment, which is why only "None" or a
  # category prefix (two or three letters) counts as the start of a cell.
  starts <- which(str_detect(grid$nice_id, "^[A-Z]{2,3}-") |
                    str_detect(str_to_lower(grid$nice_id), "^none"))
  if (length(starts) == 0) return(list(roles = tibble(), competencies = tibble()))

  roles <- list()
  comps <- list()

  for (k in seq_along(starts)) {
    start <- starts[k]
    end <- if (k < length(starts)) starts[k + 1] - 1L else nrow(grid)
    span <- grid[start:end, ]

    title_txt <- repair_pdf_text(paste(span$title[nzchar(span$title)], collapse = " "))
    nice_txt  <- repair_pdf_text(paste(span$nice_id[nzchar(span$nice_id)], collapse = ""))
    noc_txt   <- repair_pdf_text(paste(span$noc[nzchar(span$noc)], collapse = " "))
    area_txt  <- span$area_carried[1]
    resp_txt  <- repair_pdf_text(paste(span$responsibility[nzchar(span$responsibility)],
                                       collapse = " "))

    rid <- slugify_profile_title(title_txt)
    roles[[length(roles) + 1]] <- list(
      adjacent_role_id = rid,
      title            = title_txt,
      activity_area    = if (is.na(area_txt)) "" else area_txt,
      nice_id          = nice_txt,
      noc              = noc_txt,
      responsibility   = resp_txt
    )
    target_id <- rid

    # Competency cell: unbulleted wrapped lines. A line that starts at the
    # column's left edge begins a competency; a deeper indent continues it.
    cl <- span |> filter(nzchar(comp_line))
    if (nrow(cl) > 0) {
      acc <- NA_character_
      for (k in seq_len(nrow(cl))) {
        # Competency statements are unbulleted and wrap at the same left edge,
        # so indentation says nothing. A wrapped line is recognized by the
        # source's own sentence shape instead: it opens in lowercase or with a
        # bracket, or the line above it ends mid-construction (unclosed
        # parenthesis, dangling comma or conjunction).
        wraps <- !is.na(acc) && (
          str_detect(cl$comp_line[k], "^[a-z(]") ||
            str_count(acc, fixed("(")) > str_count(acc, fixed(")")) ||
            str_detect(acc, "(,|\\band\\b|\\bor\\b|&)$")
        )
        if (is.na(acc) || !wraps) {
          if (!is.na(acc)) {
            comps[[length(comps) + 1]] <- tibble(adjacent_role_id = target_id,
                                                 competency = repair_pdf_text(acc))
          }
          acc <- cl$comp_line[k]
        } else {
          acc <- join_continuation(acc, cl$comp_line[k])
        }
      }
      if (!is.na(acc)) {
        comps[[length(comps) + 1]] <- tibble(adjacent_role_id = target_id,
                                             competency = repair_pdf_text(acc))
      }
    }
  }

  roles_tbl <- map_dfr(roles, as_tibble) |>
    mutate(across(everything(), repair_pdf_text)) |>
    filter(nzchar(title))

  comps_tbl <- if (length(comps) == 0) tibble() else {
    bind_rows(comps) |>
      filter(nzchar(competency)) |>
      group_by(adjacent_role_id) |>
      mutate(element_index = row_number()) |>
      ungroup() |>
      select(adjacent_role_id, element_index, competency)
  }

  list(roles = roles_tbl, competencies = comps_tbl)
}

# ---------------------------------------------------------------------------
# Crosswalk
# ---------------------------------------------------------------------------

# A NICE (2017-era) work role id is a two OR three letter category, a hyphen, a
# three letter specialty, a hyphen, and three digits: OV-EXL-001, SP-TRD-001,
# INV-FOR-002. The category is not always two letters, so the pattern is
# anchored on word boundaries; a fixed two-letter assumption clips the leading
# letter off the three-letter categories.
nice_id_canonical_rx <- "\\b[A-Z]{2,3}-[A-Z]{3}-\\d{3}\\b"

# The source prints some ids with a space where a hyphen belongs and with
# inconsistent letter case ("SP-ARC 002", "SP Dev-001"). This tolerant pattern
# captures the token exactly as printed so a malformed citation is preserved
# rather than dropped.
nice_id_tolerant_rx <- "\\b[A-Za-z]{2,3}[- ][A-Za-z]{3}[- ]\\d{3}\\b"

#' Normalize a printed NICE work role id, but only where it is unambiguous
#'
#' Normalization is purely typographic: a space standing in for a hyphen is
#' closed up, and letter case is raised. Nothing else is inferred. If the
#' result is not a canonical id, NA is returned rather than a guess.
#'
#' @param as_printed Character vector of id tokens exactly as the source prints.
#' @return Character vector of canonical ids, or NA where normalization would
#'   require more than the two typographic repairs above.
normalize_nice_id <- function(as_printed) {
  map_chr(as_printed, \(tok) {
    if (is.na(tok)) return(NA_character_)
    cand <- str_to_upper(str_replace_all(tok, " ", "-"))
    if (str_detect(cand, paste0("^", nice_id_canonical_rx, "$"))) {
      cand
    } else {
      NA_character_
    }
  })
}

#' Pull every cited NICE work role id out of a reference string
#'
#' Returns one row per citation with the token as printed alongside its
#' normalized form. A string citing no id at all (for example "None.") yields a
#' single all-NA row so the absence stays visible in the crosswalk.
#'
#' @param txt Character vector.
#' @return List of tibbles, one per input element.
extract_nice_ids <- function(txt) {
  map(txt, \(s) {
    toks <- if (is.na(s)) character(0) else str_extract_all(s, nice_id_tolerant_rx)[[1]]
    if (length(toks) == 0) {
      tibble(nice_work_role_id_as_printed = NA_character_,
             nice_work_role_id_normalized = NA_character_)
    } else {
      tibble(nice_work_role_id_as_printed = toks,
             nice_work_role_id_normalized = normalize_nice_id(toks))
    }
  })
}

#' Build the NICE crosswalk from both role tables
#'
#' The framework cites NICE work role IDs in the form XX-XXX-000 or
#' XXX-XXX-000. Three id columns are written:
#'
#'   nice_work_role_id_as_printed  the token exactly as the source prints it,
#'                                 typos included, for every row citing one
#'   nice_work_role_id_normalized  the canonical form, only where normalization
#'                                 is unambiguous and purely typographic
#'   nice_work_role_id             alias of the normalized value, kept under its
#'                                 original name for downstream readers
#'
#' plus id_malformed_in_source, TRUE where the printed token differs from its
#' canonical form. Where a role block says "None" all four stay NA so the
#' absence is visible.
#'
#' @param core_roles Tibble from build_role_catalog().
#' @param adjacent Tibble of Annex E roles.
#' @return Tibble: source_table, role_id, title, nice_reference_raw,
#'   nice_work_role_id, nice_work_role_id_as_printed,
#'   nice_work_role_id_normalized, id_malformed_in_source.
build_nice_crosswalk <- function(core_roles, adjacent) {
  core <- core_roles |>
    mutate(ids = extract_nice_ids(nice_reference)) |>
    select(role_id, title, nice_reference, ids) |>
    tidyr::unnest(ids) |>
    transmute(source_table = "core_role", role_id, title,
              nice_reference_raw = nice_reference,
              nice_work_role_id_as_printed, nice_work_role_id_normalized)

  adj <- adjacent |>
    mutate(ids = extract_nice_ids(nice_id)) |>
    select(adjacent_role_id, title, nice_id, ids) |>
    tidyr::unnest(ids) |>
    transmute(source_table = "adjacent_role", role_id = adjacent_role_id, title,
              nice_reference_raw = nice_id,
              nice_work_role_id_as_printed, nice_work_role_id_normalized)

  bind_rows(core, adj) |>
    mutate(
      nice_work_role_id = nice_work_role_id_normalized,
      id_malformed_in_source = if_else(
        is.na(nice_work_role_id_as_printed),
        NA,
        is.na(nice_work_role_id_normalized) |
          nice_work_role_id_as_printed != nice_work_role_id_normalized
      )
    ) |>
    select(source_table, role_id, title, nice_reference_raw, nice_work_role_id,
           nice_work_role_id_as_printed, nice_work_role_id_normalized,
           id_malformed_in_source)
}

# ---------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------

#' Build the core role catalog (one row per core role)
#'
#' @param role_index Tibble from locate_core_roles().
#' @param elements_long Tibble of parsed elements.
#' @return Tibble: role_id, title, annex, grouping, description, nice_reference.
build_role_catalog <- function(role_index, elements_long) {
  first_of <- function(rid, etype) {
    v <- elements_long |>
      filter(role_id == rid, element_type == etype) |>
      pull(element_text)
    if (length(v) == 0) NA_character_ else paste(v, collapse = " ")
  }

  role_index |>
    left_join(ccssf_activity_areas |> select(annex, activity_area), by = "annex") |>
    mutate(
      grouping       = activity_area,
      description    = map_chr(role_id, first_of, etype = "functional_description"),
      nice_reference = map_chr(role_id, first_of, etype = "nice_framework_reference")
    ) |>
    select(role_id, title, grouping, description, nice_reference, annex,
           page_start, page_end)
}

#' Read the count of core roles the document itself declares
#'
#' The table of annexes lists every core role section (A.1 through D.7). This
#' counts those listed entries, giving an expected role count that comes from
#' the document rather than from this script.
#'
#' @param text_path Character path to extracted-text.md.
#' @return Integer.
declared_role_count <- function(text_path) {
  lines <- read_lines(text_path)
  toc <- lines[str_detect(lines, "^\\s{1,4}[A-D]\\.\\d+\\s+\\S.*\\.{5,}\\s*\\d+\\s*$")]
  ids <- str_extract(toc, "[A-D]\\.\\d+")
  length(unique(ids[!is.na(ids)]))
}

# ---------------------------------------------------------------------------
# Integrity checks
# ---------------------------------------------------------------------------

#' Run the in-script integrity checks
#'
#' @param role_catalog Tibble.
#' @param elements_long Tibble.
#' @param adjacent Tibble.
#' @param adj_comps Tibble.
#' @param declared_n Integer, the document's own core role count.
#' @return Invisibly, a list of check results.
run_integrity_checks <- function(role_catalog, elements_long, adjacent,
                                 adj_comps, declared_n) {
  message("\n--- Integrity checks ---")

  ok_count <- nrow(role_catalog) == declared_n
  message("  Core roles parsed: ", nrow(role_catalog),
          " | declared by document: ", declared_n,
          if (ok_count) "  [OK]" else "  [MISMATCH]")

  dup_core <- role_catalog$role_id[duplicated(role_catalog$role_id)]
  message("  Duplicate core role_id: ",
          if (length(dup_core) == 0) "none  [OK]" else paste(dup_core, collapse = ", "))

  dup_adj <- adjacent$adjacent_role_id[duplicated(adjacent$adjacent_role_id)]
  message("  Duplicate adjacent_role_id: ",
          if (length(dup_adj) == 0) "none  [OK]" else paste(dup_adj, collapse = ", "))

  empty_elem <- sum(!nzchar(str_trim(elements_long$element_text)))
  message("  Empty element_text rows: ", empty_elem,
          if (empty_elem == 0) "  [OK]" else "  [CHECK]")

  short <- elements_long |> filter(str_length(element_text) < 15)
  long  <- elements_long |> filter(str_length(element_text) > 600)
  message("  Elements under 15 characters: ", nrow(short),
          if (nrow(short) > 0) "  [flagged for manual look]" else "")
  if (nrow(short) > 0) {
    print(short |> select(role_id, element_type, element_text) |> head(25))
  }
  message("  Elements over 600 characters: ", nrow(long),
          if (nrow(long) > 0) "  [flagged for manual look]" else "")
  if (nrow(long) > 0) {
    print(long |> mutate(chars = str_length(element_text)) |>
            select(role_id, element_type, chars) |> head(25))
  }

  n_parented <- sum(!is.na(elements_long$parent_index))
  message("  Elements recorded as sub-bullets (parent_index set): ", n_parented,
          " of ", nrow(elements_long))
  if (n_parented > 0) {
    print(elements_long |> filter(!is.na(parent_index)) |>
            count(role_id, element_type, name = "sub_bullets"))
  }
  if (length(ccssf_nesting_env$unclear_pages) > 0) {
    message("  Pages whose bullet indentation is not cleanly bimodal ",
            "(parent_index left NA there): ",
            paste(sort(ccssf_nesting_env$unclear_pages), collapse = ", "))
  } else {
    message("  Pages with ambiguous bullet indentation: none  [OK]")
  }

  missing_desc <- role_catalog |> filter(is.na(description))
  if (nrow(missing_desc) > 0) {
    message("  Roles with no functional description: ",
            paste(missing_desc$role_id, collapse = ", "), "  [CHECK]")
  }

  no_comp <- setdiff(adjacent$adjacent_role_id, adj_comps$adjacent_role_id)
  if (length(no_comp) > 0) {
    message("  Adjacent roles with no competencies parsed: ",
            paste(no_comp, collapse = ", "), "  [CHECK]")
  }

  invisible(list(
    role_count_ok = ok_count,
    empty_elements = empty_elem,
    short_elements = nrow(short),
    long_elements  = nrow(long)
  ))
}

#' Spot-check parsed elements against the source page text
#'
#' Picks five roles at random (seeded) and three elements from each, then looks
#' for the parsed text inside the whitespace-normalized text of the pages the
#' role spans. Reports exact matches against discrepancies.
#'
#' @param pages_text Character vector from pdf_text().
#' @param role_catalog Tibble.
#' @param elements_long Tibble.
#' @return Tibble of spot-check results.
spot_check_fidelity <- function(pages_text, role_catalog, elements_long) {
  set.seed(2026)
  picked <- sample(role_catalog$role_id, min(5, nrow(role_catalog)))

  normalize <- function(x) {
    x |>
      repair_pdf_text() |>
      str_replace_all("[‘’]", "'") |>
      str_replace_all("[“”]", "\"") |>
      str_to_lower()
  }

  results <- map_dfr(picked, \(rid) {
    role <- role_catalog |> filter(role_id == rid)
    src <- normalize(paste(pages_text[role$page_start:role$page_end], collapse = " "))
    pool <- elements_long |>
      filter(role_id == rid, str_length(element_text) >= 25)
    if (nrow(pool) == 0) return(tibble())
    idx <- sample(seq_len(nrow(pool)), min(3, nrow(pool)))
    pool[idx, ] |>
      mutate(
        matched = map_lgl(element_text, \(t) str_detect(src, fixed(normalize(t)))),
        role_id = rid
      ) |>
      select(role_id, element_type, element_index, matched, element_text)
  })

  message("\n--- Fidelity spot check (set.seed(2026)) ---")
  message("  Roles sampled: ", paste(picked, collapse = ", "))
  message("  Elements checked: ", nrow(results),
          " | exact matches: ", sum(results$matched),
          " | discrepancies: ", sum(!results$matched))
  if (any(!results$matched)) {
    message("  Discrepancies:")
    print(results |> filter(!matched) |>
            mutate(element_text = str_trunc(element_text, 120)) |>
            select(role_id, element_type, element_index, element_text))
  }
  results
}

# ---------------------------------------------------------------------------
# Provenance
# ---------------------------------------------------------------------------

write_provenance_manifest <- function(pdf_path, pdf_copy_path, text_path,
                                      role_catalog, elements_long,
                                      adjacent, adj_comps, crosswalk,
                                      page_count, declared_n, spot) {
  manifest <- list(
    framework         = ccssf_config$framework,
    framework_version = ccssf_config$framework_version,
    framework_name    = "The Canadian Cyber Security Skills Framework",
    publication_id    = ccssf_config$publication_id,
    version_date      = ccssf_config$version_date,
    # Same date under the key the downstream pipeline reads. 016 and the
    # assembler look for framework_date first; version_date is kept so the
    # manifest's existing readers are unaffected.
    framework_date    = ccssf_config$version_date,
    source = list(
      type             = "official_pdf_supplied_by_steward",
      publisher        = ccssf_config$publisher,
      filename         = ccssf_config$pdf_filename,
      working_copy     = ccssf_config$pdf_copy_filename,
      working_copy_note = paste(
        "Byte-identical copy of the supplied file under a space-free name.",
        "Nothing was renamed; both names are recorded here."
      ),
      text_filename    = ccssf_config$text_filename,
      isbn             = ccssf_config$isbn,
      catalogue_number = ccssf_config$catalogue_number,
      conversion_tool  = paste0("pdftools ", as.character(packageVersion("pdftools")),
                                " (pdf_text and pdf_data)"),
      supplied_by      = "Cyber Skills Development Team, Canadian Centre for Cyber Security",
      includes_annexes = "A, B, C, D, E, F"
    ),
    retrieval = list(
      retrieved_date  = ccssf_config$retrieved_date,
      retrieved_by    = "scripts/010-ingest-ccssf.R",
      pdf_size_bytes  = as.integer(file.info(pdf_path)$size),
      pdf_sha256      = digest(file = pdf_path, algo = "sha256"),
      working_copy_sha256 = digest(file = pdf_copy_path, algo = "sha256"),
      text_sha256     = digest(file = text_path, algo = "sha256"),
      page_count      = page_count
    ),
    extraction = list(
      activity_areas          = nrow(ccssf_activity_areas),
      core_roles              = nrow(role_catalog),
      core_roles_declared_by_document = declared_n,
      core_role_elements      = nrow(elements_long),
      core_role_elements_with_parent = sum(!is.na(elements_long$parent_index)),
      pages_with_ambiguous_indentation = as.list(as.integer(
        sort(ccssf_nesting_env$unclear_pages))),
      element_type_breakdown  = elements_long |>
        count(element_type) |>
        deframe() |>
        as.list(),
      adjacent_roles          = nrow(adjacent),
      adjacent_role_competencies = nrow(adj_comps),
      nice_work_role_references  = sum(!is.na(crosswalk$nice_work_role_id)),
      spot_check = list(
        seed          = 2026,
        elements_checked = nrow(spot),
        exact_matches = sum(spot$matched),
        discrepancies = sum(!spot$matched)
      ),
      extraction_scope = paste(
        "Complete for the 22 core role blocks in Annexes A through D and for",
        "the Annex E adjacent-role table. Annex F is a membership list and is",
        "not ingested as role structure. Figures (Figures 1 through 6) are",
        "images and carry text that no text-layer extraction recovers."
      )
    ),
    licensing = list(
      source_license = ccssf_config$license,
      redistribution = paste(
        "Permission covers use with attribution. Reference the publication",
        "(ITSM.00.039) wherever the material or a derivative of it is used."
      )
    ),
    notes = list(
      framework_type = paste(
        "National workforce framework; an explicit adaptation of the U.S. NICE",
        "Workforce Framework for Cybersecurity for the Canadian labour market."
      ),
      organizing_structure = paste(
        "Four activity areas / work categories (oversee & govern, design &",
        "develop, operate & maintain, protect & defend), one per annex,",
        "each containing core cyber security work roles. Identifiers are the",
        "document's own annex section numbers (A.1 through D.7)."
      ),
      identifiers = paste(
        "Core roles use the document's own section identifiers. Annex E",
        "adjacent roles carry no identifier in the source, so stable slugs",
        "are generated from their printed titles, the same way",
        "slugify_profile_title() does in 010-ingest-ecsf.R."
      ),
      nice_cross_reference = paste(
        "Core role blocks carry a 'NICE framework reference' field and the",
        "Annex E table a 'NICE ID' column, both citing NICE work role IDs",
        "such as OV-EXL-001. These are captured in tables/nice-crosswalk.csv.",
        "Several roles state 'None', meaning the Canadian framework defines a",
        "role the NICE framework does not; those rows are kept with an empty",
        "id so the absence stays visible. TKS or KSA element IDs are not",
        "cited anywhere in the document; only work role IDs are.",
        "A NICE work role id is a two or three letter category, a hyphen, a",
        "three letter specialty, a hyphen, and three digits; the three-letter",
        "categories (INV) are why the pattern is not fixed at two letters."
      ),
      nice_id_columns = paste(
        "tables/nice-crosswalk.csv carries three id columns and one flag.",
        "nice_work_role_id_as_printed holds the id token exactly as the source",
        "prints it, typos included, for every row that cites one.",
        "nice_work_role_id_normalized holds the canonical form ONLY where",
        "normalization is unambiguous and purely typographic, meaning a space",
        "standing in for a hyphen and letter case; nothing else is inferred,",
        "and anything needing more is left empty rather than guessed.",
        "nice_work_role_id is an alias of the normalized value, kept under its",
        "original name for readers written against the earlier tables; for a",
        "well-formed row as_printed and normalized are identical.",
        "id_malformed_in_source is true where the printed token differs from",
        "its canonical form. Rows whose reference reads 'None' are empty in",
        "all four. Two core roles print a malformed id: B.1 'SP-ARC 002' and",
        "B.3 'SP Dev-001'. Both are preserved as printed and normalized to",
        "SP-ARC-002 and SP-DEV-001; the source text itself is not corrected."
      ),
      extraction_method = paste(
        "pdftools::pdf_data supplies per-word coordinates. Core role pages are",
        "a two-column label/value table whose split is measured per page from",
        "the x offset most lines share, because the value column starts in a",
        "different place in different role blocks. A label's baseline sits a",
        "few pixels below the first line of its own value, so a label-only",
        "line is folded back into the value line above it; printed field labels",
        "wrap over lines and are accumulated until they match the known label",
        "set. Element boundaries follow the source's own bulleting: a bullet",
        "glyph opens an element, and an unbulleted line opens one only when it",
        "is outdented from the current bullet, follows a vertical gap, or",
        "follows a line ending in a colon. Annex E is cut into its five",
        "columns using the header row reprinted on each page."
      ),
      repair_rules = paste(
        "Applied to every extracted run, and nothing else:",
        "(1) ligature normalization (fi, fl, ff, ffi, ffl);",
        "(2) soft hyphen removal;",
        "(3) hyphenation across a line break rejoined when a trailing hyphen",
        "meets a lowercase continuation;",
        "(4) non-breaking and zero-width spaces normalized to a plain space;",
        "(5) whitespace squished and trimmed;",
        "(6) leading bullet glyph stripped.",
        "No paraphrase, no merging or splitting beyond the source's bulleting,",
        "no correction of the source's own typographical errors."
      ),
      sub_bullet_nesting = paste(
        "The source prints one level of sub-bullets under a colon-terminated",
        "parent bullet, for example D.7's 'Types of digital forensics ... which",
        "may include the following forensics for:' followed by 'computer',",
        "'network and active directory', 'mobile devices', 'digital media",
        "(image, video, audio)' and 'memory'. Those single-word rows are the",
        "faithful content of the source and are not altered.",
        "tables/role-elements-long.csv carries a parent_index column recording",
        "which bullet a sub-bullet hangs under (the parent's element_index",
        "within the same role and element_type); it is empty for top-level",
        "rows. Nesting is read off the bullet glyph x offsets one page and one",
        "field at a time, and only where they fall cleanly into two clusters",
        "separated by a real gap; anything less clean is left empty and",
        "reported by the run's integrity checks. Fields are kept apart because",
        "a parent can only be a bullet of the same field and because two fields",
        "on one page routinely indent their top-level bullets a few pixels",
        "differently. On this edition 30 rows across A.2, A.3, B.2, D.1 and D.7",
        "take a parent, and every one of those parents is a bullet the source",
        "ends with a colon. No text is changed by this; only the parent link",
        "is added."
      ),
      extraction_limitations = paste(
        "Sub-bullets inside the Competencies field remain one row each rather",
        "than nested rows; their parent is recorded in parent_index rather",
        "than in the table's shape. Lead-in lines such as",
        "'Basic application of the following KSAs:' are kept as their own",
        "elements rather than as headings. Annex E row boundaries are inferred",
        "from where a NICE ID cell begins (a two-letter category prefix, or",
        "'None'), because the PDF exposes no table structure; a row whose",
        "title or responsibility wraps past a page break is carried into that",
        "span rather than read from the table itself. Text baked into the figures is not recovered.",
        "One known artifact survives in the adjacent-role competencies: on the",
        "IT program auditor row the source prints 'procedures' and the next",
        "competency 'Threat and risk assessment' on one baseline, so they are",
        "written as a single run reading 'Cyber security audit policies,",
        "practices and procedures Threat and risk assessment'. Split it by",
        "hand if that row matters downstream."
      ),
      label_variants = paste(
        "The source prints two field labels inconsistently: 'Functional",
        "description' also appears as 'Functional Description', and the",
        "'NICE framework reference' field is headed 'NICE framework role' in",
        "C.1. Label matching therefore ignores case, and the C.1 variant is",
        "mapped to the same element_type. No other normalization of labels."
      ),
      known_source_inconsistency = paste(
        "The Annex B opening page lists core roles that have no detail block",
        "in the annex (encryption engineer/technologist and operational",
        "technology engineer/technologist). The detailed sections B.1 through",
        "B.9 are what this ingester captures; the listing is left as printed."
      ),
      successor_edition = paste(
        "The Canadian Centre for Cyber Security has said an updated edition of",
        "the framework is in progress. Re-run this ingester against the new",
        "edition when it is published rather than patching these tables."
      )
    )
  )

  manifest_path <- file.path(ccssf_config$staging_dir, ccssf_config$manifest_filename)
  write_yaml(manifest, manifest_path)
  message("Provenance manifest written: ", manifest_path)
  invisible(manifest_path)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== CCSSF 2022 Ingestion ===")

  staging_dir <- ccssf_config$staging_dir
  pdf_path    <- file.path(staging_dir, ccssf_config$pdf_filename)
  text_path   <- file.path(staging_dir, ccssf_config$text_filename)

  pdf_copy_path <- ensure_pdf_copy(staging_dir)

  message("Extracting text layer...")
  page_count <- write_intermediate_text(pdf_copy_path, text_path)
  message("  Pages: ", page_count, " -> ", text_path)

  pages_text <- pdf_text(pdf_copy_path)
  pages_data <- pdf_data(pdf_copy_path)

  message("Locating core role blocks...")
  role_index <- locate_core_roles(pages_data)
  message("  Core role blocks found: ", nrow(role_index))

  message("Parsing core role elements...")
  ccssf_nesting_env$unclear_pages <- integer(0)
  elements_long <- map_dfr(seq_len(nrow(role_index)), \(i) {
    parse_core_role(pages_data, role_index[i, ])
  })
  message("  Elements parsed: ", nrow(elements_long))

  role_catalog <- build_role_catalog(role_index, elements_long)

  message("Parsing Annex E adjacent roles...")
  annex_e_pages <- locate_annex_e_pages(pages_data)
  annex_e <- parse_annex_e(pages_data, annex_e_pages)
  message("  Adjacent roles: ", nrow(annex_e$roles),
          " | competency statements: ", nrow(annex_e$competencies))

  message("Building NICE crosswalk...")
  crosswalk <- build_nice_crosswalk(role_catalog, annex_e$roles)
  message("  Crosswalk rows: ", nrow(crosswalk),
          " | with a NICE work role id: ", sum(!is.na(crosswalk$nice_work_role_id)))

  declared_n <- declared_role_count(text_path)

  checks <- run_integrity_checks(role_catalog, elements_long, annex_e$roles,
                                 annex_e$competencies, declared_n)
  spot <- spot_check_fidelity(pages_text, role_catalog, elements_long)
  # The build driver gates on exit status, so a failed check has to stop the
  # script before any table is written. Short and long elements are flags
  # for a manual look, not failures.
  if (!isTRUE(checks$role_count_ok) || checks$empty_elements > 0) {
    stop("CCSSF integrity checks failed (role count ok: ", checks$role_count_ok,
         ", empty elements: ", checks$empty_elements, ").")
  }

  tables_dir <- file.path(staging_dir, ccssf_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)

  write_csv(ccssf_activity_areas |> select(annex, activity_area),
            file.path(tables_dir, "activity-areas.csv"))
  write_csv(role_catalog |> select(role_id, title, grouping, description,
                                   nice_reference),
            file.path(tables_dir, "roles.csv"))
  write_csv(elements_long, file.path(tables_dir, "role-elements-long.csv"))
  write_csv(annex_e$roles, file.path(tables_dir, "adjacent-roles.csv"))
  write_csv(annex_e$competencies,
            file.path(tables_dir, "adjacent-role-competencies-long.csv"))
  write_csv(crosswalk, file.path(tables_dir, "nice-crosswalk.csv"))
  write_csv(spot, file.path(tables_dir, "spot-check.csv"))

  message("\nWriting provenance manifest...")
  write_provenance_manifest(pdf_path, pdf_copy_path, text_path,
                            role_catalog, elements_long, annex_e$roles,
                            annex_e$competencies, crosswalk,
                            page_count, declared_n, spot)

  message("\n=== Summary ===")
  message("  Activity areas: ", nrow(ccssf_activity_areas))
  message("  Core roles: ", nrow(role_catalog))
  message("  Core role elements: ", nrow(elements_long))
  cat("  Element type breakdown:\n")
  print(elements_long |> count(element_type))
  message("  Adjacent roles: ", nrow(annex_e$roles))
  message("  Adjacent role competencies: ", nrow(annex_e$competencies))
  message("  NICE crosswalk rows: ", nrow(crosswalk))
  message("\nOutput: ", tables_dir)
  message("Done.")

  invisible(list(
    role_catalog  = role_catalog,
    elements_long = elements_long,
    adjacent      = annex_e$roles,
    adj_comps     = annex_e$competencies,
    crosswalk     = crosswalk,
    checks        = checks,
    spot          = spot
  ))
}

if (sys.nframe() == 0) {
  main()
}
