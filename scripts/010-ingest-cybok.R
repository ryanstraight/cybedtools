# 010-ingest-cybok.R
#
# Ingest the Cyber Security Body of Knowledge (CyBOK) v1.1.0, July 2021,
# published by the National Cyber Security Centre (NCSC) under the Open
# Government Licence v3.0.
#
# Source: PDFs only. CyBOK publishes no CSV, JSON or XML. Every file is staged
# under data/raw/cybok/ with a provenance.yml that records its URL, version
# and SHA256. This script never fetches anything, and it stops unless every
# declared file is present with its declared hash.
#
#   Introduction_v1.1.0.pdf   the Introduction to CyBOK Knowledge Area. Its
#       Figure 2 ("Short descriptions of CyBOK Knowledge Areas") is a text
#       table that prints the 5 categories as header rows and the 21
#       Knowledge Area names beneath them. Source of the KA names and of each
#       KA's category.
#   trees/*.pdf               one Knowledge Tree per KA, each versioned with
#       its KA. CyBOK defines its own levels on these trees: "The nodes
#       directly under the root node are referred to as Topics" and
#       "Indicative Material is defined as the nodes in the Knowledge Tree one
#       layer further down from the Topic" (A-to-Z document, Introduction).
#       Source of the Topic titles, the Indicative Material terms and which
#       Topic each term hangs from.
#   A_to_Z_CyBOK_KA_1_1_July_2021.pdf  the alphabetical Indicative Material
#       index: a three-column table (term, Topic, KA acronym). Source of the
#       KA acronyms, which key the KA IRIs. Its rows are otherwise used only
#       to cross-check the trees. Nothing else is taken from it.
#   text/*.raw.txt            the same PDFs read by a second program (xpdf
#       pdftotext 4.06 -raw -enc UTF-8), for the verbatim check only.
#
# Text normalisation, the complete list:
#   1. Whitespace. Every run of whitespace, including a line break, becomes
#      one space. Leading and trailing whitespace goes.
#   2. Line-break hyphenation. A line break directly after a hyphen that
#      follows a letter is removed without inserting a space, and the hyphen
#      is kept.
# No other character is changed. Case in particular is kept as printed: the
# Knowledge Trees print most Topics in lower case and the A-to-Z prints
# everything in capitals, and both are carried as printed.
#
# Reading a Knowledge Tree. A tree is a drawing: each node is a boxed label
# and each parent-child link is a stroked line, which the text layer does not
# carry. Node labels come from the text layer (pdftools word coordinates).
# The links come from the drawing itself: the page is rendered, every node
# box is blanked out, and the remaining ink is split into connected
# components. One component is the fan of lines leaving one node, so a
# component touching two node boxes links them. The component that reaches
# the far left of the drawing is the root's fan, and the nodes it touches are
# the Topics. A component that touches a Topic and a node to its right links
# that node to the Topic as its Indicative Material. This is how CyBOK
# defines both levels, and it does not rely on node position: at least one
# tree (Distributed Systems Security) draws a Topic in the column where the
# other Topics' children sit.
#
# Cross-check against the A-to-Z. Every A-to-Z row (term, Topic, KA) is
# resolved against the trees and the result written row by row. Matching
# folds case, because the A-to-Z sets every cell in capitals, and accepts a
# line-break hyphen with or without the hyphen, because the A-to-Z's
# justified columns break words mid-syllable. Both are matching rules only
# and never change a carried string. Rows that do not resolve are reported,
# not corrected.
#
# The Introduction Knowledge Tree (acronym CI in the A-to-Z) is staged and
# parsed for the cross-check but is not a Knowledge Area and is not ingested.
#
# Tables written to data/raw/cybok/tables/:
#   categories.csv            the 5 categories of Figure 2, in printed order
#   knowledge-areas.csv       the 21 KAs: acronym, name, category, version,
#                             tree title, tree file
#   topics.csv                one row per Topic, per KA in tree order
#   indicative-material.csv   one row per Indicative Material node, under its
#                             Topic in tree order
#   a-to-z.csv                the A-to-Z table, flat, one row per printed row
#   a-to-z-resolution.csv     each A-to-Z row resolved against the trees
#   verbatim-check.csv        every carried string looked up in the
#                             independent extraction
#   crosswalk-ka-resolution.csv  the staged SFIA and ECSF crosswalks' KA
#                             names resolved to KA acronyms
#
# Run: Rscript scripts/010-ingest-cybok.R

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

cybok_config <- list(
  staging_dir       = here("data", "raw", "cybok"),
  tables_subdir     = "tables",
  manifest_filename = "provenance.yml",
  # Page furniture on every CyBOK page: the running header above y = 45 and
  # the footer below y = 790.
  header_max_y      = 45,
  footer_min_y      = 790,
  # Knowledge Tree text: words on one baseline further apart than this
  # belong to different nodes.
  node_gap          = 6,
  # Knowledge Tree drawing: render resolution, the grey level below which a
  # pixel counts as ink (the lines are thin and anti-aliased), and how far
  # outside a node box a line still counts as touching it, in pixels.
  render_dpi        = 300,
  ink_below         = 215,
  touch_px          = 3
)

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---------------------------------------------------------------------------
# Provenance anchor
# ---------------------------------------------------------------------------

#' Stop unless every file the manifest declares matches its recorded hash.
verify_cybok_hashes <- function(manifest, staging_dir) {
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

#' The declared files of one role, as a tibble.
cybok_files_of_role <- function(manifest, file_role) {
  manifest$source$files |>
    keep(\(f) identical(f$role, file_role)) |>
    map(\(f) tibble(filename   = f$filename,
                    ka_acronym = f$ka_acronym %||% NA_character_,
                    ka_name    = f$ka_name %||% NA_character_,
                    version    = f$version %||% NA_character_,
                    text_of    = f$text_of %||% NA_character_)) |>
    bind_rows()
}

# ---------------------------------------------------------------------------
# Text normalisation (the two documented rules, nothing else)
# ---------------------------------------------------------------------------

#' Join printed lines into one string under the two rules. With
#' `soft_hyphen = TRUE` a line-break hyphen is dropped instead of kept, which
#' is used only to match the A-to-Z and never for a carried string.
cybok_join_lines <- function(lines, soft_hyphen = FALSE) {
  lines <- str_squish(lines)
  lines <- lines[nzchar(lines)]
  if (length(lines) == 0) return("")
  out <- lines[1]
  for (ln in lines[-1]) {
    if (str_detect(out, "[[:alpha:]]-$")) {
      out <- paste0(if (soft_hyphen) str_remove(out, "-$") else out, ln)
    } else {
      out <- paste(out, ln)
    }
  }
  out
}

#' Apply the same two rules to free text, for the verbatim check.
cybok_normalise_text <- function(x) {
  x |>
    str_replace_all("(?<=[[:alpha:]]-)[ \\t]*\\r?\\n\\s*", "") |>
    str_squish()
}

#' Case fold for matching the capitalised A-to-Z against the trees. Matching
#' only: never applied to a carried string.
cybok_fold <- function(x) str_to_lower(str_squish(x))

# ---------------------------------------------------------------------------
# Text-layer geometry
# ---------------------------------------------------------------------------

#' Assign words to printed lines by baseline.
cybok_line_ids <- function(y, tol = 2) {
  if (length(y) == 0) return(integer(0))
  ord <- order(y)
  id <- integer(length(y))
  current <- 1L
  anchor <- y[ord[1]]
  for (i in ord) {
    if (y[i] - anchor > tol) {
      current <- current + 1L
      anchor <- y[i]
    }
    id[i] <- current
  }
  id
}

#' Words grouped into printed lines, x ordered, as text.
cybok_lines <- function(words) {
  if (nrow(words) == 0) return(tibble(y = numeric(), x0 = numeric(), text = character()))
  words |>
    mutate(line = cybok_line_ids(y)) |>
    arrange(line, x) |>
    group_by(line) |>
    summarise(y = min(y), x0 = min(x), text = paste(text, collapse = " "),
              .groups = "drop") |>
    select(-line)
}

# ---------------------------------------------------------------------------
# Introduction, Figure 2: categories and Knowledge Areas
# ---------------------------------------------------------------------------

#' Parse Figure 2 of the Introduction.
#'
#' Category headers are the small-type lines of the description column. KA
#' names are the left column. A name printed on several lines is one cell: its
#' lines sit one line pitch apart, while two cells are separated by the row
#' rule and padding.
#'
#' @param words pdf_data() words of the Figure 2 page.
#' @return List: categories (category_order, category_name) and kas
#'   (ka_order, ka_name, category_name).
cybok_parse_figure2 <- function(words, name_x_max = 160, pitch = 11) {
  caption <- words |> filter(text == "Figure", lead(text) == "2:")
  if (nrow(caption) != 1) stop("Figure 2 caption not found on the page.")
  words <- words |>
    filter(y > cybok_config$header_max_y, y < caption$y - 2)
  headers <- cybok_lines(words |> filter(height < 9, x >= name_x_max)) |> arrange(y)
  names_l <- cybok_lines(words |> filter(height >= 9, x < name_x_max)) |> arrange(y)
  kas <- names_l |>
    mutate(cell = cumsum(c(TRUE, diff(y) > pitch))) |>
    group_by(cell) |>
    summarise(y = min(y), ka_name = cybok_join_lines(text), .groups = "drop")
  kas$category_name <- headers$text[findInterval(kas$y, headers$y)]
  list(
    categories = tibble(category_order = seq_len(nrow(headers)),
                        category_name = headers$text),
    kas = tibble(ka_order = seq_len(nrow(kas)), ka_name = kas$ka_name,
                 category_name = kas$category_name)
  )
}

# ---------------------------------------------------------------------------
# A-to-Z: acronym table and the Indicative Material index
# ---------------------------------------------------------------------------

#' The acronym table ("Acronym Knowledge Area").
cybok_parse_acronyms <- function(words) {
  head_row <- words |> filter(text == "Acronym")
  note <- words |> filter(str_detect(text, "^Note"))
  if (nrow(head_row) != 1 || nrow(note) < 1) stop("A-to-Z acronym table not found.")
  body <- words |> filter(y > head_row$y + 3, y < min(note$y) - 3)
  name_x <- min(body$x[body$x > head_row$x + head_row$width])
  body |>
    mutate(line = cybok_line_ids(y)) |>
    arrange(line, x) |>
    group_by(line) |>
    summarise(acronym = paste(text[x < name_x], collapse = " "),
              az_ka_name = paste(text[x >= name_x], collapse = " "),
              .groups = "drop") |>
    select(acronym, az_ka_name)
}

#' Parse one A-to-Z table page into rows.
#'
#' Every cell is top aligned, so a row starts on the baseline of its KA
#' acronym (set in smaller type a point lower) and runs to the next one. The
#' red section letters (A, B, ...) are larger type and are dropped.
cybok_parse_atoz_page <- function(words, term_x_max = 240, ka_x_min = 470) {
  head_row <- words |> filter(text == "INDICATIVE", x < 100)
  if (nrow(head_row) == 0) return(NULL)
  body <- words |>
    filter(y > head_row$y[1] + 5, y < cybok_config$footer_min_y) |>
    filter(!(height >= 11 & x < term_x_max))
  anchors <- body |> filter(x >= ka_x_min) |> arrange(y)
  if (nrow(anchors) == 0) return(NULL)
  term_l <- cybok_lines(body |> filter(x < term_x_max))
  topic_l <- cybok_lines(body |> filter(x >= term_x_max, x < ka_x_min))
  starts <- c(anchors$y - 3, Inf)
  if (any(term_l$y < starts[1]) || any(topic_l$y < starts[1])) {
    stop("A-to-Z page: text above the first row anchor.")
  }
  map(seq_len(nrow(anchors)), \(k) {
    tl <- term_l |> filter(y >= starts[k], y < starts[k + 1])
    pl <- topic_l |> filter(y >= starts[k], y < starts[k + 1])
    tibble(indicative_material      = cybok_join_lines(tl$text),
           topic                    = cybok_join_lines(pl$text),
           ka_acronym               = anchors$text[k],
           indicative_material_soft = cybok_join_lines(tl$text, soft_hyphen = TRUE),
           topic_soft               = cybok_join_lines(pl$text, soft_hyphen = TRUE))
  }) |> bind_rows()
}

cybok_parse_atoz <- function(pages) {
  map(seq_along(pages), \(p) {
    rows <- cybok_parse_atoz_page(pages[[p]])
    if (is.null(rows)) return(NULL)
    rows |> mutate(page = p, .before = 1)
  }) |>
    bind_rows() |>
    mutate(row = row_number(), .before = 1)
}

# ---------------------------------------------------------------------------
# Knowledge Trees: node labels from the text layer
# ---------------------------------------------------------------------------

#' Rebuild the node labels of one Knowledge Tree page from its words. Every
#' label sits on one baseline, and words on a baseline split into labels where
#' the horizontal gap exceeds `node_gap`.
cybok_tree_labels <- function(words, node_gap = cybok_config$node_gap) {
  words |>
    mutate(line = cybok_line_ids(y)) |>
    arrange(line, x) |>
    group_by(line) |>
    mutate(node = cumsum(c(TRUE, diff(x) - head(width, -1) > node_gap))) |>
    group_by(line, node) |>
    summarise(y = min(y), x0 = min(x), x1 = max(x + width),
              text = paste(text, collapse = " "), .groups = "drop") |>
    arrange(y, x0) |>
    transmute(node_id = row_number(), text, x0, x1, y)
}

#' The title printed on a tree's cover ("Network Security Knowledge Tree").
cybok_tree_title <- function(cover_words) {
  lines <- cybok_lines(cover_words |> filter(height > 15))$text
  str_remove(cybok_join_lines(lines), "^The Cyber Security Body of Knowledge ")
}

# ---------------------------------------------------------------------------
# Knowledge Trees: links from the drawing
# ---------------------------------------------------------------------------

#' Find the box drawn around one label, in pixels of a rendered page.
#'
#' Searches outward from the label's text box for the first row above and
#' below that is ink across the label's width, then for the first column
#' left and right that is ink down the box's height, then walks each side to
#' the outer edge of its stroke.
#'
#' @param ink Logical matrix, ink[x, y].
#' @param x0,x1,y0,y1 The label's text box, in points.
#' @param s Pixels per point.
#' @param search How far outside the text box to look, in points.
#' @return Named integer vector (l, r, t, b), or NULL when no box is found.
cybok_find_box <- function(ink, x0, x1, y0, y1, s, search) {
  span <- round(x0 * s):round(x1 * s)
  span <- span[span >= 1 & span <= nrow(ink)]
  full_row <- function(r) r >= 1 && r <= ncol(ink) && mean(ink[span, r]) > 0.9
  up <- rev(round((y0 - search) * s):round(y0 * s))
  down <- round(y1 * s):round((y1 + search) * s)
  top <- up[which(vapply(up, full_row, logical(1)))[1]]
  bot <- down[which(vapply(down, full_row, logical(1)))[1]]
  if (is.na(top) || is.na(bot) || bot - top < 4) return(NULL)
  inner <- (top + 2):(bot - 2)
  full_col <- function(cc) cc >= 1 && cc <= nrow(ink) && mean(ink[cc, inner]) > 0.9
  left_c <- rev(round((x0 - search) * s):(round(x0 * s) + round(s)))
  right_c <- (round(x1 * s) - round(s)):round((x1 + search) * s)
  left <- left_c[which(vapply(left_c, full_col, logical(1)))[1]]
  right <- right_c[which(vapply(right_c, full_col, logical(1)))[1]]
  if (is.na(left) || is.na(right)) return(NULL)
  while (full_row(top - 1)) top <- top - 1
  while (full_row(bot + 1)) bot <- bot + 1
  while (full_col(left - 1)) left <- left - 1
  while (full_col(right + 1)) right <- right + 1
  c(l = left, r = right, t = top, b = bot)
}

#' Split ink into 8-connected components.
#'
#' @param ink Logical matrix, ink[x, y].
#' @return Data frame of horizontal ink runs (y, x_from, x_to, comp).
cybok_ink_components <- function(ink) {
  runs <- map(seq_len(ncol(ink)), \(j) {
    v <- ink[, j]
    if (!any(v)) return(NULL)
    r <- rle(v)
    ends <- cumsum(r$lengths)
    starts <- ends - r$lengths + 1
    data.frame(y = j, x_from = starts[r$values], x_to = ends[r$values])
  }) |> bind_rows()
  if (nrow(runs) == 0) return(data.frame(y = integer(), x_from = integer(),
                                         x_to = integer(), comp = integer()))
  parent <- seq_len(nrow(runs))
  find <- function(i) {
    while (parent[i] != i) {
      parent[i] <<- parent[parent[i]]
      i <- parent[i]
    }
    i
  }
  by_row <- split(seq_len(nrow(runs)), runs$y)
  rows <- as.integer(names(by_row))
  for (k in seq_along(rows)[-1]) {
    if (rows[k] - rows[k - 1] != 1) next
    above <- by_row[[k - 1]]
    for (i in by_row[[k]]) {
      hit <- above[runs$x_from[above] <= runs$x_to[i] + 1 &
                     runs$x_from[i] <= runs$x_to[above] + 1]
      for (a in hit) {
        ri <- find(i)
        ra <- find(a)
        if (ri != ra) parent[ri] <- ra
      }
    }
  }
  runs$comp <- vapply(seq_len(nrow(runs)), find, integer(1))
  runs
}

#' Read the Topics and their Indicative Material off a tree drawing.
#'
#' @param labels Tibble from cybok_tree_labels(): node_id, text, x0, x1, y.
#' @param ink Logical matrix ink[x, y] of the rendered page.
#' @param s Pixels per point.
#' @param label_height Text height of the labels, in points.
#' @return List: nodes (labels plus is_topic), links (topic node_id, child
#'   node_id), and problems (character).
cybok_tree_links <- function(labels, ink, s, label_height,
                             touch = cybok_config$touch_px) {
  search <- max(6, 2.5 * label_height)
  boxes <- map(seq_len(nrow(labels)), \(i)
    cybok_find_box(ink, labels$x0[i], labels$x1[i], labels$y[i],
                   labels$y[i] + label_height, s, search))
  problems <- character(0)
  unboxed <- which(map_lgl(boxes, is.null))
  if (length(unboxed) > 0) {
    problems <- c(problems, paste0("no box found around \"", labels$text[unboxed], "\""))
    return(list(nodes = mutate(labels, is_topic = FALSE),
                links = tibble(topic = integer(), child = integer()),
                problems = problems))
  }
  for (b in boxes) ink[(b["l"] - 1):(b["r"] + 1), (b["t"] - 1):(b["b"] + 1)] <- FALSE
  runs <- cybok_ink_components(ink)
  touching <- map(boxes, \(b) unique(runs$comp[
    runs$y >= b["t"] - 1 - touch & runs$y <= b["b"] + 1 + touch &
      runs$x_to >= b["l"] - 1 - touch & runs$x_from <= b["r"] + 1 + touch]))

  # The root is the unlabelled point at the far left where the Topic lines
  # meet. Its fan is every component that reaches that point (the lines meet
  # at a point, so antialiasing can leave more than one component there), and
  # the boxes the fan touches are the Topics.
  linking <- unique(unlist(touching))
  if (length(linking) == 0) {
    return(list(nodes = mutate(labels, is_topic = FALSE),
                links = tibble(topic = integer(), child = integer()),
                problems = "no lines touch any node box"))
  }
  linked_runs <- runs[runs$comp %in% linking, ]
  root_x <- min(linked_runs$x_from)
  root_y <- linked_runs$y[linked_runs$x_from == root_x]
  near_root <- abs(linked_runs$x_from - root_x) <= round(2 * s) &
    linked_runs$y >= min(root_y) - round(2 * s) & linked_runs$y <= max(root_y) + round(2 * s)
  root <- unique(linked_runs$comp[near_root])
  # A root line that grazes another Topic's box is cut in two by the blanked
  # box. The far piece never reaches past the right side of the Topic box it
  # grazed, which every line leaving a Topic for its children does, so such
  # pieces join the root's fan until nothing changes.
  comp_max_x <- tapply(runs$x_to, runs$comp, max)
  repeat {
    is_topic <- map_lgl(touching, \(t) any(root %in% t))
    grazing <- unique(unlist(map(which(is_topic), \(t) {
      cs <- setdiff(touching[[t]], root)
      cs[comp_max_x[as.character(cs)] <= boxes[[t]]["r"] + 1]
    })))
    if (length(grazing) == 0) break
    root <- c(root, grazing)
  }
  centre <- (labels$x0 + labels$x1) / 2

  links <- map(which(is_topic), \(t) {
    fan <- setdiff(touching[[t]], root)
    kids <- which(!is_topic & centre > centre[t] &
                    map_lgl(touching, \(c) any(c %in% fan)))
    tibble(topic = rep(labels$node_id[t], length(kids)), child = labels$node_id[kids])
  }) |> bind_rows()
  multi <- links |> count(child) |> filter(n > 1)
  if (nrow(multi) > 0) {
    problems <- c(problems, paste0("\"", labels$text[match(multi$child, labels$node_id)],
                                   "\" hangs from ", multi$n, " Topics"))
  }
  list(nodes = mutate(labels, is_topic = is_topic), links = links, problems = problems)
}

#' Parse one tree PDF: its cover title, its Topics and their Indicative
#' Material.
cybok_parse_tree <- function(pdf_path, dpi = cybok_config$render_dpi) {
  pages <- pdf_data(pdf_path)
  p <- length(pages)
  words <- pages[[p]] |>
    filter(y > cybok_config$header_max_y, y < cybok_config$footer_min_y)
  labels <- cybok_tree_labels(words)
  bitmap <- pdf_render_page(pdf_path, page = p, dpi = dpi, numeric = FALSE)
  grey <- pmax(as.integer(bitmap[1, , ]), as.integer(bitmap[2, , ]), as.integer(bitmap[3, , ]))
  ink <- matrix(grey < cybok_config$ink_below, nrow = dim(bitmap)[2], ncol = dim(bitmap)[3])
  s <- dpi / 72
  ink[, c(seq_len(round(cybok_config$header_max_y * s)),
          round(cybok_config$footer_min_y * s):ncol(ink))] <- FALSE
  graph <- cybok_tree_links(labels, ink, s, label_height = median(words$height))
  list(title = cybok_tree_title(pages[[1]]), nodes = graph$nodes,
       links = graph$links, problems = graph$problems)
}

#' Topics and Indicative Material of one parsed tree, in tree order (top to
#' bottom).
cybok_tree_tables <- function(tree, acronym) {
  topics <- tree$nodes |>
    filter(is_topic) |>
    arrange(y, x0) |>
    mutate(ka_acronym = acronym, ordinal = row_number(),
           topic_id = sprintf("%s-%02d", acronym, ordinal))
  im <- tree$links |>
    left_join(topics |> select(topic = node_id, topic_id, topic_ordinal = ordinal),
              by = "topic") |>
    left_join(tree$nodes |> select(child = node_id, term = text, y, x0), by = "child") |>
    arrange(topic_ordinal, y, x0) |>
    group_by(topic_id) |>
    mutate(ordinal = row_number()) |>
    ungroup() |>
    transmute(ka_acronym = acronym, topic_id, ordinal, term)
  list(topics = topics |> select(ka_acronym, topic_id, ordinal, title = text),
       im = im)
}

# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------

#' Look every carried string up in the independent extraction of its own
#' source document, after the two documented normalisations.
cybok_verbatim_check <- function(checks, reference_texts) {
  ref <- map_chr(reference_texts, cybok_normalise_text)
  checks |>
    mutate(found = map2_lgl(text, source_file, \(t, s) grepl(t, ref[[s]], fixed = TRUE)))
}

#' Resolve A-to-Z rows against the trees' Topics and Indicative Material.
#'
#' @param atoz Parsed A-to-Z rows.
#' @param topics,im Tables from the trees, including the Introduction tree
#'   under acronym "CI".
cybok_resolve_atoz <- function(atoz, topics, im) {
  topic_keys <- topics |> transmute(ka_acronym, key = cybok_fold(title), topic_id, tree_topic = title)
  term_keys <- im |>
    transmute(topic_id, key = cybok_fold(term), term_in_tree = term) |>
    distinct(topic_id, key, .keep_all = TRUE)
  match_topic <- function(acr, hard, soft) {
    k <- topic_keys[topic_keys$ka_acronym == acr, ]
    i <- match(cybok_fold(hard), k$key)
    if (is.na(i)) i <- match(cybok_fold(soft), k$key)
    if (is.na(i)) c(NA_character_, NA_character_) else c(k$topic_id[i], k$tree_topic[i])
  }
  hit <- pmap(list(atoz$ka_acronym, atoz$topic, atoz$topic_soft), match_topic)
  atoz$topic_id <- map_chr(hit, 1)
  atoz$tree_topic <- map_chr(hit, 2)
  atoz$term_in_tree <- pmap_chr(list(atoz$topic_id, atoz$indicative_material,
                                     atoz$indicative_material_soft), \(tid, hard, soft) {
    if (is.na(tid)) return(NA_character_)
    k <- term_keys[term_keys$topic_id == tid, ]
    i <- match(cybok_fold(hard), k$key)
    if (is.na(i)) i <- match(cybok_fold(soft), k$key)
    if (is.na(i)) NA_character_ else k$term_in_tree[i]
  })
  # Where the row does not resolve, say whether the term is in the KA's tree
  # at all, and under which Topic, so a Topic worded differently in the two
  # documents can be told apart from a term the tree does not have.
  ka_terms <- im |>
    transmute(ka_acronym = str_remove(topic_id, "-[0-9]+$"), topic_id,
              key = cybok_fold(term))
  atoz$term_topic_in_tree <- pmap_chr(list(atoz$ka_acronym, atoz$indicative_material,
                                           atoz$indicative_material_soft), \(acr, hard, soft) {
    k <- ka_terms[ka_terms$ka_acronym == acr, ]
    hit <- k$topic_id[k$key %in% cybok_fold(c(hard, soft))]
    if (length(hit) == 0) NA_character_ else paste(unique(hit), collapse = " ")
  })
  atoz |>
    mutate(status = case_when(
      !is.na(topic_id) & !is.na(term_in_tree) ~ "resolved",
      is.na(topic_id) & !is.na(term_topic_in_tree) ~ "topic worded differently, term in tree",
      is.na(topic_id) ~ "topic and term not in tree",
      !is.na(term_topic_in_tree) ~ "term under a different topic in the tree",
      TRUE ~ "topic resolved, term not in tree"
    ))
}

# ---------------------------------------------------------------------------
# Crosswalk resolution (the staged SFIA and ECSF crosswalks)
# ---------------------------------------------------------------------------

#' Resolve the KA names the staged crosswalks print to KA acronyms. Exact
#' match first. The ECSF study writes "and" where Figure 2 prints "&", so a
#' second pass accepts that one substitution and says so.
cybok_resolve_crosswalk_kas <- function(ka_names, kas) {
  tibble(printed = unique(ka_names)) |>
    mutate(
      exact = kas$ka_acronym[match(printed, kas$ka_name)],
      amp = kas$ka_acronym[match(str_replace_all(printed, " and ", " & "), kas$ka_name)],
      ka_acronym = coalesce(exact, amp),
      resolution = case_when(!is.na(exact) ~ "exact",
                             !is.na(amp) ~ "and read as ampersand",
                             TRUE ~ "unresolved")
    ) |>
    select(printed, ka_acronym, resolution)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main <- function() {
  message("=== CyBOK v1.1.0 Ingestion ===")
  staging <- cybok_config$staging_dir
  manifest_path <- file.path(staging, cybok_config$manifest_filename)
  if (!file.exists(manifest_path)) stop("provenance.yml not found at ", manifest_path)
  manifest <- read_yaml(manifest_path)

  message("Verifying staged files against provenance.yml hashes...")
  verify_cybok_hashes(manifest, staging)

  intro_file <- cybok_files_of_role(manifest, "introduction")$filename
  atoz_file  <- cybok_files_of_role(manifest, "indicative_material_index")$filename
  trees      <- cybok_files_of_role(manifest, "knowledge_tree")
  intro_tree <- cybok_files_of_role(manifest, "introduction_tree")$filename
  check_of   <- cybok_files_of_role(manifest, "verification_text")

  # Figure 2.
  intro_pages <- pdf_data(file.path(staging, intro_file))
  fig2_page <- which(map_lgl(intro_pages, \(w) any(w$text == "Short") &&
                               any(w$text == "descriptions")))
  if (length(fig2_page) != 1) stop("Figure 2 page not found in the Introduction.")
  fig2 <- cybok_parse_figure2(intro_pages[[fig2_page]])
  categories <- fig2$categories

  # A-to-Z.
  atoz_pages <- pdf_data(file.path(staging, atoz_file))
  acr_page <- which(map_lgl(atoz_pages, \(w) any(w$text == "Acronym")))
  acronyms <- cybok_parse_acronyms(atoz_pages[[acr_page[1]]])
  atoz <- cybok_parse_atoz(atoz_pages)

  # Knowledge Areas: each declared tree file binds an acronym to a Figure 2
  # name. Both halves are checked against the documents below.
  kas <- trees |>
    select(ka_acronym, ka_name, version, tree_file = filename) |>
    left_join(fig2$kas, by = "ka_name") |>
    left_join(acronyms, by = c("ka_acronym" = "acronym")) |>
    arrange(ka_order)

  message("Reading ", nrow(kas) + 1, " Knowledge Trees...")
  parsed <- map(file.path(staging, kas$tree_file), cybok_parse_tree)
  kas$tree_title <- map_chr(parsed, "title")
  tables <- map2(parsed, kas$ka_acronym, cybok_tree_tables)
  topics <- map(tables, "topics") |> bind_rows()
  im <- map(tables, "im") |> bind_rows()
  tree_problems <- unlist(map2(parsed, kas$ka_acronym, \(p, acr)
    if (length(p$problems)) paste0(acr, ": ", p$problems)))

  # The Introduction tree, for the CI rows of the cross-check only.
  ci <- cybok_tree_tables(cybok_parse_tree(file.path(staging, intro_tree)), "CI")
  tree_problems <- c(tree_problems, if (nrow(ci$topics) == 0) "CI: no Topics found")

  atoz_res <- cybok_resolve_atoz(atoz, bind_rows(topics, ci$topics), bind_rows(im, ci$im))

  # Verbatim check.
  refs <- set_names(map(file.path(staging, check_of$filename), read_file), check_of$text_of)
  tree_of <- function(acr) kas$tree_file[match(acr, kas$ka_acronym)]
  checks <- bind_rows(
    tibble(field = "category_name", id = as.character(categories$category_order),
           text = categories$category_name, source_file = intro_file),
    tibble(field = "ka_name", id = kas$ka_acronym, text = kas$ka_name,
           source_file = intro_file),
    tibble(field = "topic_title", id = topics$topic_id, text = topics$title,
           source_file = tree_of(topics$ka_acronym)),
    tibble(field = "indicative_material", id = paste0(im$topic_id, ".", im$ordinal),
           text = im$term, source_file = tree_of(im$ka_acronym))
  )
  check <- cybok_verbatim_check(checks, refs)

  # Crosswalks staged earlier in this directory.
  xw_sfia <- read_csv(file.path(staging, "tables", "cybok-sfia-mapping.csv"),
                      show_col_types = FALSE)
  xw_ecsf <- read_csv(file.path(staging, "tables", "cybok-ecsf-mapping.csv"),
                      show_col_types = FALSE)
  xw <- bind_rows(
    cybok_resolve_crosswalk_kas(xw_sfia$ka, kas) |> mutate(crosswalk = "sfia", .before = 1),
    cybok_resolve_crosswalk_kas(setdiff(xw_ecsf$primary_ka, "N/A"), kas) |>
      mutate(crosswalk = "ecsf", .before = 1)
  )

  # Checks that stop the ingest.
  problems <- c(
    if (nrow(categories) != 5) paste("categories:", nrow(categories), "vs the Introduction's five"),
    if (nrow(fig2$kas) != 21) paste("Figure 2 KAs:", nrow(fig2$kas), "vs the Introduction's 21"),
    if (any(is.na(fig2$kas$category_name))) "a Figure 2 KA sits above the first category",
    if (nrow(kas) != 21) paste("declared KA trees:", nrow(kas), "vs 21"),
    if (any(is.na(kas$ka_order))) paste("declared KA name not in Figure 2:",
                                        paste(kas$ka_name[is.na(kas$ka_order)], collapse = ", ")),
    if (any(is.na(kas$az_ka_name))) paste("declared acronym not in the A-to-Z:",
                                          paste(kas$ka_acronym[is.na(kas$az_ka_name)], collapse = ", ")),
    if (anyDuplicated(kas$ka_acronym) || anyDuplicated(kas$ka_name)) "a KA is declared twice",
    if (!all(atoz$ka_acronym %in% acronyms$acronym))
      "an A-to-Z row carries an acronym missing from its acronym table",
    if (any(!nzchar(atoz$indicative_material) | !nzchar(atoz$topic))) "an A-to-Z row has an empty cell",
    if (anyDuplicated(topics$topic_id)) "duplicate Topic ids",
    if (any(!kas$ka_acronym %in% topics$ka_acronym)) "a tree without Topics",
    tree_problems
  )

  tables_dir <- file.path(staging, cybok_config$tables_subdir)
  dir.create(tables_dir, showWarnings = FALSE, recursive = TRUE)
  write_csv(categories, file.path(tables_dir, "categories.csv"))
  write_csv(kas |> select(ka_acronym, ka_name, category_name, ka_order, version,
                          tree_title, az_ka_name, tree_file),
            file.path(tables_dir, "knowledge-areas.csv"))
  write_csv(topics, file.path(tables_dir, "topics.csv"))
  write_csv(im, file.path(tables_dir, "indicative-material.csv"))
  write_csv(atoz |> select(row, page, indicative_material, topic, ka_acronym),
            file.path(tables_dir, "a-to-z.csv"))
  write_csv(atoz_res |> select(row, page, indicative_material, topic, ka_acronym,
                               topic_id, tree_topic, term_in_tree, term_topic_in_tree,
                               status),
            file.path(tables_dir, "a-to-z-resolution.csv"), na = "")
  write_csv(check, file.path(tables_dir, "verbatim-check.csv"))
  write_csv(xw, file.path(tables_dir, "crosswalk-ka-resolution.csv"), na = "")

  if (length(problems) > 0) {
    stop("CyBOK extraction failed its checks:\n  ", paste(problems, collapse = "\n  "))
  }

  is_ci <- atoz_res$ka_acronym == "CI"
  ka_rows <- atoz_res[!is_ci, ]
  # The measured counts below are rewritten on every run. Only the declared
  # extraction method and the crosswalks' own counts are carried over, so a
  # count this script no longer measures cannot linger in the manifest.
  keep <- c("tool", "text_normalisation", "cybok_sfia_mapping", "cybok_ecsf_mapping")
  manifest$extraction <- manifest$extraction[intersect(keep, names(manifest$extraction))]
  manifest$extraction$categories              <- nrow(categories)
  manifest$extraction$knowledge_areas         <- nrow(kas)
  manifest$extraction$topics                  <- nrow(topics)
  manifest$extraction$indicative_material     <- nrow(im)
  # A Topic the tree draws with no children (Applied Cryptography's "Future
  # of Applied Cryptography", which the A-to-Z lists as "CELL LEFT
  # DELIBERATELY BLANK").
  manifest$extraction$topics_without_indicative_material <- sum(!topics$topic_id %in% im$topic_id)
  manifest$extraction$a_to_z_rows             <- nrow(atoz)
  manifest$extraction$a_to_z_rows_knowledge_areas <- nrow(ka_rows)
  manifest$extraction$a_to_z_rows_resolved    <- sum(ka_rows$status == "resolved")
  manifest$extraction$a_to_z_status <- as.list(table(ka_rows$status))
  manifest$extraction$a_to_z_rows_introduction <- sum(is_ci)
  manifest$extraction$a_to_z_rows_introduction_resolved <-
    sum(atoz_res$status[is_ci] == "resolved")
  manifest$extraction$verbatim_checked        <- nrow(check)
  manifest$extraction$verbatim_found          <- sum(check$found)
  manifest$extraction$crosswalk_ka_names_resolved   <- sum(xw$resolution != "unresolved")
  manifest$extraction$crosswalk_ka_names_unresolved <- sum(xw$resolution == "unresolved")
  write_yaml(manifest, manifest_path)

  message("\n=== Summary ===")
  message("  Categories: ", nrow(categories), "  Knowledge Areas: ", nrow(kas),
          "  Topics: ", nrow(topics), "  Indicative Material: ", nrow(im))
  message("  A-to-Z rows: ", nrow(atoz), ", of which ", nrow(ka_rows), " name a KA:")
  st <- table(ka_rows$status)
  message(paste0("    ", names(st), ": ", st, collapse = "\n"))
  message("  Verbatim check: ", sum(check$found), " of ", nrow(check), " found")
  message("\nDone.")

  invisible(list(kas = kas, topics = topics, im = im, atoz = atoz_res, check = check))
}

if (sys.nframe() == 0) {
  main()
}
