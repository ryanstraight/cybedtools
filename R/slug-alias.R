# R/slug-alias.R
#
# Two framework-slug vocabularies exist in this package (documented in full
# on cybed_fetch() and framework_summary()):
#
#   - versioned slugs, e.g. "nice-v2", "otccf-v1.1" -- carried by
#     framework_summary()$framework_slug and framework_licenses()$slug, and
#     minted into every framework node's IRI in the graph.
#   - release (short) slugs, e.g. "nice", "otccf" -- the names of the public
#     per-framework release files, assigned by docs/data-release.yml and
#     recorded in the release manifest's `slug` field (with the versioned
#     form alongside it as `license_slug`).
#
# cybed_fetch() already resolves either form because it reads the release
# manifest at call time. Every OTHER public function that takes a framework
# slug (cybed_license(), framework_similarity()) has no manifest to consult,
# so this file derives the same short-slug rule
# `scripts/030-export-release.R`'s `release_license_row()` applies (strip a
# trailing version suffix; a framework that is its own edition, not a
# version of a shorter-named sibling, keeps its full slug) from the shipped
# `framework_summary`/`framework_licenses` tibbles alone, with no network or
# build-time input. This is the ONE place that map is built; both
# `cybed_license()` and `framework_similarity()` call it.

#' Alias map from release (short) slug to canonical versioned slug
#'
#' @return A named character vector: `names()` are release/short slugs,
#'   values are the canonical versioned slugs.
#' @noRd
framework_slug_alias_map <- function() {
  versioned <- cybedtools::framework_summary$framework_slug
  short <- sub("-v?[0-9][0-9.]*$", "", versioned)

  # csta-2026 is a framework in its own right, not an edition of csta --
  # csta-2017 already claims the "csta" short slug (mirrors the `reserved`
  # handling in scripts/030-export-release.R's release_license_row()).
  short[versioned == "csta-2026"] <- "csta-2026"

  stats::setNames(versioned, short)
}

#' Resolve a framework slug (either vocabulary) against a set of known
#' (already-versioned) slugs
#'
#' @param slug Character scalar to resolve.
#' @param known Character vector of valid versioned slugs to resolve against.
#' @param arg Character scalar, the argument name to use in error messages.
#' @return The canonical versioned slug, if resolvable.
#' @noRd
resolve_framework_slug <- function(slug, known, arg = "slug") {
  if (slug %in% known) {
    return(slug)
  }

  alias_map <- framework_slug_alias_map()
  if (slug %in% names(alias_map) && unname(alias_map[[slug]]) %in% known) {
    return(unname(alias_map[[slug]]))
  }

  rlang::abort(
    c(
      "Unknown framework slug.",
      "x" = paste0("`", arg, "`: '", slug, "'."),
      "i" = paste0("Known slugs: ", paste(sort(known), collapse = ", "), ".")
    ),
    class = "cybedtools_framework_not_found",
    framework_slug = slug
  )
}
