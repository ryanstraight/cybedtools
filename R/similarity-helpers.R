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
