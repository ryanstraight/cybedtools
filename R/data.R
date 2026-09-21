# R/data.R
#
# Roxygen documentation for shipped package data. Source script that
# produces these artifacts lives in data-raw/.

#' Fourteen-framework summary tibble
#'
#' One row per framework in the cybedtools corpus. All count columns are
#' computed from the staged combined N-Triples graph at package-build time
#' via `data-raw/build-framework-summary.R`. Display name, framework type
#' (workforce vs pedagogy), and license are hand-curated because they
#' originate outside the JSON-LD graph.
#'
#' Three frameworks were added in v0.3.0 on steward terms: CyQUAL
#' (Czech Republic, open data, attribution to CyQUAL and Masaryk
#' University), CCSSF (Canada, Government of Canada copyright, used with
#' permission of the Canadian Centre for Cyber Security), and OTCCF
#' (Singapore, Cyber Security Agency of Singapore copyright, permission for
#' non-commercial academic and research use). The build script fails loudly
#' in both directions if the graph and the curated display table disagree
#' about which frameworks exist.
#'
#' The 2026 CSTA PK-12 Computer Science Standards (`csta-2026`) were added
#' after v0.3.0 as a framework of their own alongside the 2017 edition
#' (`csta-2017`), whose row is unchanged. Its 53 organizing units are level x
#' concept groups for the foundational tier and tier x specialty area groups
#' for the specialty tier. Its Examples are CSTA's published implementation
#' examples.
#'
#' The Saudi Cybersecurity Workforce Framework (`scywf-1.5`, SCyWF - 1.5 :
#' 2026) was added after v0.3.0 by written permission of the National
#' Cybersecurity Authority (NCA), which requires its content to be carried
#' verbatim. Its 81 organizing units are 40 job roles, 24 competency areas,
#' 12 specialty areas and 5 categories. Only the job roles assert
#' `cybed:Role`. The links from a specialty area to its category and from a
#' role to its specialty area are cybedtools-derived, not NCA content.
#'
#' The Cyber Security Body of Knowledge (`cybok-v1.1.0`, CyBOK v1.1.0, July
#' 2021) was added after v0.3.0 under the Open Government Licence v3.0. Its
#' organizing units are its Knowledge Areas, which assert no `cybed:Role`.
#' Its parent elements are the Topics of each KA's Knowledge Tree, and the
#' Indicative Material the trees draw under each Topic is carried as
#' `cybed:Subpoint`. Those Subpoints are source-drawn, not parser output.
#'
#' Statement codes are unique only within a framework. NICE, CCSSF and
#' SCyWF all print codes in the T0516 shape, and they denote different
#' statements. SCyWF shares 296 codes with NICE v2.2.0 and prints different
#' text under every one of them.
#' Never join two frameworks on a bare statement code. Join on the full IRI,
#' or carry a framework column alongside the code.
#'
#' @section What the element counts mean:
#' `element_count_with_examples` counts every `cybed:RoleElement` bound to
#' the framework: parents, plus `cybed:Subpoint` children, plus
#' `cybed:Example` children. `element_count_strict` counts parents only, that
#' is with-examples less both the Subpoint and the Example populations.
#' OTCCF, csta-2026, DigComp 3.0 and SCyWF have zero Subpoints (parser
#' disabled for all four on fidelity grounds. See
#' docs/framework-invariants.yml). CyBOK runs with the parser disabled too,
#' and its Subpoints are the Indicative Material its Knowledge Trees draw. Only OTCCF and SCyWF have zero of both
#' children, so strict equals with-examples there. DigComp 3.0 still has a nonzero `example_count` with the parser
#' off: its Learning Outcomes attach as `cybed:Example` children of each
#' Competence unit, so strict is less than with-examples there.
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
#' The related count in `docs/framework-invariants.yml`,
#' `total_elements_with_subpoints`, is parents plus Subpoints excluding
#' Examples. This tibble's `element_count_strict` is parents only.
#'
#' @section Units, roles, and density:
#' `organizing_unit_count` counts every `cybed:OrganizingUnit`, which for
#' several frameworks mixes more than one kind of unit: NICE contributes 42
#' work roles plus 11 competency areas, CyQUAL 102 work roles plus 59
#' competencies, OTCCF 15 job roles plus 30 Technical Skills and
#' Competencies plus 16 Critical Core Skills, SCyWF 40 job roles plus 24
#' competency areas, 12 specialty areas and 5 categories. A density taken over that
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
#' @format A tibble with 14 rows and 16 columns.
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
#'     `"SG"`, `"SA"`, `"UK"`, or `"global"`.}
#'   \item{organizing_unit_count}{Integer. Distinct subjects typed
#'     `cybed:OrganizingUnit` and bound to the framework via `cybed:partOf`.
#'     A mixed denominator where a framework publishes more than one kind of
#'     unit, as described above.}
#'   \item{role_count}{Integer. Distinct subjects typed `cybed:Role` and
#'     bound to the framework via `cybed:partOf`. A subset of
#'     `organizing_unit_count`. `NA` for the seven frameworks that assert no
#'     roles at all (SFIA, Cyber.org K-12, CSTA 2017, CSTA 2026, CSEC2017,
#'     DigComp 3.0, CyBOK).
#'     `NA` rather than zero, because "this framework does not use the role
#'     construct" is a different statement from "this framework has zero
#'     roles".}
#'   \item{element_count_strict}{Integer. Distinct parent elements only.
#'     Equals `element_count_with_examples` less `subpoint_count` less
#'     `example_count`. Use this column when the comparison must exclude
#'     both enumeration splitting and pedagogical scaffolding.}
#'   \item{subpoint_count}{Integer. Distinct `cybed:Subpoint` instances:
#'     enumeration-list splits parsed out of a parent's text at assembly
#'     time, plus sub-points the source itself prints or draws beneath a
#'     parent: CCSSF's sub-bullets and CyBOK's Indicative Material. Zero where
#'     the parser is disabled and the source has none (OTCCF, csta-2026,
#'     DigComp 3.0, SCyWF) or where the parser finds nothing.}
#'   \item{example_count}{Integer. Distinct `cybed:Example` instances:
#'     Clarification-statement scaffolding for Cyber.org K-12 and CSTA 2017,
#'     and published implementation examples for CSTA 2026. Zero everywhere
#'     else.}
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
#'     inflate the apparent specification density of Cyber.org K-12 and both
#'     CSTA editions.}
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
#'   \item{license}{Character. Short licence label, **derived**: taken by
#'     slug from [framework_licenses]`$license_short` when this tibble is
#'     built, never hand-typed here. [framework_licenses] owns the detail,
#'     including what the source's own document says, the prescribed
#'     attribution wording, the public-redistribution class, the terms URL,
#'     and the date the terms were last read. Use [cybed_license()] to reach
#'     it. Do not treat this column as a statement of terms; it is a label.}
#' }
#'
#' @source Computed from the fourteen-framework combined graph produced by
#'   `scripts/025-export-ntriples.R`. See
#'   `data-raw/build-framework-summary.R`.
#' @examples
#' framework_summary
#' subset(framework_summary, framework_type == "workforce")
#' subset(framework_summary, !is.na(role_count))
"framework_summary"

#' Licence facts for the package code and every framework
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' The single owner of licence facts in cybedtools. One row for the
#' package's own code (MIT) and one row per framework, built by
#' `data-raw/build-framework-licenses.R` from each source's own document,
#' licence file, or published terms page. [framework_summary]`$license` is
#' derived from this tibble's `license_short` column, so the short label and
#' the detail can never disagree. Reach a single row with [cybed_license()].
#'
#' Nothing here is legal advice. The `license` column records what a source
#' says; deciding what that permits in your situation is your call, and for
#' several frameworks the honest answer is that the source says nothing and
#' the position is inferred.
#'
#' @section What the redistribution classes mean:
#' `public_redistribution` is the package's own operating rule for what it
#' will publish from a framework, and it agrees by construction with
#' `docs/framework-invariants.yml`, where a framework carrying no
#' `public_redistribution` key means `"unrestricted"`.
#' \describe{
#'   \item{`"unrestricted"`}{Structure and statement text may both be
#'     published, subject to the source's own attribution and
#'     non-commercial or share-alike terms where it has them. The class
#'     speaks to redistribution, not to commercial reuse: CSTA and
#'     Cyber.org K-12 are `"unrestricted"` here and still carry NC and
#'     NC-SA obligations recorded in `license`.}
#'   \item{`"full_with_attribution"`}{As above, with attribution the
#'     steward asked for explicitly.}
#'   \item{`"structure_only"`}{Titles, categories, levels, codes, counts
#'     and mappings may be published. Statement text may not.}
#'   \item{`"local_only"`}{Nothing beyond aggregate counts is published.
#'     Analysis happens on the user's own machine, where no distribution
#'     occurs.}
#' }
#'
#' @format A tibble with 15 rows and 10 columns.
#' \describe{
#'   \item{layer}{Character. `"code"` for the package's own code, or
#'     `"framework"` for a framework's source content. Exactly one `"code"`
#'     row exists.}
#'   \item{slug}{Character. `"cybedtools"` for the code row; otherwise the
#'     framework slug, equal to [framework_summary]`$framework_slug`.
#'     Unique.}
#'   \item{framework_name}{Character. Short display name, matching
#'     [framework_summary]`$framework_name` for framework rows.}
#'   \item{license_short}{Character. A short honest label, under 40
#'     characters. The value [framework_summary]`$license` carries.}
#'   \item{license}{Character. What the source's own document, licence file,
#'     or published terms page says, verbatim or as a faithful close
#'     quotation, naming the document or page it was read from. Where a
#'     source states nothing, the row says so rather than filling the gap.}
#'   \item{attribution}{Character. The attribution string to use, verbatim
#'     where the steward prescribed one. `NA` where none is prescribed; the
#'     package does not invent citation wording and attribute it to a
#'     steward. This is the only column that may be `NA`.}
#'   \item{public_redistribution}{Character. One of `"unrestricted"`,
#'     `"full_with_attribution"`, `"structure_only"`, or `"local_only"`, as
#'     described above.}
#'   \item{terms_url}{Character. A public URL for the terms or the source
#'     document. Always `https`. Where a source publishes no
#'     framework-specific terms page, this is the publisher's own page for
#'     the document.}
#'   \item{granted}{Logical. `TRUE` only where a steward gave cybedtools
#'     specific written permission. An open licence anyone may rely on is
#'     not a grant to cybedtools and is `FALSE`.}
#'   \item{verified}{Date. When the terms were last read from the source.}
#' }
#'
#' @source Each framework's own published document or terms page, cited in
#'   the `license` and `terms_url` columns. See
#'   `data-raw/build-framework-licenses.R`, `LICENSING.md`, and
#'   `docs/framework-data-sources.md`.
#' @family licensing
#' @examples
#' framework_licenses
#' subset(framework_licenses, granted)
#' subset(framework_licenses, public_redistribution != "unrestricted",
#'        select = c("slug", "license_short", "public_redistribution"))
"framework_licenses"
