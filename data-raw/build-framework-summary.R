# data-raw/build-framework-summary.R
#
# Builds data/framework_summary.rda from the staged combined N-Triples graph.
#
# Run when framework data revisions land (NICE v2.x bumps, ECSF revisions,
# license changes). End-users never run this script. They consume the
# resulting tibble via cybedtools::framework_summary.
#
# Requires:
#   - A staged combined N-Triples graph at
#     data/processed/ntriples/_combined.nt produced by
#     scripts/025-export-ntriples.R against fully staged framework source
#     files. The data/ subtree is gitignored; the .rda artifact below ships
#     with the package.

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
})

# Use the in-repo version of cybedtools when running from a working tree.
# Falls back to the installed version otherwise.
if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  pkgload::load_all(quiet = TRUE)
} else {
  library(cybedtools)
}

# Regression guard, part 1: keep the currently shipped object so the rebuilt
# one can be diffed against it before anything is overwritten. See the
# comparison block at the bottom of this script.
previous_summary <- NULL
if (file.exists("data/framework_summary.rda")) {
  .prev_env <- new.env()
  load("data/framework_summary.rda", envir = .prev_env)
  previous_summary <- .prev_env$framework_summary
}

rdf <- load_combined_ntriples_graph()

meta <- framework_metadata(rdf)

# Cross-framework parent count: every framework's top-level enumerated unit
# regardless of whether it is a workforce role. Replaces the role-only count
# used in v0.1.x, which under-counted the five non-workforce frameworks
# (SFIA, Cyber.org K-12, CSTA, CSEC2017, DigComp 2.2) where parents are not
# typed cybed:Role under v0.2.0.
#
# NOTE (v0.3.0): this is a MIXED denominator for frameworks that publish
# more than one kind of organizing unit. NICE contributes 42 work roles plus
# 11 competency areas; CyQUAL 102 work roles plus 59 competencies; OTCCF 15
# job roles plus 30 Technical Skills and Competencies plus 16 Critical Core
# Skills. The elements_per_organizing_unit_* columns are therefore not
# like-for-like against a framework whose units are all roles (DCWF 74).
# The elements_per_role_* columns added in v0.3.0 give the role-only cut.
units <- organizing_unit_framework_bindings(rdf) |>
  count(framework, name = "organizing_unit_count")

# Role count: organizing units that additionally assert cybed:Role. Absent
# for the five frameworks that assert no roles at all (SFIA, Cyber.org K-12,
# CSTA, CSEC2017, DigComp 2.2); those become NA rather than 0 below, because
# "this framework does not use the role construct" is a different statement
# from "this framework has zero roles".
role_bindings <- role_framework_bindings(rdf) |>
  distinct(role, framework)

roles <- role_bindings |>
  count(framework, name = "role_count")

# Total element count includes parents, Subpoints, and Examples.
elements_with <- element_framework_bindings(rdf) |>
  count(framework, name = "element_count_with_examples")

# Example count: cybed:Example instances (Cyber.org K-12 and CSTA
# Clarification-statement scaffolding). Zero for the frameworks that do
# not encode pedagogical examples.
examples <- example_framework_bindings(rdf) |>
  count(framework, name = "example_count")

# Subpoint count: cybed:Subpoint instances, the uniform parser's
# enumeration-list splits ("such as X, Y, and Z" / "including A and B")
# applied at JSON-LD assembly time, plus (CCSSF only) source-printed
# sub-bullets. Distinct from Example (Cyber.org K-12 / CSTA
# Clarification-statement scaffolding specifically). Both are non-parent
# content and are both excluded from the strict count -- see the 2026-08-14
# audit finding: element_count_strict previously subtracted only
# example_count, silently leaving Subpoint-derived elements (NICE +4,
# SFIA +158, ECSF +16, CSTA +20, CSEC2017 +2) inside a column whose name
# promises no tool augmentation at all.
subpoints <- subpoint_framework_bindings(rdf) |>
  dplyr::count(framework, name = "subpoint_count")

# cybed:UnitRelation nodes per framework. These are qualified unit-to-unit
# statements (OTCCF's role-to-TSC and role-to-Critical-Core-Skill maps, each
# statement carrying its published proficiency level). They are typed neither
# cybed:OrganizingUnit nor cybed:RoleElement, so they touch no other column
# here. Zero for every framework that publishes no such map.
framework_uris <- sparql_subjects(rdf, "a", "cybed:Framework")
part_of_pairs  <- sparql_pairs(rdf, "cybed:partOf")

unit_relations <- sparql_subjects(rdf, "a", "cybed:UnitRelation") |>
  dplyr::transmute(relation = s) |>
  dplyr::inner_join(dplyr::rename(part_of_pairs, framework = o),
                    by = c("relation" = "s")) |>
  dplyr::semi_join(dplyr::rename(framework_uris, framework = s),
                   by = "framework") |>
  dplyr::distinct(relation, framework) |>
  dplyr::count(framework, name = "unit_relation_count")

# Role-only element density (added v0.3.0).
#
# Numerator: DISTINCT elements reachable by cybed:hasElement from a
# role-typed organizing unit. Distinct, not summed per role, because NICE,
# CyQUAL and DCWF share statements across roles -- NICE's 5,424 role-element
# edges resolve to 1,877 distinct statements. Counting edges would measure
# how heavily statements are reused, not how much distinct content the role
# population covers, and would not be comparable with the
# elements_per_organizing_unit_* columns, whose numerator is also a distinct
# element count.
#
# Denominator: role_count. Frameworks with no roles get NA.
role_elements <- role_element_bindings(rdf) |>
  dplyr::inner_join(role_bindings, by = "role")

subpoint_uris <- subpoint_framework_bindings(rdf) |> dplyr::pull(subpoint)
example_uris  <- example_framework_bindings(rdf)  |> dplyr::pull(example)

role_element_counts <- role_elements |>
  dplyr::group_by(framework) |>
  dplyr::summarise(
    role_elements_with_examples = dplyr::n_distinct(element),
    role_elements_strict        = dplyr::n_distinct(
      element[!element %in% subpoint_uris & !element %in% example_uris]
    ),
    role_element_edges          = dplyr::n(),
    .groups = "drop"
  )

# Display + classification metadata not present in the JSON-LD. The
# workforce/pedagogy content classification, display name, and ordering
# originate outside the JSON-LD graph and rarely change. Slug-keyed for
# stability across revisions. The framework_type column denotes content
# focus (workforce competencies vs educational standards), not the
# structural distinction that drives cybed:Role assertion (NICE / DCWF /
# ECSF / CyQUAL / CCSSF / OTCCF carry cybed:Role; SFIA carries
# cybed:OrganizingUnit only despite being a workforce-content framework,
# because it enumerates skills rather than work roles). For structural
# questions, query cybed:Role and cybed:OrganizingUnit directly, or read
# the role_count column.
#
# display_name is hand-curated here, NOT read from the graph's schema:name
# literal: the graph carries the full published title (e.g. "Cyber.org K-12
# Learning Standards v1.0"), which is too long for a table column. New rows
# follow the existing short-name convention.
#
# The `license` column is NOT in this table any more. As of v0.3.1 it is
# DERIVED from framework_licenses$license_short, joined by slug below, so
# that licence facts have one owner. The hand-typed labels here had gone
# stale (SFIA read "SFIA Use Policy" when SFIA requires a licence for all
# use; NICE read as public domain alone when NIST also grants a worldwide
# royalty-free right). Edit data-raw/build-framework-licenses.R instead.
display <- tibble::tribble(
  ~framework,                                                    ~display_order, ~display_name,             ~framework_type,
  "https://w3id.org/cybed/ontology#framework/nice-v2",           1L,             "NICE v2.2.0",             "workforce",
  "https://w3id.org/cybed/ontology#framework/dcwf-v5.1",         2L,             "DCWF v5.1",               "workforce",
  "https://w3id.org/cybed/ontology#framework/ecsf-v1",           3L,             "ECSF v1",                 "workforce",
  "https://w3id.org/cybed/ontology#framework/sfia-9",            4L,             "SFIA 9",                  "workforce",
  "https://w3id.org/cybed/ontology#framework/cyberorg-k12-v1.0", 5L,             "Cyber.org K-12 v1.0",     "pedagogy",
  "https://w3id.org/cybed/ontology#framework/csta-2017",         6L,             "CSTA K-12 CS (Rev 2017)", "pedagogy",
  "https://w3id.org/cybed/ontology#framework/csec2017-v1",       7L,             "ACM/IEEE CSEC2017",       "pedagogy",
  "https://w3id.org/cybed/ontology#framework/digcomp-3.0",       8L,             "DigComp 3.0",             "pedagogy",
  "https://w3id.org/cybed/ontology#framework/cyqual-v1.2.0",     9L,             "CyQUAL 1.2.0",            "workforce",
  "https://w3id.org/cybed/ontology#framework/ccssf-2022",        10L,            "CCSSF 2022",              "workforce",
  "https://w3id.org/cybed/ontology#framework/otccf-v1.1",        11L,            "OTCCF v1.1",              "workforce",
  "https://w3id.org/cybed/ontology#framework/csta-2026",         12L,            "CSTA PK-12 CS (2026)",    "pedagogy",
  "https://w3id.org/cybed/ontology#framework/scywf-1.5",         13L,            "SCyWF 1.5",               "workforce",
  "https://w3id.org/cybed/ontology#framework/cybok-v1.1.0",      14L,            "CyBOK v1.1.0",            "pedagogy"
)

# Licence labels, derived. framework_licenses is the single owner of licence
# facts; this build reads only its short label. Fail loudly if a framework
# has no licence row rather than shipping an NA licence.
if (!exists("framework_licenses")) {
  stop("framework_licenses is not available. Run ",
       "data-raw/build-framework-licenses.R first, then reload the package.",
       call. = FALSE)
}

license_lookup <- framework_licenses[framework_licenses$layer == "framework", ]
display$license <- license_lookup$license_short[
  match(sub("^.*/", "", display$framework), license_lookup$slug)
]

if (any(is.na(display$license))) {
  stop(
    "No framework_licenses row for framework(s): ",
    paste(sub("^.*/", "", display$framework[is.na(display$license)]),
          collapse = ", "),
    ". Add a row in data-raw/build-framework-licenses.R and rebuild it.",
    call. = FALSE
  )
}

# Fail loudly in BOTH directions before any join can hide the problem.
#
# The v0.2.0 build inner_joined the computed counts against this display
# table and then asserted nrow == 8. A framework present in the graph but
# missing a display row silently vanished from the shipped object: the
# inner_join dropped it and the row-count assertion still passed, because
# the assertion was pinned to the display table's own length. That is the
# exact failure mode the three v0.3.0 frameworks would have hit. The two
# setdiffs below name the offender instead.
graph_frameworks   <- sort(meta$framework)
display_frameworks <- sort(display$framework)

missing_display <- setdiff(graph_frameworks, display_frameworks)
missing_graph   <- setdiff(display_frameworks, graph_frameworks)

if (length(missing_display) > 0L) {
  stop(
    "Framework(s) typed cybed:Framework in the staged graph have no display ",
    "row in data-raw/build-framework-summary.R. Add a row for each, then ",
    "rerun:\n  ", paste(missing_display, collapse = "\n  "),
    call. = FALSE
  )
}

if (length(missing_graph) > 0L) {
  stop(
    "Display row(s) in data-raw/build-framework-summary.R name a framework ",
    "that is not typed cybed:Framework in the staged graph. Either the graph ",
    "is stale or the display row is wrong:\n  ",
    paste(missing_graph, collapse = "\n  "),
    call. = FALSE
  )
}

framework_summary <- meta |>
  left_join(units,               by = "framework") |>
  left_join(roles,               by = "framework") |>
  left_join(elements_with,       by = "framework") |>
  left_join(examples,            by = "framework") |>
  left_join(subpoints,           by = "framework") |>
  left_join(unit_relations,      by = "framework") |>
  left_join(role_element_counts, by = "framework") |>
  left_join(display,             by = "framework") |>
  mutate(
    # Frameworks with zero Examples, zero Subpoints, or zero UnitRelations
    # are absent from their respective left-joins. coalesce turns those NAs
    # into 0L so the arithmetic below stays well-defined. role_count is
    # deliberately NOT coalesced: NA means the framework asserts no roles.
    example_count                              = dplyr::coalesce(example_count, 0L),
    subpoint_count                             = dplyr::coalesce(subpoint_count, 0L),
    unit_relation_count                        = dplyr::coalesce(unit_relation_count, 0L),
    # 2026-08-14 audit fix: strict must exclude ALL non-parent content, not
    # just Examples. Subpoint (generic enumeration-list splitting) and
    # Example (Cyber.org/CSTA Clarification-statement scaffolding) are both
    # content beyond the framework's own numbered/named units. Previously
    # only example_count was subtracted, so any framework with nonzero
    # Subpoints silently carried inflated "strict" values. This restores the
    # v0.1.1 NEWS.md-era meaning of "strict": matches what the framework's
    # own publisher would count.
    element_count_strict                       = element_count_with_examples - example_count - subpoint_count,
    elements_per_organizing_unit_strict        = round(element_count_strict / organizing_unit_count, 1),
    elements_per_organizing_unit_with_examples = round(element_count_with_examples / organizing_unit_count, 1),
    elements_per_role_strict                   = round(role_elements_strict / role_count, 1),
    elements_per_role_with_examples            = round(role_elements_with_examples / role_count, 1)
  ) |>
  arrange(display_order) |>
  transmute(
    framework_slug    = sub("^.*/", "", framework),
    framework_name    = display_name,
    framework_type,
    jurisdiction,
    organizing_unit_count,
    role_count,
    element_count_strict,
    subpoint_count,
    example_count,
    element_count_with_examples,
    unit_relation_count,
    elements_per_organizing_unit_strict,
    elements_per_organizing_unit_with_examples,
    elements_per_role_strict,
    elements_per_role_with_examples,
    license
  )

# Columns that are allowed to be NA, and only for frameworks that assert no
# cybed:Role. Every other column must be complete.
role_dependent <- c("role_count", "elements_per_role_strict",
                    "elements_per_role_with_examples")
non_role_cols  <- setdiff(names(framework_summary), role_dependent)

stopifnot(
  "framework_summary should have 14 rows" = nrow(framework_summary) == 14L,
  "no NA values expected outside the role-dependent columns" =
    !any(is.na(framework_summary[non_role_cols])),
  "the role-dependent columns must be NA together or present together" =
    all(is.na(framework_summary$role_count) ==
          is.na(framework_summary$elements_per_role_strict)) &&
    all(is.na(framework_summary$role_count) ==
          is.na(framework_summary$elements_per_role_with_examples)),
  "element_count_strict must equal element_count_with_examples - example_count - subpoint_count" =
    all(framework_summary$element_count_strict ==
          framework_summary$element_count_with_examples -
          framework_summary$example_count -
          framework_summary$subpoint_count),
  "every framework's organizing_unit_count must be positive" =
    all(framework_summary$organizing_unit_count > 0L),
  "role_count must never exceed organizing_unit_count" =
    all(framework_summary$role_count <= framework_summary$organizing_unit_count,
        na.rm = TRUE),
  "framework slugs must be unique" =
    !anyDuplicated(framework_summary$framework_slug)
)

# Regression guard, part 2: every column that existed in the shipped object
# must be byte-identical for the original eight frameworks. A rebuild is
# allowed to ADD frameworks and ADD columns. It is not allowed to change a
# published number, because downstream prose, the README, and the
# cross-framework-analysis vignette quote these figures.
if (!is.null(previous_summary)) {
  old_cols <- names(previous_summary)
  new_cols <- names(framework_summary)
  dropped  <- setdiff(old_cols, new_cols)
  if (length(dropped) > 0L) {
    stop("Rebuild dropped previously shipped column(s): ",
         paste(dropped, collapse = ", "), call. = FALSE)
  }

  old_slugs <- previous_summary$framework_slug
  lost      <- setdiff(old_slugs, framework_summary$framework_slug)
  if (length(lost) > 0L) {
    stop("Rebuild dropped previously shipped framework(s): ",
         paste(lost, collapse = ", "), call. = FALSE)
  }

  old_df <- as.data.frame(previous_summary)
  new_df <- as.data.frame(
    framework_summary[match(old_slugs, framework_summary$framework_slug), ]
  )

  # The ONE narrow relaxation, added v0.3.1. The `license` column is now
  # derived from framework_licenses$license_short instead of being typed by
  # hand in this script, and that change is intended to move several labels:
  # SFIA's, NICE's, DCWF's, ECSF's, DigComp's and CCSSF's were stale or
  # understated against what their sources actually say. Holding `license`
  # to byte-identity would block the very correction this release makes.
  #
  # Nothing else is relaxed. Every other pre-existing column, for every
  # pre-existing framework, is still held to byte-identity, because the
  # published numbers are quoted in the README, the cross-framework-analysis
  # vignette, and the Concordance manuscript. If a future change needs
  # another column exempted, exempt it here explicitly and say why. Do not
  # widen this vector to a pattern, and do not remove the guard.
  guard_exempt <- "license"

  # Acknowledged changes: one framework, named columns, a stated cause. Not
  # an exemption, and never a pattern. Each entry lets exactly these cells
  # move for exactly this framework and is printed below when it does.
  #
  # digcomp-3.0: commit 5a9bafe disabled the sub-point parser for DigComp
  # 3.0 on fidelity grounds (its Competence Statement text split into
  # fragments JRC did not publish) and updated the invariants and roxygen
  # counts, but the shipped summary was not rebuilt with it. Its 97
  # Subpoints go to 0, which moves the two with-examples columns with them.
  # Parents (362) and Examples (522) are unchanged.
  acknowledged_drift <- list(
    `digcomp-3.0` = c("subpoint_count", "element_count_with_examples",
                      "elements_per_organizing_unit_with_examples")
  )

  drifted <- character(0)
  acknowledged <- character(0)
  for (cl in setdiff(old_cols, guard_exempt)) {
    ov <- old_df[[cl]]
    nv <- new_df[[cl]]
    bad <- which(!mapply(identical, as.list(ov), as.list(nv)))
    ack <- bad[vapply(old_slugs[bad], \(sl) cl %in% acknowledged_drift[[sl]], logical(1))]
    if (length(ack) > 0L) {
      acknowledged <- c(acknowledged, sprintf("  %s: %s was %s, now %s", cl,
                                              old_slugs[ack], format(ov[ack]),
                                              format(nv[ack])))
    }
    bad <- setdiff(bad, ack)
    if (length(bad) > 0L) {
      drifted <- c(drifted, sprintf(
        "  %s: %s",
        cl,
        paste(sprintf("%s was %s, now %s", old_slugs[bad],
                      format(ov[bad]), format(nv[bad])), collapse = "; ")
      ))
    }
  }

  if (length(drifted) > 0L) {
    stop(
      "REGRESSION GUARD: the rebuild changed pre-existing values for the ",
      "original eight frameworks. Nothing was written. Investigate before ",
      "overwriting data/framework_summary.rda:\n",
      paste(drifted, collapse = "\n"),
      call. = FALSE
    )
  }
  if (length(acknowledged) > 0L) {
    cat("Acknowledged changes (see acknowledged_drift):
",
        paste(acknowledged, collapse = "
"), "
", sep = "")
  }
  cat("Regression guard passed: all pre-existing columns unchanged for the original eight frameworks",
      if (length(guard_exempt)) paste0(" (exempt: ", paste(guard_exempt, collapse = ", "), ")"),
      ".\n", sep = "")

  # Report the licence-label moves the exemption allowed, so the relaxation
  # never hides a change silently.
  lic_moved <- which(!mapply(identical,
                             as.list(old_df$license), as.list(new_df$license)))
  if (length(lic_moved) > 0L) {
    cat("Licence labels changed (derived from framework_licenses):\n")
    cat(sprintf("  %s: %s -> %s\n", old_slugs[lic_moved],
                old_df$license[lic_moved], new_df$license[lic_moved]),
        sep = "")
  }
}

if (!dir.exists("data")) dir.create("data")
save(framework_summary, file = "data/framework_summary.rda", compress = "xz")

cat("Wrote data/framework_summary.rda\n")
print(framework_summary, n = 20, width = 300)

# Reported, not shipped: the mean number of elements per role counting
# repeats (cybed:hasElement edges / role_count). Where this exceeds the
# distinct-element density, statements are shared across roles.
cat("\nRole element density, distinct vs counting repeats (reported, not a column):\n")
print(
  role_element_counts |>
    dplyr::left_join(roles, by = "framework") |>
    dplyr::transmute(
      framework_slug = sub("^.*/", "", framework),
      role_count,
      distinct_elements_from_roles = role_elements_with_examples,
      per_role_distinct            = round(role_elements_with_examples / role_count, 1),
      role_element_edges,
      per_role_with_repeats        = round(role_element_edges / role_count, 1)
    ) |>
    dplyr::arrange(framework_slug),
  n = 20, width = 300
)
