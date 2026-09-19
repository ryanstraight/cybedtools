# R/licenses.R
#
# Accessor for the shipped framework_licenses tibble, the single owner of
# licence facts in the package. The tibble is built by
# data-raw/build-framework-licenses.R and documented in R/data.R.
#
# The shipped tibble is reached through the self-qualified
# `cybedtools::framework_licenses` rather than as a bare symbol. A bare
# symbol would be an unbound global to R CMD check, and R/zzz.R deliberately
# keeps no utils::globalVariables() allow-list so that every such NOTE stays
# a real finding. This is the one-line cost of that policy.

license_table <- function() {
  cybedtools::framework_licenses
}

#' Look up the licence terms for the package or one framework
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' Returns rows of [framework_licenses], the package's single owner of
#' licence facts. Called with no argument it returns the whole tibble: one
#' row for the package's own code and one row per framework. Called with a
#' slug it returns that one row.
#'
#' The `license_short` column is the short label that
#' [framework_summary]`$license` is derived from. The `license` column holds
#' what the source's own document or terms page says, quoted and attributed
#' to the document it was read from. The `attribution` column holds the
#' wording to reproduce when the framework's content is used: the steward's
#' own wording verbatim where one is prescribed, a minimal attribution
#' composed by the package where the licence requires credit but the steward
#' prescribes no wording, and `NA` where neither applies. The `license` cell
#' says which of the two a given row carries.
#'
#' @param slug Character scalar, or `NULL`. Either `"cybedtools"` for the
#'   package's own code, or a framework slug as carried by
#'   [framework_summary]`$framework_slug` (for example `"nice-v2"`,
#'   `"otccf-v1.1"`). `NULL`, the default, returns every row.
#' @return A tibble. One row per licence layer when `slug` is `NULL`, and a
#'   single-row tibble otherwise.
#' @family licensing
#' @export
#' @examples
#' cybed_license()
#' cybed_license("otccf-v1.1")
#' cybed_license("cybedtools")$license_short
#'
#' # Which frameworks may not be redistributed publicly at all?
#' lic <- cybed_license()
#' lic$slug[lic$public_redistribution == "local_only"]
cybed_license <- function(slug = NULL) {
  licenses <- license_table()

  if (is.null(slug)) {
    return(licenses)
  }

  if (!is.character(slug) || length(slug) != 1L || is.na(slug)) {
    rlang::abort(
      c(
        "`slug` must be a single non-missing character string, or NULL.",
        "x" = paste0("Received: ", class(slug)[1], " of length ", length(slug), "."),
        "i" = "Call `cybed_license()` with no argument for every row."
      ),
      class = "cybedtools_scalar_input"
    )
  }

  row <- licenses[licenses$slug == slug, , drop = FALSE]

  if (nrow(row) == 0L) {
    rlang::abort(
      c(
        "No licence row for that slug.",
        "x" = paste0("Slug: '", slug, "'."),
        "i" = paste0("Known slugs: ",
                     paste(licenses$slug, collapse = ", "), "."),
        "i" = "Call `cybed_license()` with no argument for every row."
      ),
      class = "cybedtools_framework_not_found",
      framework_slug = slug
    )
  }

  row
}
