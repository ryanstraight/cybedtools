# Similarity Helpers, Canonical Text-Similarity Layer
#
# Canonical implementations of the tokenization / Jaccard / ranking /
# tiering logic used by the concordance data-prep scripts
# (concordance/_data-prep-*.R). Until 2026-08-20 these functions lived as
# script-local copies, triplicated across the three alignment scripts and
# already drifted (the two NICE-facing scripts carry ten extra stopwords
# the K-12 script lacks). Promoting them into the package makes them
# testable and gives the scripts one implementation to converge on.
#
# All functions here are internal (not exported). The concordance scripts
# can call them via cybedtools:::tokenize() etc., or keep their local
# copies pinned by the drift-tripwire tests in
# tests/testthat/test-similarity-helpers.R until they are refactored.

#' Stopword lists used by the concordance similarity scripts
#'
#' Two profiles exist in the wild:
#' - `"k12"`: the base list used by `_data-prep-k12-alignment.R`.
#' - `"workforce"`: the base list plus ten extra words
#'   (`any/all/new/one/two/three/work/perform/performs/ensure`) used by the
#'   NICE-vs-ECSF and NICE-vs-CSEC2017 scripts.
#'
#' The divergence is preserved deliberately rather than silently unified:
#' collapsing the lists would change published concordance tables. Tests
#' pin both lists and the containment relation between them.
#'
#' @param profile Character, `"workforce"` (default) or `"k12"`.
#' @return Character vector of stopwords.
#' @noRd
similarity_stopwords <- function(profile = c("workforce", "k12")) {
  profile <- match.arg(profile)

  base <- c(
    "the","a","an","of","in","to","for","with","and","or","is","are","be","by",
    "on","at","as","that","this","their","they","it","its","from","how","can",
    "use","using","used","may","will","such","but","not","do","have","has",
    "what","which","when","between","into","about","also","than","then","there",
    "these","those","while","each","other","both","more","most","some","many",
    "include","including","includes","example","examples","based","through"
  )

  workforce_extra <- c(
    "any","all","new","one","two","three","work","perform","performs","ensure"
  )

  switch(profile,
    k12       = base,
    workforce = c(base, workforce_extra)
  )
}

#' Tokenize a text scalar for Jaccard comparison
#'
#' Lowercases, splits on runs of non-alphanumeric characters, drops tokens
#' shorter than 3 characters and stopwords, and de-duplicates (set
#' semantics -- the output feeds `jaccard()`).
#'
#' Known lossy behaviors, pinned by tests rather than accidental:
#' - 2-character domain terms ("AI", "OS", "IT", "5G", the halves of
#'   "wi-fi") are unrecoverably dropped by the `nchar >= 3` rule.
#' - Non-ASCII letters are split boundaries under `[^a-z0-9]+`, so
#'   accented text degrades ("café" -> "caf"). Matters for EU-origin
#'   framework text (ECSF).
#'
#' Contract hardening over the script-local copies (which crashed on both):
#' `character(0)` returns `character(0)`; length > 1 input signals a
#' classed error (`cybedtools_scalar_input`) instead of a bare condition
#' error.
#'
#' @param x Character scalar (or `character(0)` / `NA`).
#' @param stopwords Character vector; defaults to the workforce profile.
#' @return Character vector of unique tokens.
#' @noRd
tokenize <- function(x, stopwords = similarity_stopwords("workforce")) {
  if (is.null(x) || length(x) == 0L) return(character(0))
  if (length(x) > 1L) {
    rlang::abort(
      c(
        "`x` must be a length-1 character vector.",
        "x" = paste0("Got length ", length(x), "."),
        "i" = "Call tokenize() once per document (e.g., via lapply())."
      ),
      class = "cybedtools_scalar_input"
    )
  }
  if (is.na(x) || !nzchar(x)) return(character(0))

  toks <- strsplit(tolower(x), "[^a-z0-9]+")[[1]]
  toks <- toks[nchar(toks) >= 3 & !toks %in% stopwords]
  unique(toks)
}

#' Jaccard similarity of two token sets
#'
#' Set-Jaccard: |intersection| / |union|. Inputs are treated as sets
#' (duplicates ignored) and `NA` tokens are dropped, so callers need not
#' pre-clean. Either side empty (after NA removal) returns exactly 0 --
#' the deliberate empty-set convention used across the concordance
#' scripts (not the mathematical-purist 1 for empty-empty). The scripts'
#' `u == 0` branch was dead code (union of two non-empty sets is
#' non-empty) and is not reproduced here.
#'
#' @param a,b Character vectors of tokens.
#' @return Numeric scalar in `[0, 1]`.
#' @noRd
jaccard <- function(a, b) {
  a <- unique(a[!is.na(a)])
  b <- unique(b[!is.na(b)])
  if (length(a) == 0 || length(b) == 0) return(0)
  length(intersect(a, b)) / length(union(a, b))
}

#' Top-N candidate matches per group, deterministic tie-break
#'
#' Canonical form of the ranking idiom triplicated across the concordance
#' scripts (`arrange(ni, desc(similarity)) |> group_by(ni) |>
#' slice_head(n) |> mutate(rank = row_number())`), with two hardenings the
#' scripts lack:
#' - Ties are broken by ascending `candidate`, so the published best match
#'   for a tied pair cannot flip between graph rebuilds (SPARQL result
#'   order is not contractually stable; the scripts' tie-break was
#'   whatever row order the pull happened to emit).
#' - A `zero_match` flag marks rows whose score is exactly 0, so a group
#'   with no token overlap anywhere does not present an arbitrary
#'   candidate as a real rank-1 match.
#'
#' @param grid Tibble/data frame with columns `group`, `candidate`,
#'   `score`. One row per (group, candidate) pair.
#' @param n Integer, matches to keep per group. Groups with fewer than `n`
#'   candidates return all their candidates (no padding, no error).
#' @return The top-`n` rows per group, ranked `1..k` within each group
#'   (dense, restarting per group), with added `rank` and `zero_match`
#'   columns.
#' @noRd
top_n_matches <- function(grid, n = 3) {
  required <- c("group", "candidate", "score")
  missing_cols <- setdiff(required, names(grid))
  if (length(missing_cols) > 0) {
    rlang::abort(
      c(
        "`grid` is missing required column(s).",
        "x" = paste0("Missing: ", paste(missing_cols, collapse = ", "), "."),
        "i" = "top_n_matches() expects columns `group`, `candidate`, `score`."
      ),
      class = "cybedtools_bad_grid"
    )
  }

  grid |>
    dplyr::arrange(.data$group, dplyr::desc(.data$score), .data$candidate) |>
    dplyr::group_by(.data$group) |>
    dplyr::slice_head(n = n) |>
    dplyr::mutate(
      rank = dplyr::row_number(),
      zero_match = .data$score == 0
    ) |>
    dplyr::ungroup()
}

#' Strength tier for a similarity score
#'
#' Canonical form of the `case_when` tiering in
#' `_data-prep-k12-alignment.R` (lines 198-212). Boundaries are inclusive
#' (`>=`): exactly 0.30 is "strong", exactly 0.20 is "moderate", exactly
#' 0.10 is "weak". Note the k12 script applies this AFTER `round(x, 3)`,
#' so a raw 0.2995-ish value can round up across the boundary; tests pin
#' that round-then-tier interaction explicitly.
#'
#' @param x Numeric vector of similarity scores.
#' @return Character vector of `"strong"`, `"moderate"`, `"weak"`,
#'   `"none"`.
#' @noRd
similarity_strength <- function(x) {
  dplyr::case_when(
    x >= 0.30 ~ "strong",
    x >= 0.20 ~ "moderate",
    x >= 0.10 ~ "weak",
    TRUE      ~ "none"
  )
}

#' Cross-framework unit-text similarity, top-n matches per unit
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Reproduces, as the one public entry point, the "full-document" Jaccard
#' similarity computed script-locally by the concordance data-prep scripts
#' (`concordance/_data-prep-*.R`, e.g. `_data-prep-nice-ecsf-alignment.R`'s
#' `build_full_doc()`): each organizing unit's comparison text is its own
#' `schema:name`, its own `cybed:elementText` when it carries one directly
#' (true for pedagogy units where the unit and its top-level statement share
#' one IRI, e.g. Cyber.org/CSTA cells), and the concatenated
#' `cybed:elementText` of every element reachable via
#' [unit_element_bindings()] (true for workforce units, whose task/
#' knowledge/skill statements are separate elements linked by
#' `cybed:hasElement`). This single text-assembly rule is what lets one
#' function serve both structural shapes. Every (from-unit, to-unit) pair is
#' then scored with `jaccard()`, the top `n` matches per from-unit are kept
#' via `top_n_matches()`, and each score's `similarity_strength()` is
#' attached. The tokenizer, the Jaccard set-similarity, the stopword list
#' and the ranking tie-break are internal (`@noRd`) and may change without
#' notice; only this function's signature and output shape are the
#' contract.
#'
#' `from` and `to` select organizing units by `framework_slug`
#' ([organizing_unit_framework_bindings()]`$framework_slug`), matching how
#' the concordance scripts partition units before scoring
#' (`framework_slug == "cyberorg-k12"` vs `"csta-2017"`, for example). A
#' unit with no name, no own text, and no child element text at all
#' contributes no rows on either side (empty document, nothing to compare).
#'
#' @param rdf An rdf object.
#' @param from,to Character scalars, the `framework_slug` values (from
#'   [organizing_unit_framework_bindings()]) whose organizing units are
#'   compared, either as the versioned slug (`"nice-v2"`) or the short
#'   release-file slug (`"nice"`; see [cybed_fetch()]). May be identical, to
#'   find near-duplicate units within one framework. An unknown slug (in
#'   either vocabulary, and not present in `rdf`) errors with class
#'   `cybedtools_framework_not_found` rather than silently returning an
#'   empty result.
#' @param n Integer, matches to keep per from-unit (default `5`).
#' @return A tibble with one row per (from unit, match): columns
#'   `from_unit`, `to_unit` (both full IRIs), `score` (numeric in `[0, 1]`),
#'   `strength` (`"strong"`/`"moderate"`/`"weak"`/`"none"`), and `rank`
#'   (integer, `1..k`, dense per `from_unit`). A `from`-side unit with zero
#'   candidates on the `to` side contributes no rows. A `from`-side unit
#'   whose only candidates all score 0 still appears, ranked, with
#'   `strength == "none"`.
#' @family similarity helpers
#' @export
#' @examples
#' rdf <- make_demo_graph()
#' # make_demo_graph()'s two frameworks carry no cybed:elementText or
#' # cybed:hasElement text, so this is a zero-row tibble with the columns
#' # from_unit/to_unit/score/strength/rank.
#' framework_similarity(rdf, from = "demo-fw-a", to = "demo-fw-b")
#'
#' \dontrun{
#' rdf <- load_combined_ntriples_graph()
#' framework_similarity(rdf, from = "cyberorg-k12", to = "csta-2017", n = 3)
#' }
framework_similarity <- function(rdf, from, to, n = 5) {
  stopifnot(is.character(from), length(from) == 1L)
  stopifnot(is.character(to), length(to) == 1L)

  units <- organizing_unit_framework_bindings(rdf)
  known_slugs <- unique(units$framework_slug)
  from <- resolve_framework_slug(from, known_slugs, arg = "from")
  to   <- resolve_framework_slug(to, known_slugs, arg = "to")

  texts <- element_text(rdf)

  child_text <- unit_element_bindings(rdf) |>
    dplyr::inner_join(texts, by = "element") |>
    dplyr::group_by(.data$role) |>
    dplyr::summarise(child_text = paste(.data$text, collapse = " "), .groups = "drop") |>
    dplyr::rename(unit = "role")

  own_text <- dplyr::rename(texts, unit = "element", own_text = "text")

  side <- function(slug) {
    units |>
      dplyr::filter(.data$framework_slug == slug) |>
      dplyr::left_join(own_text, by = "unit") |>
      dplyr::left_join(child_text, by = "unit") |>
      dplyr::mutate(
        full_text = trimws(paste(
          dplyr::coalesce(.data$unit_name, ""),
          dplyr::coalesce(.data$own_text, ""),
          dplyr::coalesce(.data$child_text, "")
        ))
      ) |>
      dplyr::filter(nzchar(.data$full_text)) |>
      dplyr::transmute(
        unit   = .data$unit,
        tokens = lapply(.data$full_text, tokenize)
      )
  }

  from_units <- side(from)
  to_units   <- side(to)

  empty <- tibble::tibble(
    from_unit = character(0), to_unit = character(0),
    score = numeric(0), strength = character(0), rank = integer(0)
  )
  if (nrow(from_units) == 0 || nrow(to_units) == 0) {
    return(empty)
  }

  grid <- tidyr::expand_grid(
    fi = seq_len(nrow(from_units)),
    ti = seq_len(nrow(to_units))
  ) |>
    dplyr::mutate(
      group     = from_units$unit[.data$fi],
      candidate = to_units$unit[.data$ti],
      score     = purrr::map2_dbl(
        .data$fi, .data$ti,
        ~ jaccard(from_units$tokens[[.x]], to_units$tokens[[.y]])
      )
    )

  top_n_matches(grid, n = n) |>
    dplyr::transmute(
      from_unit = .data$group,
      to_unit   = .data$candidate,
      score     = round(.data$score, 10),
      strength  = similarity_strength(.data$score),
      rank      = .data$rank
    )
}

#' Filter unit bindings by a framework-name pattern, masking-proof
#'
#' Safe form of the `filter(grepl("^NICE", framework_name))` idiom used in
#' the concordance scripts. The parameter is named `fw_pattern` -- NEVER
#' `framework` -- because the binding tibbles carry `framework` /
#' `framework_name` columns, and a parameter sharing a column's name is
#' silently shadowed inside dplyr data-masking verbs (the filter matches
#' the column against itself and returns 0 rows with no warning; confirmed
#' in this project's analysis scripts, 2026-08). Implemented in base R so
#' no data mask exists to collide with, even if a caller's tibble carries
#' an `fw_pattern` column.
#'
#' @param unit_tbl Data frame with a `framework_name` column.
#' @param fw_pattern Character scalar regex matched against
#'   `framework_name`.
#' @return The rows of `unit_tbl` whose `framework_name` matches.
#' @noRd
filter_units_by_framework <- function(unit_tbl, fw_pattern) {
  stopifnot(is.character(fw_pattern), length(fw_pattern) == 1L)
  unit_tbl[grepl(fw_pattern, unit_tbl$framework_name), , drop = FALSE]
}
