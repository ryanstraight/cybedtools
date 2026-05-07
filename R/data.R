# R/data.R
#
# Roxygen documentation for shipped package data. Source script that
# produces these artifacts lives in data-raw/.

#' Eight-framework summary tibble
#'
#' One row per framework in the cybedtools corpus. Counts (`role_count`,
#' `element_count`, `elements_per_role`) are computed from the staged
#' combined N-Triples graph at package-build time via
#' `data-raw/build-framework-summary.R`. Display name, framework type
#' (workforce vs. pedagogy), and license are hand-curated because they
#' originate outside the JSON-LD graph (license terms come from each
#' framework's own materials; the workforce/pedagogy distinction is a
#' cybedtools-side classification).
#'
#' @format A tibble with 8 rows and 8 columns.
#' \describe{
#'   \item{framework_slug}{Character. Stable slug used as the URI tail
#'     (e.g., `"nice-v2"`, `"sfia-9"`).}
#'   \item{framework_name}{Character. Short display name suitable for
#'     tables and prose.}
#'   \item{framework_type}{Character. One of `"workforce"` or
#'     `"pedagogy"`.}
#'   \item{jurisdiction}{Character. One of `"US"`, `"EU"`, or `"global"`.}
#'   \item{role_count}{Integer. Distinct roles bound to the framework via
#'     `cybed:partOf` in the assembled graph.}
#'   \item{element_count}{Integer. Distinct role elements bound to the
#'     framework via `cybed:partOf`.}
#'   \item{elements_per_role}{Numeric. `element_count / role_count`,
#'     rounded to one decimal. Surfaces specification density across
#'     frameworks of different structural types.}
#'   \item{license}{Character. Distribution license as published by the
#'     framework owner.}
#' }
#'
#' @source Computed from the eight-framework combined graph produced by
#'   `scripts/025-export-ntriples.R`. See
#'   `data-raw/build-framework-summary.R`.
#' @examples
#' framework_summary
#' subset(framework_summary, framework_type == "workforce")
"framework_summary"
