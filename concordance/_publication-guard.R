# Publication guard for the Concordance site data prep.
#
# ---------------------------------------------------------------------------
# The contract
# ---------------------------------------------------------------------------
#
# What this guard guarantees: no object written into concordance/_data carries
# framework statement text that the framework's steward did not permit us to
# publish. The check runs at the write side. Every object passes through
# assert_no_unpublishable_text() immediately before it is saved, and that
# function inspects every character column of the object rather than only the
# columns the caller thought to name.
#
# What this guard does not guarantee: it says nothing about what may be
# analysed. Every framework staged here was obtained lawfully and may be read,
# tokenised, scored and compared locally in full. A policy value in
# docs/framework-invariants.yml answers one question only, which is whether a
# framework's statement text may be published. It never answers whether that
# text may be analysed. Filtering a text pull by policy would silently change
# every similarity score in the analysis, which is a correctness bug dressed up
# as caution, so the pulls are not filtered.
#
# What counts as text. A title, a name, an identifier and a unit label are
# structure, and structure is publishable under every framework's terms here.
# Statement text and descriptions are not. The guard cannot tell the two apart
# by looking, so the caller declares it: structure_cols names the character
# columns that hold names and identifiers, and every other character column is
# treated as statement text. An undeclared character column therefore fails
# closed, which is the point. Forgetting a column makes the write stop, not
# pass.
#
# ---------------------------------------------------------------------------
# Policy values
# ---------------------------------------------------------------------------
#
# docs/framework-invariants.yml records the terms per framework in
# `public_redistribution`. Every recognised value is declared once, in
# PUBLICATION_POLICIES below. An unrecognised value is a hard stop at load
# time, naming the framework and the value, because a typo that read as
# publishable is exactly the failure this guard exists to prevent.
#
#   unrestricted          (the default when the field is absent) statement
#                         text may be published
#   full_with_attribution statement text may be published, attribution
#                         required
#   structure_only        titles, categories, levels and mappings may be
#                         published; statement text may not
#   local_only            nothing beyond aggregate counts is published; the
#                         framework's terms reach its structure as well as its
#                         text, so statement text may not be published
#
# Source this from each _data-prep-*.R after library(cybedtools).

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
})

# The single declaration of every recognised policy value. TRUE means statement
# text may be published under that policy.
PUBLICATION_POLICIES <- c(
  unrestricted          = TRUE,
  full_with_attribution = TRUE,
  structure_only        = FALSE,
  local_only            = FALSE
)

# Cache so the YAML is read once per session.
.pub_guard <- new.env(parent = emptyenv())

# Absence of a declared term means unrestricted, not unknown.
PUBLICATION_POLICY_DEFAULT <- "unrestricted"

publication_invariants_path <- function() {
  if (requireNamespace("here", quietly = TRUE)) {
    here::here("docs", "framework-invariants.yml")
  } else {
    file.path("docs", "framework-invariants.yml")
  }
}

#' Policy table: one row per framework declared in the invariants file.
#' Pass the graph to attach the framework IRIs and schema:name literals the
#' data-prep scripts actually hold, so name-based matching is exact rather
#' than guessed.
publication_policy <- function(rdf = NULL, path = publication_invariants_path()) {
  if (is.null(.pub_guard$policy)) {
    inv <- yaml::read_yaml(path)
    fw <- inv$frameworks
    if (is.null(fw) || !length(fw)) {
      stop("publication guard: no frameworks found in ", path)
    }
    policies <- vapply(fw, function(entry) {
      p <- entry[["public_redistribution"]]
      if (is.null(p)) PUBLICATION_POLICY_DEFAULT else as.character(p)[1]
    }, character(1), USE.NAMES = FALSE)

    unknown <- which(!policies %in% names(PUBLICATION_POLICIES))
    if (length(unknown)) {
      stop("publication guard: unrecognised public_redistribution value(s) in ",
           path, ": ",
           paste(sprintf("%s = %s", names(fw)[unknown], policies[unknown]),
                 collapse = "; "),
           ". Recognised values are ",
           paste(names(PUBLICATION_POLICIES), collapse = ", "),
           ". Refusing to load: an unrecognised value is unknown terms, not ",
           "safe terms.")
    }

    .pub_guard$policy <- tibble(
      framework_slug = names(fw),
      policy         = policies,
      framework_id   = NA_character_,
      framework_name = NA_character_
    )
  }
  if (!is.null(rdf)) register_graph_frameworks(rdf)
  .pub_guard$policy
}

#' Attach the graph's framework IRIs and names to the policy table. Any
#' framework in the graph with no invariants entry is a hard stop: an
#' unmapped framework is unknown terms, not safe terms.
register_graph_frameworks <- function(rdf) {
  if (isTRUE(.pub_guard$registered)) return(invisible(.pub_guard$policy))

  fws <- sparql_subjects(rdf, "a", "cybed:Framework") |>
    transmute(framework_id = s)
  nms <- sparql_pairs(rdf, "schema:name") |>
    transmute(framework_id = s, framework_name = o)
  fws <- fws |> left_join(nms, by = "framework_id")

  keys <- .pub_guard$policy$framework_slug
  slug <- vapply(fws$framework_id, match_framework_slug, character(1),
                 keys = keys, USE.NAMES = FALSE)
  if (anyNA(slug)) {
    stop("publication guard: graph frameworks with no invariants entry: ",
         paste(fws$framework_id[is.na(slug)], collapse = ", "))
  }
  fws$framework_slug <- slug

  .pub_guard$policy <- .pub_guard$policy |>
    select(-framework_id, -framework_name) |>
    left_join(fws |> select(framework_slug, framework_id, framework_name),
              by = "framework_slug")
  .pub_guard$registered <- TRUE
  invisible(.pub_guard$policy)
}

# IRIs are https://w3id.org/cybed/ontology#framework/<tail>; the tail is the
# invariants key plus a version suffix (csta-2017, cyberorg-k12-v1.0).
normalize_framework_value <- function(x) sub(".*framework/", "", as.character(x))

match_framework_slug <- function(value, keys) {
  if (is.na(value)) return(NA_character_)
  tbl <- .pub_guard$policy

  # Exact graph name or IRI first, then the invariants key, then the
  # versioned IRI tail.
  hit <- tbl$framework_slug[!is.na(tbl$framework_name) & tbl$framework_name == value]
  if (length(hit) == 1L) return(hit)
  hit <- tbl$framework_slug[!is.na(tbl$framework_id) & tbl$framework_id == value]
  if (length(hit) == 1L) return(hit)

  v <- normalize_framework_value(value)
  if (v %in% keys) return(v)
  cand <- keys[v == keys | startsWith(v, paste0(keys, "-"))]
  if (length(cand) >= 1L) return(cand[which.max(nchar(cand))])
  NA_character_
}

#' Map framework values (slug, IRI tail, IRI, or schema:name) to invariants
#' slugs. Stops on anything it cannot map.
resolve_framework_slug <- function(values) {
  publication_policy()
  keys <- .pub_guard$policy$framework_slug
  uniq <- unique(as.character(values))
  mapped <- vapply(uniq, match_framework_slug, character(1),
                   keys = keys, USE.NAMES = FALSE)
  if (anyNA(mapped)) {
    stop("publication guard: unrecognised framework value(s), refusing to ",
         "treat unknown as publishable: ",
         paste(unique(uniq[is.na(mapped)]), collapse = ", "))
  }
  mapped[match(as.character(values), uniq)]
}

framework_policy_of <- function(values) {
  slugs <- resolve_framework_slug(values)
  tbl <- .pub_guard$policy
  tbl$policy[match(slugs, tbl$framework_slug)]
}

#' Slugs whose statement text may be published.
text_publishable_frameworks <- function() {
  p <- publication_policy()
  p$framework_slug[unname(PUBLICATION_POLICIES[p$policy])]
}

#' Statement text publishable? Explicit allowlist, not a negated denylist: a
#' policy value is publishable only when PUBLICATION_POLICIES says so.
is_text_publishable <- function(values) {
  unname(PUBLICATION_POLICIES[framework_policy_of(values)])
}

check_guard_cols <- function(df, framework_col, text_cols) {
  missing <- setdiff(c(framework_col, text_cols), names(df))
  if (length(missing)) {
    stop("publication guard: column(s) not in data: ",
         paste(missing, collapse = ", "))
  }
}

# Character and factor columns are the ones that can carry text. Everything
# else (numeric, logical, list) cannot.
guard_text_bearing_candidates <- function(df) {
  names(df)[vapply(df, function(col) is.character(col) || is.factor(col),
                   logical(1))]
}

guard_col_has_text <- function(v) {
  v <- as.character(v)
  !is.na(v) & nzchar(trimws(v))
}

#' Blank (NA) the named text columns for rows belonging to a framework whose
#' statement text may not be published. Reports what it blanked, per framework.
drop_unpublishable_text <- function(df, framework_col, text_cols) {
  check_guard_cols(df, framework_col, text_cols)
  bad <- !is_text_publishable(df[[framework_col]])
  if (!any(bad)) {
    message("publication guard: nothing to blank, all rows are publishable.")
    return(df)
  }
  for (col in text_cols) df[[col]][bad] <- NA
  counts <- table(resolve_framework_slug(df[[framework_col]][bad]))
  for (slug in names(counts)) {
    message("publication guard: blanked ", counts[[slug]], " row(s) of ",
            paste(text_cols, collapse = ", "), " for ", slug,
            " (", framework_policy_of(slug), ").")
  }
  df
}

#' Hard gate, called immediately before every write into concordance/_data.
#'
#' Inspects EVERY character column of `x`. A column is exempt only when the
#' caller names it in `structure_cols` as a name or identifier column. Anything
#' else is treated as statement text, so a forgotten column stops the write
#' rather than slipping through.
#'
#' Framework attribution, one of two forms:
#'   framework_col     long tables: a column naming the framework each ROW
#'                     belongs to.
#'   framework_by_col  wide tables that carry one framework per COLUMN: a named
#'                     vector mapping column name to framework. Every
#'                     text-bearing column must appear in it.
#' A frame whose character columns are all structure needs neither.
assert_no_unpublishable_text <- function(x,
                                         framework_col    = NULL,
                                         framework_by_col = NULL,
                                         structure_cols   = character(0)) {
  if (!is.data.frame(x)) {
    stop("publication guard: assert_no_unpublishable_text() expects a data ",
         "frame, got ", paste(class(x), collapse = "/"), ".")
  }
  check_guard_cols(x, framework_col, structure_cols)
  if (!is.null(framework_by_col)) {
    if (is.null(names(framework_by_col)) || anyNA(names(framework_by_col)) ||
        !all(nzchar(names(framework_by_col)))) {
      stop("publication guard: framework_by_col must be a named vector ",
           "mapping column name to framework.")
    }
    check_guard_cols(x, NULL, names(framework_by_col))
  }

  text_cols <- setdiff(guard_text_bearing_candidates(x),
                       c(framework_col, structure_cols))

  if (!is.null(framework_by_col)) {
    undeclared <- setdiff(text_cols, names(framework_by_col))
    if (length(undeclared)) {
      stop("publication guard: character column(s) with no framework ",
           "attribution and not declared as structure: ",
           paste(undeclared, collapse = ", "),
           ". Declare each one in framework_by_col or in structure_cols; an ",
           "undeclared column is treated as statement text and refused.")
    }
  } else if (is.null(framework_col) && length(text_cols)) {
    stop("publication guard: character column(s) with no framework ",
         "attribution and not declared as structure: ",
         paste(text_cols, collapse = ", "),
         ". Pass framework_col or framework_by_col, or declare them in ",
         "structure_cols.")
  }

  if (!length(text_cols)) return(invisible(x))

  offences <- list()
  for (col in text_cols) {
    if (is.null(framework_by_col)) {
      publishable <- is_text_publishable(x[[framework_col]])
      slugs <- resolve_framework_slug(x[[framework_col]])
    } else {
      publishable <- rep(is_text_publishable(framework_by_col[[col]]), nrow(x))
      slugs <- rep(resolve_framework_slug(framework_by_col[[col]]), nrow(x))
    }
    offending <- !publishable & guard_col_has_text(x[[col]])
    if (any(offending)) {
      counts <- table(slugs[offending])
      offences[[col]] <- sprintf("%s: %s", col,
        paste(sprintf("%s (%d row(s), %s)", names(counts), as.integer(counts),
                      framework_policy_of(names(counts))),
              collapse = "; "))
    }
  }

  if (length(offences)) {
    stop("publication guard: unpublishable statement text present. ",
         paste(unlist(offences, use.names = FALSE), collapse = " | "),
         ". Refusing to write.")
  }
  invisible(x)
}
