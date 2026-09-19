# R/data.R
#
# Roxygen documentation for shipped package data. Source script that
# produces these artifacts lives in data-raw/.

#' Eleven-framework summary tibble
#'
#' One row per framework in the cybedtools corpus. All count columns are
#' computed from the staged combined N-Triples graph at package-build time
#' via `data-raw/build-framework-summary.R`. Display name, framework type
#' (workforce vs pedagogy), and license are hand-curated because they
#' originate outside the JSON-LD graph.
#'
#' Three frameworks were added in v0.3.0 by steward permission: CyQUAL
#' (Czech Republic, open data, attribution to CyQUAL and Masaryk
#' University), CCSSF (Canada, Government of Canada copyright, used with
#' written permission of the Canadian Centre for Cyber Security), and OTCCF
#' (Singapore, Cyber Security Agency of Singapore copyright, permission for
#' non-commercial academic and research use). The build script fails loudly
#' in both directions if the graph and the curated display table disagree
#' about which frameworks exist.
#'
#' Statement codes are unique only within a framework. NICE and CCSSF both
#' print codes in the T0516 shape, and they denote different statements.
#' Never join two frameworks on a bare statement code. Join on the full IRI,
#' or carry a framework column alongside the code.
#'
#' @section What the element counts mean:
#' `element_count_with_examples` counts every `cybed:RoleElement` bound to
#' the framework: parents, plus `cybed:Subpoint` children, plus
#' `cybed:Example` children. `element_count_strict` counts parents only, that
#' is with-examples less both the Subpoint and the Example populations.
#' Only DCWF, DigComp 2.2 and OTCCF have zero of both children, so strict
#' equals with-examples there.
#'
#' **Corrected 2026-08-14**: `element_count_strict` previously subtracted
#' only `example_count`, so any framework with nonzero Subpoints carried an
#' inflated "strict" value that silently included non-parent content
#' (NICE +4, SFIA +158, ECSF +16, CSTA +20, CSEC2017 +2). That is what
#' produced the NICE 2,115-vs-NIST's-2,111 discrepancy caught in the
#' Concordance manuscript audit. The README headline "density spread"
#' finding uses the with-examples count, which counts what each framework
#' puts in front of a teacher, trainee, or curriculum designer. The strict
#' count is the supplementary figure, reported in the
#' cross-framework-analysis vignette.
#'
#' Note that `docs/framework-invariants.yml` uses the word "strict" in a
#' different sense: its `total_elements_strict` is parents plus Subpoints
#' excluding Examples, whereas this tibble's `element_count_strict` is
#' parents only, so the two figures will not match for any framework with
#' Subpoints.
#'
#' @section Units, roles, and density:
#' `organizing_unit_count` counts every `cybed:OrganizingUnit`, which for
#' several frameworks mixes more than one kind of unit: NICE contributes 42
#' work roles plus 11 competency areas, CyQUAL 102 work roles plus 59
#' competencies, OTCCF 15 job roles plus 30 Technical Skills and
#' Competencies plus 16 Critical Core Skills. A density taken over that
#' mixed denominator is not like-for-like against a framework whose units
#' are all roles, such as DCWF's 74. The `role_count` and
#' `elements_per_role_*` columns added in v0.3.0 give the role-only cut.
#' The `elements_per_organizing_unit_*` columns keep the definition they
#' have always had, because they are published figures.
#'
#' The `framework_type` column denotes content focus (workforce
#' competencies vs educational standards), not the structural distinction
#' that drives `cybed:Role` assertion. SFIA carries `framework_type ==
#' "workforce"` because it specifies workforce skills, but its parent units
#' assert `cybed:OrganizingUnit` only (not `cybed:Role`) because SFIA
#' enumerates skills rather than work roles, so its `role_count` is `NA`.
#' For structural questions, query `cybed:Role` and `cybed:OrganizingUnit`
#' directly.
#'
#' @format A tibble with 11 rows and 16 columns.
#' \describe{
#'   \item{framework_slug}{Character. Stable slug used as the URI tail
#'     (e.g., `"nice-v2"`, `"sfia-9"`, `"otccf-v1.1"`). Unique.}
#'   \item{framework_name}{Character. Short curated display name suitable
#'     for tables and prose. Not the graph's `schema:name` literal, which
#'     carries the full published title.}
#'   \item{framework_type}{Character. Content-focus classification, one
#'     of `"workforce"` or `"pedagogy"`. Independent of the structural
#'     `cybed:Role` vs `cybed:OrganizingUnit` distinction.}
#'   \item{jurisdiction}{Character. One of `"US"`, `"EU"`, `"CZ"`, `"CA"`,
#'     `"SG"`, or `"global"`.}
#'   \item{organizing_unit_count}{Integer. Distinct subjects typed
#'     `cybed:OrganizingUnit` and bound to the framework via `cybed:partOf`.
#'     A mixed denominator where a framework publishes more than one kind of
#'     unit, as described above.}
#'   \item{role_count}{Integer. Distinct subjects typed `cybed:Role` and
#'     bound to the framework via `cybed:partOf`. A subset of
#'     `organizing_unit_count`. `NA` for the five frameworks that assert no
#'     roles at all (SFIA, Cyber.org K-12, CSTA, CSEC2017, DigComp 2.2).
#'     `NA` rather than zero, because "this framework does not use the role
#'     construct" is a different statement from "this framework has zero
#'     roles".}
#'   \item{element_count_strict}{Integer. Distinct parent elements only.
#'     Equals `element_count_with_examples` less `subpoint_count` less
#'     `example_count`. Use this column when the comparison must exclude
#'     both enumeration splitting and pedagogical scaffolding.}
#'   \item{subpoint_count}{Integer. Distinct `cybed:Subpoint` instances:
#'     enumeration-list splits parsed out of a parent's text at assembly
#'     time, plus, for CCSSF only, sub-bullets the source itself prints
#'     beneath a parent bullet. Zero where the parser is disabled (OTCCF)
#'     or finds nothing.}
#'   \item{example_count}{Integer. Distinct `cybed:Example` instances
#'     (Clarification-statement scaffolding). Non-zero for Cyber.org K-12
#'     and CSTA only.}
#'   \item{element_count_with_examples}{Integer. Distinct elements typed
#'     `cybed:RoleElement` and bound to the framework: parents plus
#'     Subpoints plus Examples.}
#'   \item{unit_relation_count}{Integer. Distinct `cybed:UnitRelation`
#'     nodes bound to the framework: qualified unit-to-unit statements, each
#'     carrying its published proficiency level. Nonzero for OTCCF only
#'     (310: 190 role-to-TSC plus 120 role-to-Critical-Core-Skill), zero
#'     everywhere else, since no other framework in the corpus publishes a
#'     skills map of this shape.}
#'   \item{elements_per_organizing_unit_strict}{Numeric.
#'     `element_count_strict / organizing_unit_count`, rounded to one
#'     decimal. The supplementary density figure, reported in the
#'     cross-framework-analysis vignette.}
#'   \item{elements_per_organizing_unit_with_examples}{Numeric.
#'     `element_count_with_examples / organizing_unit_count`, rounded to one
#'     decimal. The headline density figure used in the README. The vignette
#'     shows it alongside the strict column to make visible how Examples
#'     inflate Cyber.org K-12 and CSTA's apparent specification density.}
#'   \item{elements_per_role_strict}{Numeric. The count of DISTINCT parent
#'     elements reachable by `cybed:hasElement` from a role-typed organizing
#'     unit, divided by `role_count`, rounded to one decimal. `NA` where
#'     `role_count` is `NA`. Distinct, not summed per role, because NICE,
#'     CyQUAL and DCWF share statements across roles, so an edge count would
#'     measure reuse rather than coverage and would not be comparable with
#'     the per-organizing-unit columns.}
#'   \item{elements_per_role_with_examples}{Numeric. As above but counting
#'     every element type, so parents plus Subpoints plus Examples reachable
#'     from role-typed units, divided by `role_count`. `NA` where
#'     `role_count` is `NA`.}
#'   \item{license}{Character. Distribution license as published by the
#'     framework owner.}
#' }
#'
#' @source Computed from the eleven-framework combined graph produced by
#'   `scripts/025-export-ntriples.R`. See
#'   `data-raw/build-framework-summary.R`.
#' @examples
#' framework_summary
#' subset(framework_summary, framework_type == "workforce")
#' subset(framework_summary, !is.na(role_count))
"framework_summary"
