# R/data.R
#
# Roxygen documentation for shipped package data. Source script that
# produces these artifacts lives in data-raw/.

#' Eight-framework summary tibble
#'
#' One row per framework in the cybedtools corpus. Counts
#' (`organizing_unit_count`, `element_count_strict`,
#' `element_count_with_examples`, `example_count`,
#' `elements_per_organizing_unit_strict`,
#' `elements_per_organizing_unit_with_examples`) are computed from the
#' staged combined N-Triples graph at package-build time via
#' `data-raw/build-framework-summary.R`. Display name, framework type
#' (workforce vs pedagogy), and license are hand-curated because they
#' originate outside the JSON-LD graph.
#'
#' Two element-count columns are surfaced: `element_count_strict` counts
#' parents plus parsed Subpoints (framework-as-specified content);
#' `element_count_with_examples` additionally counts the Cyber.org K-12
#' and CSTA Clarification-statement Examples (pedagogical scaffolding,
#' not enumerable sub-standards). For frameworks that emit no Examples
#' (NICE, DCWF, ECSF, SFIA, CSEC2017, DigComp 2.2) the two columns are
#' equal. The README headline "density spread" finding uses the strict
#' count for cross-framework parity; the cross-framework-analysis vignette
#' shows both columns side-by-side and discusses the encoding heterogeneity
#' that drives the difference.
#'
#' The `framework_type` column denotes content focus (workforce
#' competencies vs educational standards), not the structural distinction
#' that drives `cybed:Role` assertion. SFIA carries `framework_type ==
#' "workforce"` because it specifies workforce skills, but its parent
#' units assert `cybed:OrganizingUnit` only (not `cybed:Role`) because
#' SFIA enumerates skills rather than work roles. For structural
#' questions, query `cybed:Role` and `cybed:OrganizingUnit` directly.
#'
#' @format A tibble with 8 rows and 11 columns.
#' \describe{
#'   \item{framework_slug}{Character. Stable slug used as the URI tail
#'     (e.g., `"nice-v2"`, `"sfia-9"`).}
#'   \item{framework_name}{Character. Short display name suitable for
#'     tables and prose.}
#'   \item{framework_type}{Character. Content-focus classification, one
#'     of `"workforce"` or `"pedagogy"`. Independent of the structural
#'     `cybed:Role` vs `cybed:OrganizingUnit` distinction.}
#'   \item{jurisdiction}{Character. One of `"US"`, `"EU"`, or `"global"`.}
#'   \item{organizing_unit_count}{Integer. Distinct top-level enumerated
#'     units bound to the framework via `cybed:partOf`. For NICE / DCWF /
#'     ECSF this is work roles or work profiles; for SFIA, skills; for
#'     Cyber.org K-12, grade-band concepts; for CSTA, level-concept
#'     buckets; for CSEC2017, Knowledge Areas; for DigComp 2.2, competence
#'     areas. Cross-framework comparison via `cybed:OrganizingUnit`.}
#'   \item{element_count_strict}{Integer. Distinct framework-as-specified
#'     elements (parents plus `cybed:Subpoint` children). Excludes
#'     `cybed:Example` instances. Use this column for headline density
#'     comparisons across frameworks.}
#'   \item{element_count_with_examples}{Integer. Distinct elements
#'     including `cybed:Example` instances (Cyber.org K-12 and CSTA
#'     Clarification-statement scaffolding). For frameworks without
#'     Examples this equals `element_count_strict`.}
#'   \item{example_count}{Integer. Distinct `cybed:Example` instances.
#'     Non-zero for Cyber.org K-12 and CSTA only; zero for the other six
#'     frameworks.}
#'   \item{elements_per_organizing_unit_strict}{Numeric.
#'     `element_count_strict / organizing_unit_count`, rounded to one
#'     decimal. The headline density figure used in the README.}
#'   \item{elements_per_organizing_unit_with_examples}{Numeric.
#'     `element_count_with_examples / organizing_unit_count`, rounded
#'     to one decimal. Used in the cross-framework-analysis vignette to
#'     show how Examples inflate Cyber.org K-12 and CSTA's apparent
#'     specification density.}
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
