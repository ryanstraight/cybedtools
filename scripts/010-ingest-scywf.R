# 010-ingest-scywf.R
#
# Ingest the Saudi Cybersecurity Workforce Framework (SCyWF - 1.5 : 2026) from
# the National Cybersecurity Authority (NCA) PDF.
#
# Source: scywf_en.pdf (128 pages), staged under data/raw/scywf/ with a
# provenance.yml that records the SHA256 of every staged file. This script
# never fetches anything, and it stops unless every declared file is present
# with its declared hash.
#
# Licensing. NCA granted written permission on 2026-09-20. The terms are
# binding on this script: NCA is cited as issuing body and source with the
# official page link, and everything taken from the document is carried
# verbatim. Identifiers, titles and statement text are copied exactly as
# published. The only edits are the two layout normalisations documented
# below. Nothing is composed, normalised, paraphrased or translated. Anything
# cybedtools derives (the hierarchy edges between job roles, specialty areas
# and categories) is ours and is never presented as NCA content.
#
# Text normalisation, the complete list:
#   1. Whitespace. Every run of whitespace, including a line break inside a
#      table cell, becomes one space. Leading and trailing whitespace goes.
#   2. Line-break hyphenation. A line break that directly follows a hyphen is
#      removed without inserting a space, and the hyphen is kept. Every such
#      join is written to tables/hyphen-joins.csv for review.
# No other character is changed: apostrophes, quotation marks, capitals and
# punctuation stay as the PDF encodes them.
#
# Structure (observed in the PDF, not assumed):
#   Appendix A (pp. 19 to 42)  one card per job role. Fields: Job Role Name,
#       Job Role ID, Category, Specialty Area, Job Role Description,
#       Competency Areas, and Task, Knowledge and Skill CODES only.
#   Appendix B (pp. 43 to 122) Tables 9, 10 and 11: the Task, Knowledge and
#       Skill statements by code. Skills carry a published "Technical?" flag.
#   Appendix C (pp. 123 to 125) Table 12: competency areas by CA code, with
#       name and description.
# The document states its own size (p. 9): five categories, twelve specialty
# areas and forty job roles. Job role IDs are category ID, specialty area ID
# and a sequence number (CARD-CA-001).
#
# Extraction is table-aware. pdftools::pdf_data() gives every word with its
# page coordinates. Cells are rebuilt from the coordinates: a card's value
# column starts at the x of its Job Role ID, and multi-line table rows are
# assigned to their row anchor (the code in the first column) by a monotone
# partition that minimises the distance between each anchor and the vertical
# centre of its lines. A line-oriented regex over the linear text dump cannot
# do this: it finds only 26 of the 40 role IDs.
#
# Verification is independent of the extractor. scywf_en_raw.txt is the same
# PDF read by a second program (xpdf pdftotext -raw -enc UTF-8, content-stream
# order). Every carried string is looked up in that text after the same two
# normalisations. The result is written to tables/verbatim-check.csv and the
# ingest stops unless every string is found.
#
# Not ingested this pass: the companion Career Progression document
# (scywf_cp_en.pdf, SCyWF-CP 1:2026), which adds career levels, minimum
# qualifications and progression pathways. It is staged for provenance and
# deferred. The category and specialty area descriptions of Tables 1 and 2
# are not carried either: those tables set text in merged, vertically
# centred cells that this extractor does not yet rebuild reliably.
#
# Tables written to data/raw/scywf/tables/:
#   categories.csv             one row per category (5)
#   specialty-areas.csv        one row per specialty area (12)
#   roles.csv                  one row per job role card (40)
#   statements.csv             one row per Appendix B statement
#   role-statements.csv        one row per code printed on a role card
#   competency-areas.csv       one row per Appendix C competency area
#   role-competency-areas.csv  one row per CA code printed on a role card
#   unresolved-codes.csv       card codes with no Appendix B statement
#   hyphen-joins.csv           every line-break hyphenation join applied
#   verbatim-check.csv         the verbatim check, one row per carried string
#   nice-overlap.csv           statement codes shared with NICE, and whether
#                              the text is identical (a finding, not a merge)
#   nice-same-text.csv         SCyWF statements worded exactly as a NICE
#                              statement, under whatever code
#
# Run: Rscript scripts/010-ingest-scywf.R

suppressPackageStartupMessages({
  library(here)
  library(pdftools)
  library(dplyr)
  library(readr)
  library(yaml)
  library(purrr)
  library(tibble)
  library(stringr)
  library(digest)
})

scywf_config <- list(
  staging_dir       = here("data", "raw", "scywf"),
  pdf_filename      = "scywf_en.pdf",
  check_filename    = "scywf_en_raw.txt",
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml",
  nice_tables_dir   = here("data", "raw", "nice", "tables"),
  # Page furniture: the running header sits at y = 36 and the footer from
  # y = 772. Footnotes sit above the footer, at y 749 to 762, and are kept.
  header_max_y      = 45,
  footer_min_y      = 768
)

scywf_role_id_regex <- "^(CARD|LWD|GRCL|PD|ICSOT)-[A-Z]+-[0-9]{3}$"
scywf_code_regex    <- "^[TKS][0-9]{4}$"
scywf_ca_regex      <- "^CA[0-9]{3}$"

# ---------------------------------------------------------------------------
# Provenance anchor
# ---------------------------------------------------------------------------

#' Stop unless every file the manifest declares matches its recorded hash.
verify_scywf_hashes <- function(manifest, staging_dir) {
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
# Text normalisation (the two documented rules, nothing else)
# ---------------------------------------------------------------------------

#' Join the lines of one table cell into one string.
#'
#' Rule 1: lines are joined with one space and whitespace runs collapse.
#' Rule 2: a line that ends in a hyphen joins the next line with no space.
#' Returns the text and the hyphenation joins applied, for the join log.
scywf_join_lines <- function(lines) {
  lines <- str_squish(lines)
  lines <- lines[nzchar(lines)]
  if (length(lines) == 0) {
    return(list(text = "", joins = tibble(left = character(), right = character())))
  }
  out <- lines[1]
  joins <- tibble(left = character(), right = character())
  for (ln in lines[-1]) {
    if (str_detect(out, "[[:alpha:]]-$")) {
      joins <- bind_rows(joins, tibble(left = str_extract(out, "\\S+$"),
                                       right = str_extract(ln, "^\\S+")))
      out <- paste0(out, ln)
    } else {
      out <- paste(out, ln)
    }
  }
  list(text = out, joins = joins)
}

#' Apply the same two rules to free text, for the verbatim check.
scywf_normalise_text <- function(x) {
  x |>
    str_replace_all("(?<=[[:alpha:]]-)[ \\t]*\\r?\\n\\s*", "") |>
    str_squish()
}

# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

#' Cluster words into lines by baseline. Words whose y lies within `tol` of
#' the running line's first y join it. Within a line words are x ordered.
scywf_cluster_lines <- function(words, tol = 2) {
  if (nrow(words) == 0) {
    return(tibble(line = integer(), y = numeric(), x0 = numeric(), text = character()))
  }
  words <- words |> arrange(y, x)
  line_id <- integer(nrow(words))
  current <- 1L
  anchor <- words$y[1]
  for (i in seq_len(nrow(words))) {
    if (words$y[i] - anchor > tol) {
      current <- current + 1L
      anchor <- words$y[i]
    }
    line_id[i] <- current
  }
  words |>
    mutate(line = line_id) |>
    arrange(line, x) |>
    group_by(line) |>
    summarise(y = mean(y), x0 = min(x), text = paste(text, collapse = " "),
              .groups = "drop")
}

#' Assign line y positions to row anchors.
#'
#' Rows are contiguous and in anchor order, every anchor owns at least one
#' line, and the partition minimises the squared distance between each
#' anchor and the vertical centre of its lines. Returns the anchor index of
#' each line.
scywf_partition_rows <- function(line_y, anchor_y) {
  n_lines <- length(line_y)
  n_anchor <- length(anchor_y)
  if (n_anchor == 0 || n_lines < n_anchor) {
    stop("Cannot partition ", n_lines, " line(s) among ", n_anchor, " row anchor(s).")
  }
  ord <- order(line_y)
  ly <- line_y[ord]
  cost <- function(i, j, k) ((ly[i] + ly[j]) / 2 - anchor_y[k])^2
  best <- matrix(Inf, n_anchor, n_lines)
  from <- matrix(NA_integer_, n_anchor, n_lines)
  for (j in seq_len(n_lines)) best[1, j] <- cost(1, j, 1)
  if (n_anchor > 1) {
    for (k in 2:n_anchor) {
      for (j in k:n_lines) {
        for (i in k:j) {
          v <- best[k - 1, i - 1] + cost(i, j, k)
          if (v < best[k, j]) {
            best[k, j] <- v
            from[k, j] <- i
          }
        }
      }
    }
  }
  assign <- integer(n_lines)
  j <- n_lines
  for (k in n_anchor:1) {
    i <- if (k == 1) 1L else from[k, j]
    assign[i:j] <- k
    j <- i - 1L
  }
  out <- integer(n_lines)
  out[ord] <- assign
  out
}

#' Drop small-caps table captions ("TABLE 9: TASKS DESCRIPTIONS"), which the
#' PDF sets on two baselines as "T 9: T D" and "ABLE ASKS ESCRIPTIONS".
scywf_drop_captions <- function(words) {
  cap_y <- words$y[words$text == "ABLE"]
  if (length(cap_y) == 0) return(words)
  words |> filter(!vapply(y, \(v) any(abs(v - cap_y) <= 5), logical(1)))
}

# ---------------------------------------------------------------------------
# Appendix A: job role cards
# ---------------------------------------------------------------------------

scywf_label_sequence <- list(
  name        = c("Job", "Role", "Name"),
  id          = c("Job", "Role", "ID"),
  category    = "Category",
  specialty   = c("Specialty", "Area"),
  description = c("Job", "Role", "Description"),
  competency  = c("Competency", "Areas"),
  tasks       = "Tasks",
  knowledge   = "Knowledge",
  skills      = "Skills"
)

#' Parse one job role card from the words of its region.
#'
#' @param words Tibble of words (x, y, text) from the card header down to the
#'   next card header or the page foot.
#' @return List: role (one-row tibble), codes (tibble), asterisk (logical),
#'   footnote_words (words below the card's last code line).
scywf_parse_card <- function(words) {
  id_word <- words |> filter(str_detect(text, scywf_role_id_regex))
  if (nrow(id_word) != 1) {
    stop("Expected one job role ID in a card region, found ", nrow(id_word))
  }
  value_x0 <- id_word$x - 6

  code_like <- str_detect(str_remove(words$text, ",$"), scywf_code_regex)
  last_code_y <- max(words$y[code_like & words$x >= value_x0])
  footnote_words <- words |> filter(y > last_code_y + 8)
  words <- words |> filter(y <= last_code_y + 8)

  label_words <- words |> filter(x < value_x0)
  value_words <- words |> filter(x >= value_x0)

  # Walk the label column in reading order against the fixed label sequence.
  label_words <- label_words |> arrange(y, x)
  asterisk <- any(str_detect(label_words$text, "\\*"))
  label_words <- label_words |>
    mutate(text = str_remove_all(text, "\\*")) |>
    filter(nzchar(text))
  expected <- unlist(scywf_label_sequence, use.names = FALSE)
  field_of <- rep(names(scywf_label_sequence), lengths(scywf_label_sequence))
  if (!identical(label_words$text, expected)) {
    stop("Card label column does not read as the expected sequence: ",
         paste(label_words$text, collapse = " "))
  }
  label_centres <- tibble(field = field_of, y = label_words$y) |>
    group_by(field) |>
    summarise(y = (min(y) + max(y)) / 2, .groups = "drop")
  centre <- setNames(label_centres$y, label_centres$field)

  lines <- scywf_cluster_lines(value_words)
  tokens <- str_split(lines$text, " ")
  is_code_line <- vapply(tokens, \(t) all(str_detect(str_remove(t, ",$"), scywf_code_regex)),
                         logical(1))
  is_id_line <- str_detect(lines$text, scywf_role_id_regex) &
    vapply(tokens, length, integer(1)) == 1L

  # Text fields run in a fixed order down the card, one cell each, and each
  # label is centred on its cell. The lines are split among the five fields
  # by the same monotone partition used for table rows, anchored on the label
  # centres. The ID row holds only the ID, so it is not a candidate.
  text_fields <- c("name", "category", "specialty", "description", "competency")
  text_lines <- lines[!is_code_line & !is_id_line, ] |> arrange(y)
  id_line_y <- lines$y[is_id_line]
  text_lines$field <- text_fields[scywf_partition_rows(text_lines$y, centre[text_fields])]
  if (any(text_lines$field == "name" & text_lines$y > id_line_y) ||
      any(text_lines$field != "name" & text_lines$y < id_line_y)) {
    stop("Card ", id_word$text, ": a text line crosses the Job Role ID row.")
  }

  joins <- tibble(field = character(), left = character(), right = character())
  field_text <- function(f) {
    j <- scywf_join_lines(text_lines$text[text_lines$field == f])
    if (nrow(j$joins) > 0) joins <<- bind_rows(joins, mutate(j$joins, field = f))
    j$text
  }

  # Code lines: letters must run T, then K, then S, top to bottom.
  code_lines <- lines[is_code_line, ]
  codes <- code_lines |>
    mutate(code = str_split(text, " ")) |>
    tidyr::unnest(code) |>
    mutate(separator = if_else(str_detect(code, ",$"), ",", ""),
           code = str_remove(code, ",$"),
           statement_type = c(T = "task", K = "knowledge", S = "skill")[substr(code, 1, 1)])
  letter_rank <- match(substr(codes$code, 1, 1), c("T", "K", "S"))
  if (is.unsorted(letter_rank)) {
    stop("Card ", id_word$text, ": Task, Knowledge and Skill codes are interleaved.")
  }
  codes <- codes |>
    group_by(statement_type) |>
    mutate(ordinal = row_number()) |>
    ungroup() |>
    select(statement_id = code, statement_type, ordinal)

  role <- tibble(
    role_id              = id_word$text,
    role_name            = field_text("name"),
    category_text        = field_text("category"),
    specialty_area_text  = field_text("specialty"),
    description          = field_text("description"),
    competency_areas_text = field_text("competency")
  )
  empty <- names(role)[vapply(role, \(v) !nzchar(v), logical(1))]
  if (length(empty) > 0) {
    stop("Card ", id_word$text, " has empty field(s): ", paste(empty, collapse = ", "))
  }

  list(role = role, codes = codes, asterisk = asterisk,
       footnote_words = footnote_words, joins = mutate(joins, id = id_word$text))
}

#' Parse every job role card in the document.
#'
#' @param pages List of pdf_data() tibbles, one per page, header and footer
#'   already removed.
scywf_parse_cards <- function(pages) {
  roles <- list()
  codes <- list()
  joins <- list()
  for (p in seq_along(pages)) {
    w <- pages[[p]]
    lines <- scywf_cluster_lines(w)
    header_y <- lines$y[lines$text == "Job Role Details"]
    if (length(header_y) == 0) next
    # A category group heading always precedes its first card, so a card
    # region runs from its own header to the next one or to the page foot.
    bounds <- c(header_y, Inf)
    footnotes <- list()
    page_roles <- list()
    for (k in seq_along(header_y)) {
      region <- w |> filter(y >= bounds[k] - 1, y < bounds[k + 1] - 1)
      region <- region |> filter(!(abs(y - bounds[k]) < 2 &
                                    text %in% c("Job", "Role", "Details")))
      card <- scywf_parse_card(region)
      card$role$page <- p
      page_roles[[k]] <- card
      if (nrow(card$footnote_words) > 0) {
        fl <- scywf_cluster_lines(card$footnote_words)
        # A footnote opens with its "*" marker, set on its own baseline a
        # point below the text. Each footnote is one printed line.
        fl <- fl |> filter(text != "*") |> mutate(text = str_remove(text, "^\\*\\s*"))
        footnotes <- c(footnotes, as.list(fl$text))
      }
    }
    starred <- which(vapply(page_roles, \(c) c$asterisk, logical(1)))
    if (length(starred) != length(footnotes)) {
      stop("Page ", p, ": ", length(starred), " starred Competency Areas field(s) but ",
           length(footnotes), " footnote(s).")
    }
    for (k in seq_along(page_roles)) {
      card <- page_roles[[k]]
      note <- if (k %in% starred) footnotes[[match(k, starred)]] else NA_character_
      roles[[length(roles) + 1]] <- mutate(card$role, competency_areas_note = note)
      codes[[length(codes) + 1]] <- mutate(card$codes, role_id = card$role$role_id)
      joins[[length(joins) + 1]] <- card$joins
    }
  }
  list(roles = bind_rows(roles),
       codes = bind_rows(codes) |> select(role_id, statement_id, statement_type, ordinal),
       joins = bind_rows(joins))
}

# ---------------------------------------------------------------------------
# Appendix B statements and Appendix C competency areas
# ---------------------------------------------------------------------------

#' Parse the rows of Table 9, 10 or 11 found on one page.
#'
#' @param words Words of the table body on one page: below the column header,
#'   above the next header or the page foot.
#' @param statement_type "task", "knowledge" or "skill".
scywf_parse_statement_page <- function(words, statement_type) {
  words <- scywf_drop_captions(words)
  if (nrow(words) == 0) {
    return(list(rows = tibble(statement_id = character(), statement_type = character(),
                              text = character(), technical = character()),
                joins = tibble()))
  }

  # The ID column ends where its codes end. Everything right of it is text.
  ids <- words |> filter(x < 110, str_detect(text, scywf_code_regex))
  id_right <- max(ids$x + ids$width) + 3
  stray <- words |> filter(x < id_right, !str_detect(text, scywf_code_regex))
  if (nrow(stray) > 0) {
    stop("Unexpected word in the ID column: ", paste(stray$text, collapse = " "))
  }
  tech_x <- Inf
  flags <- NULL
  if (statement_type == "skill") {
    tech_x <- 460
    flags <- words |> filter(x >= tech_x)
    if (!all(flags$text %in% c("Yes", "No")) || nrow(flags) != nrow(ids)) {
      stop("Skill page: Technical? column does not hold one Yes or No per skill.")
    }
  }
  text_words <- words |> filter(x >= id_right, x < tech_x)
  lines <- scywf_cluster_lines(text_words)
  ids <- ids |> arrange(y)
  owner <- scywf_partition_rows(lines$y, ids$y)

  joins <- list()
  rows <- map(seq_len(nrow(ids)), function(k) {
    j <- scywf_join_lines(lines$text[owner == k][order(lines$y[owner == k])])
    if (nrow(j$joins) > 0) joins[[length(joins) + 1]] <<- mutate(j$joins, id = ids$text[k])
    tibble(statement_id = ids$text[k], statement_type = statement_type, text = j$text)
  }) |> bind_rows()
  if (!is.null(flags)) {
    rows$technical <- (flags |> arrange(y))$text
  } else {
    rows$technical <- NA_character_
  }
  list(rows = rows, joins = bind_rows(joins))
}

#' Parse one page of Table 12 (competency areas).
scywf_parse_competency_page <- function(words) {
  # Only the first page of Table 12 prints the column header, under the
  # appendix's introductory paragraph. Continuation pages start with rows.
  header <- words |> filter(text == "Name", x > 120, x < 200)
  if (nrow(header) > 0) words <- words |> filter(y > header$y[1] + 3)
  words <- scywf_drop_captions(words)
  ids <- words |> filter(x < 100) |> arrange(y)
  if (!all(str_detect(ids$text, scywf_ca_regex))) {
    stop("Unexpected word in the CA ID column: ", paste(ids$text, collapse = " "))
  }
  name_lines <- scywf_cluster_lines(words |> filter(x >= 100, x < 225))
  desc_lines <- scywf_cluster_lines(words |> filter(x >= 225))
  name_owner <- scywf_partition_rows(name_lines$y, ids$y)
  desc_owner <- scywf_partition_rows(desc_lines$y, ids$y)
  joins <- list()
  cell <- function(lines, owner, k, field) {
    j <- scywf_join_lines(lines$text[owner == k][order(lines$y[owner == k])])
    if (nrow(j$joins) > 0) {
      joins[[length(joins) + 1]] <<- mutate(j$joins, id = ids$text[k], field = field)
    }
    j$text
  }
  rows <- map(seq_len(nrow(ids)), \(k) tibble(
    ca_id       = ids$text[k],
    ca_name     = cell(name_lines, name_owner, k, "ca_name"),
    description = cell(desc_lines, desc_owner, k, "ca_description")
  )) |> bind_rows()
  list(rows = rows, joins = bind_rows(joins))
}

# ---------------------------------------------------------------------------
# Derived tables
# ---------------------------------------------------------------------------

#' Categories and specialty areas, from the IDs inside the job role IDs and
#' the verbatim Category and Specialty Area fields of the cards. Every role
#' in a group must print the same field text, or the ingest stops.
scywf_groups <- function(roles) {
  roles <- roles |>
    mutate(category_id       = str_split_i(role_id, "-", 1),
           specialty_area_id = str_split_i(role_id, "-", 2))
  categories <- roles |>
    group_by(category_id) |>
    summarise(category_name = unique(category_text),
              first_role = min(role_id), .groups = "drop")
  specialty <- roles |>
    group_by(specialty_area_id, category_id) |>
    summarise(specialty_area_name = unique(specialty_area_text),
              first_role = min(role_id), .groups = "drop")
  if (anyDuplicated(categories$category_id) || anyDuplicated(specialty$specialty_area_id)) {
    stop("A category or specialty area prints more than one name across its roles.")
  }
  order_ids <- unique(roles$category_id)
  list(
    roles = roles,
    categories = categories |>
      arrange(match(category_id, order_ids)) |>
      select(category_id, category_name),
    specialty_areas = specialty |>
      arrange(match(category_id, order_ids), first_role) |>
      select(specialty_area_id, specialty_area_name, category_id)
  )
}

#' CA codes printed in a card's Competency Areas field, in printed order.
scywf_role_competency_areas <- function(roles) {
  roles |>
    select(role_id, competency_areas_text) |>
    mutate(ca_id = str_extract_all(competency_areas_text, "(?<=\\()CA[0-9]{3}(?=\\))")) |>
    tidyr::unnest(ca_id) |>
    group_by(role_id) |>
    mutate(ordinal = row_number()) |>
    ungroup() |>
    select(role_id, ca_id, ordinal)
}

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

#' Look every carried string up in the independent extraction.
#'
#' Plain rows check that the string occurs. Paired rows check a statement
#' together with its code (and a skill's Technical? flag), and a card's code
#' list exactly as printed, which also proves the row partition.
scywf_verbatim_check <- function(roles, statements, codes, competency, categories,
                                 specialty_areas, reference_text) {
  ref <- scywf_normalise_text(reference_text)
  card_lists <- codes |>
    group_by(role_id, statement_type) |>
    summarise(text = paste(statement_id, collapse = ", "), .groups = "drop") |>
    transmute(field = paste0("card_", statement_type, "_codes"), id = role_id, text)
  stmt_pairs <- statements |>
    transmute(field = "statement_with_code", id = statement_id,
              text = if_else(is.na(technical), paste(statement_id, text),
                             paste(statement_id, text, technical)))
  checks <- bind_rows(
    tibble(field = "role_id",          id = roles$role_id, text = roles$role_id),
    tibble(field = "role_name",        id = roles$role_id, text = roles$role_name),
    tibble(field = "role_description", id = roles$role_id, text = roles$description),
    tibble(field = "role_category",    id = roles$role_id, text = roles$category_text),
    tibble(field = "role_specialty_area", id = roles$role_id, text = roles$specialty_area_text),
    tibble(field = "role_competency_areas", id = roles$role_id,
           text = roles$competency_areas_text),
    tibble(field = "role_competency_areas_note",
           id = roles$role_id[!is.na(roles$competency_areas_note)],
           text = roles$competency_areas_note[!is.na(roles$competency_areas_note)]),
    tibble(field = "statement_text",   id = statements$statement_id, text = statements$text),
    stmt_pairs,
    card_lists,
    tibble(field = "ca_id",            id = competency$ca_id, text = competency$ca_id),
    tibble(field = "ca_name",          id = competency$ca_id, text = competency$ca_name),
    tibble(field = "ca_description",   id = competency$ca_id, text = competency$description),
    tibble(field = "category_name",    id = categories$category_id,
           text = categories$category_name),
    tibble(field = "specialty_area_name", id = specialty_areas$specialty_area_id,
           text = specialty_areas$specialty_area_name)
  )
  checks |> mutate(found = vapply(text, \(t) grepl(t, ref, fixed = TRUE), logical(1)))
}

#' Statement codes SCyWF shares with the NICE Framework, and whether the text
#' printed under the code is identical. A finding for the record: the graph
#' keeps the two frameworks' statements apart under their own prefixes.
scywf_nice_overlap <- function(statements, nice_tables_dir) {
  paths <- file.path(nice_tables_dir, c("tasks.csv", "knowledge.csv", "skills.csv"))
  if (!all(file.exists(paths))) return(NULL)
  nice <- map(paths, \(p) read_csv(p, show_col_types = FALSE,
                                   col_types = cols(.default = col_character()))) |>
    bind_rows() |>
    select(statement_id = element_id, nice_text = text)
  shared_code <- statements |>
    select(statement_id, statement_type, scywf_text = text) |>
    inner_join(nice, by = "statement_id") |>
    mutate(identical_text = scywf_text == nice_text,
           identical_after_whitespace = str_squish(scywf_text) == str_squish(nice_text))
  # The same wording under any NICE code, whatever the SCyWF code.
  same_text <- statements |>
    select(statement_id, scywf_text = text) |>
    inner_join(nice |> rename(nice_statement_id = statement_id),
               by = c("scywf_text" = "nice_text"), relationship = "many-to-many")
  attr(shared_code, "same_text_any_code") <- same_text
  shared_code
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

scywf_read_pages <- function(pdf_path) {
  pdf_data(pdf_path) |>
    map(\(w) w |>
          filter(y > scywf_config$header_max_y, y < scywf_config$footer_min_y) |>
          select(x, y, width, text))
}

#' Locate the page ranges of Appendices A, B and C from their own headings.
scywf_locate <- function(pages) {
  has_line <- function(p, pattern) any(str_detect(scywf_cluster_lines(p)$text, pattern))
  a <- which(vapply(pages, has_line, logical(1), "Appendix A: Job Role Details$"))
  b <- which(vapply(pages, has_line, logical(1), "Appendix B: List of Tasks"))
  c <- which(vapply(pages, has_line, logical(1), "Appendix C: List of competency areas"))
  d <- which(vapply(pages, has_line, logical(1), "Appendix D: Updates"))
  # The table of contents names every appendix too. The body heading is the
  # last occurrence.
  list(cards = max(a):(max(b) - 1), statements = (max(b) + 1):(max(c) - 1),
       competency = max(c):(max(d) - 1))
}

main <- function() {
  message("=== Saudi Cybersecurity Workforce Framework (SCyWF) Ingestion ===")

  manifest_path <- file.path(scywf_config$staging_dir, scywf_config$manifest_filename)
  if (!file.exists(manifest_path)) stop("provenance.yml not found at ", manifest_path)
  manifest <- read_yaml(manifest_path)

  message("Verifying staged files against provenance.yml hashes...")
  verify_scywf_hashes(manifest, scywf_config$staging_dir)

  pdf_path <- file.path(scywf_config$staging_dir, scywf_config$pdf_filename)
  pages <- scywf_read_pages(pdf_path)
  message("  Pages: ", length(pages))
  where <- scywf_locate(pages)

  cards <- scywf_parse_cards(pages[where$cards])
  cards$roles$page <- where$cards[cards$roles$page]

  # Every Appendix B page repeats its column header ("Task ID", "ID" with
  # "Knowledge" above it, "Skill ID"). Each table starts on a fresh page, so a
  # page holds one table, and its type is read from its codes' letter.
  stmt_parts <- list()
  for (p in where$statements) {
    w <- pages[[p]]
    header <- w |> filter(text == "ID", x < 130)
    if (nrow(header) != 1) stop("Page ", p, ": expected one ID column header.")
    body <- w |> filter(y > header$y + 3)
    letters_on_page <- unique(substr(body$text[str_detect(body$text, scywf_code_regex) &
                                                 body$x < 110], 1, 1))
    if (length(letters_on_page) == 0) next
    if (length(letters_on_page) != 1) stop("Page ", p, ": codes of more than one table.")
    kind <- c(T = "task", K = "knowledge", S = "skill")[[letters_on_page]]
    parsed <- scywf_parse_statement_page(body, kind)
    parsed$rows$page <- rep(p, nrow(parsed$rows))
    stmt_parts[[length(stmt_parts) + 1]] <- parsed
  }
  statements <- map(stmt_parts, "rows") |> bind_rows()
  stmt_joins <- map(stmt_parts, "joins") |> bind_rows() |> mutate(field = "statement_text")

  ca_parts <- map(where$competency, \(p) {
    parsed <- scywf_parse_competency_page(pages[[p]])
    parsed$rows$page <- p
    parsed
  })
  competency <- map(ca_parts, "rows") |> bind_rows()
  ca_joins <- map(ca_parts, "joins") |> bind_rows()

  groups <- scywf_groups(cards$roles)
  roles <- groups$roles |>
    select(role_id, role_name, category_id, specialty_area_id, category_text,
           specialty_area_text, description, competency_areas_text,
           competency_areas_note, page)
  role_statements <- cards$codes
  role_ca <- scywf_role_competency_areas(roles)

  unresolved <- role_statements |> filter(!statement_id %in% statements$statement_id)
  unresolved_ca <- role_ca |> filter(!ca_id %in% competency$ca_id)

  joins <- bind_rows(
    tibble(id = character(), field = character(), left = character(), right = character()),
    cards$joins, stmt_joins, ca_joins
  ) |>
    select(id, field, left, right)

  reference <- read_file(file.path(scywf_config$staging_dir, scywf_config$check_filename))
  check <- scywf_verbatim_check(roles, statements, role_statements, competency,
                                groups$categories, groups$specialty_areas, reference)
  overlap <- scywf_nice_overlap(statements, scywf_config$nice_tables_dir)

  # Checks that stop the ingest.
  problems <- c(
    if (nrow(roles) != 40) paste("job roles:", nrow(roles), "vs the document's stated 40"),
    if (nrow(groups$categories) != 5) paste("categories:", nrow(groups$categories), "vs 5"),
    if (nrow(groups$specialty_areas) != 12)
      paste("specialty areas:", nrow(groups$specialty_areas), "vs 12"),
    if (anyDuplicated(roles$role_id)) "duplicate job role IDs",
    if (anyDuplicated(statements$statement_id)) "duplicate statement codes in Appendix B",
    if (anyDuplicated(competency$ca_id)) "duplicate competency area codes",
    if (anyDuplicated(role_statements[c("role_id", "statement_id")]))
      "a card prints the same code twice",
    if (any(substr(statements$statement_id, 1, 1) !=
            c(task = "T", knowledge = "K", skill = "S")[statements$statement_type]))
      "a statement code sits in the wrong table",
    if (nrow(unresolved_ca) > 0) "a card cites a CA code missing from Appendix C",
    if (!all(check$found))
      paste(sum(!check$found), "carried string(s) not found in the reference text")
  )

  tables_dir <- file.path(scywf_config$staging_dir, scywf_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)
  write_csv(groups$categories,      file.path(tables_dir, "categories.csv"))
  write_csv(groups$specialty_areas, file.path(tables_dir, "specialty-areas.csv"))
  write_csv(roles,                  file.path(tables_dir, "roles.csv"), na = "")
  write_csv(statements,             file.path(tables_dir, "statements.csv"), na = "")
  write_csv(role_statements,        file.path(tables_dir, "role-statements.csv"))
  write_csv(competency,             file.path(tables_dir, "competency-areas.csv"))
  write_csv(role_ca,                file.path(tables_dir, "role-competency-areas.csv"))
  write_csv(unresolved,             file.path(tables_dir, "unresolved-codes.csv"))
  write_csv(joins,                  file.path(tables_dir, "hyphen-joins.csv"))
  write_csv(check,                  file.path(tables_dir, "verbatim-check.csv"))
  if (!is.null(overlap)) {
    write_csv(overlap, file.path(tables_dir, "nice-overlap.csv"))
    write_csv(attr(overlap, "same_text_any_code"),
              file.path(tables_dir, "nice-same-text.csv"))
  }

  if (length(problems) > 0) {
    stop("SCyWF extraction failed its checks:\n  ", paste(problems, collapse = "\n  "))
  }

  # The staged manifest is the provenance anchor and is kept as written. Only
  # the counts this script measures are recorded under `extraction`.
  manifest$extraction$categories              <- nrow(groups$categories)
  manifest$extraction$specialty_areas         <- nrow(groups$specialty_areas)
  manifest$extraction$job_roles               <- nrow(roles)
  manifest$extraction$tasks                   <- sum(statements$statement_type == "task")
  manifest$extraction$knowledge               <- sum(statements$statement_type == "knowledge")
  manifest$extraction$skills                  <- sum(statements$statement_type == "skill")
  manifest$extraction$statements              <- nrow(statements)
  manifest$extraction$role_statement_links    <- nrow(role_statements)
  manifest$extraction$unresolved_card_codes   <- nrow(unresolved)
  manifest$extraction$competency_areas        <- nrow(competency)
  manifest$extraction$role_competency_area_links <- nrow(role_ca)
  manifest$extraction$hyphenation_joins       <- nrow(joins)
  manifest$extraction$verbatim_checked        <- nrow(check)
  manifest$extraction$verbatim_found          <- sum(check$found)
  if (!is.null(overlap)) {
    manifest$extraction$nice_shared_codes       <- nrow(overlap)
    manifest$extraction$nice_identical_text     <- sum(overlap$identical_text)
    manifest$extraction$nice_same_text_any_code <-
      n_distinct(attr(overlap, "same_text_any_code")$statement_id)
  }
  write_yaml(manifest, manifest_path)

  message("\n=== Summary ===")
  message("  Categories: ", nrow(groups$categories),
          "  Specialty areas: ", nrow(groups$specialty_areas),
          "  Job roles: ", nrow(roles))
  message("  Statements: ", nrow(statements), " (",
          sum(statements$statement_type == "task"), " tasks, ",
          sum(statements$statement_type == "knowledge"), " knowledge, ",
          sum(statements$statement_type == "skill"), " skills)")
  message("  Role-statement links: ", nrow(role_statements),
          "  unresolved card codes: ", nrow(unresolved))
  message("  Competency areas: ", nrow(competency),
          "  role-CA links: ", nrow(role_ca))
  message("  Verbatim check: ", sum(check$found), " of ", nrow(check), " found")
  if (!is.null(overlap)) {
    message("  Codes shared with NICE: ", nrow(overlap),
            ", identical text: ", sum(overlap$identical_text),
            ", SCyWF statements worded as some NICE statement: ",
            n_distinct(attr(overlap, "same_text_any_code")$statement_id))
  }
  message("\nDone.")

  invisible(list(roles = roles, statements = statements, role_statements = role_statements,
                 competency = competency, check = check, overlap = overlap))
}

if (sys.nframe() == 0) {
  main()
}
