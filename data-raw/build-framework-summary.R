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

rdf <- load_combined_ntriples_graph()

meta <- framework_metadata(rdf)

# Cross-framework parent count: every framework's top-level enumerated unit
# regardless of whether it is a workforce role. Replaces the role-only count
# used in v0.1.x, which under-counted the five non-workforce frameworks
# (SFIA, Cyber.org K-12, CSTA, CSEC2017, DigComp 2.2) where parents are not
# typed cybed:Role under v0.2.0.
units <- organizing_unit_framework_bindings(rdf) |>
  count(framework, name = "organizing_unit_count")

# Total element count includes parents, Subpoints, and Examples.
elements_with <- element_framework_bindings(rdf) |>
  count(framework, name = "element_count_with_examples")

# Example count: cybed:Example instances (Cyber.org K-12 and CSTA
# Clarification-statement scaffolding). Zero for the six frameworks that do
# not encode pedagogical examples.
examples <- example_framework_bindings(rdf) |>
  count(framework, name = "example_count") |>
  # Frameworks with zero Examples are absent from the inner join; left-join
  # on a complete framework list and replace_na turns them into 0L below.
  identity()

# Display + classification metadata not present in the JSON-LD. License,
# the workforce/pedagogy content classification, and ordering originate
# outside the JSON-LD graph and rarely change. Slug-keyed for stability
# across revisions. The framework_type column denotes content focus
# (workforce competencies vs educational standards), not the structural
# distinction that drives cybed:Role assertion (NICE/DCWF/ECSF carry
# cybed:Role; SFIA carries cybed:OrganizingUnit only despite being a
# workforce-content framework, because it enumerates skills rather than
# work roles). For structural questions, query cybed:Role and
# cybed:OrganizingUnit directly.
display <- tibble::tribble(
  ~framework,                                                    ~display_order, ~display_name,             ~framework_type, ~license,
  "https://w3id.org/cybed/ontology#framework/nice-v2",           1L,             "NICE v2",                 "workforce",     "public domain",
  "https://w3id.org/cybed/ontology#framework/dcwf-v5.1",         2L,             "DCWF v5.1",               "workforce",     "public domain",
  "https://w3id.org/cybed/ontology#framework/ecsf-v1",           3L,             "ECSF v1",                 "workforce",     "ENISA re-use notice",
  "https://w3id.org/cybed/ontology#framework/sfia-9",            4L,             "SFIA 9",                  "workforce",     "SFIA Use Policy",
  "https://w3id.org/cybed/ontology#framework/cyberorg-k12-v1.0", 5L,             "Cyber.org K-12 v1.0",     "pedagogy",      "CC BY-NC 4.0",
  "https://w3id.org/cybed/ontology#framework/csta-2017",         6L,             "CSTA K-12 CS (Rev 2017)", "pedagogy",      "CC BY-NC-SA 4.0",
  "https://w3id.org/cybed/ontology#framework/csec2017-v1",       7L,             "ACM/IEEE CSEC2017",       "pedagogy",      "ACM/IEEE educational-use",
  "https://w3id.org/cybed/ontology#framework/digcomp-2.2",       8L,             "DigComp 2.2",             "pedagogy",      "EU open re-use"
)

framework_summary <- meta |>
  inner_join(units,         by = "framework") |>
  inner_join(elements_with, by = "framework") |>
  left_join(examples,       by = "framework") |>
  inner_join(display,       by = "framework") |>
  mutate(
    # Frameworks with zero Examples are absent from the example_count
    # left-join. coalesce turns that NA into 0L so the strict/with-examples
    # arithmetic below stays well-defined.
    example_count                              = dplyr::coalesce(example_count, 0L),
    element_count_strict                       = element_count_with_examples - example_count,
    elements_per_organizing_unit_strict        = round(element_count_strict / organizing_unit_count, 1),
    elements_per_organizing_unit_with_examples = round(element_count_with_examples / organizing_unit_count, 1)
  ) |>
  arrange(display_order) |>
  transmute(
    framework_slug    = sub("^.*/", "", framework),
    framework_name    = display_name,
    framework_type,
    jurisdiction,
    organizing_unit_count,
    element_count_strict,
    element_count_with_examples,
    example_count,
    elements_per_organizing_unit_strict,
    elements_per_organizing_unit_with_examples,
    license
  )

# Defensive: every framework typed in the graph must produce one row, and
# every entry in the display table must match an actual framework. If
# either fails, the build script is out of sync with the staged graph and
# the user should refresh data-raw/.
stopifnot(
  "framework_summary should have 8 rows; got fewer" = nrow(framework_summary) == 8L,
  "no NA values expected in framework_summary" = !any(is.na(framework_summary)),
  "element_count_strict must equal element_count_with_examples - example_count" =
    all(framework_summary$element_count_strict ==
          framework_summary$element_count_with_examples - framework_summary$example_count),
  "every framework's organizing_unit_count must be positive" =
    all(framework_summary$organizing_unit_count > 0L)
)

if (!dir.exists("data")) dir.create("data")
save(framework_summary, file = "data/framework_summary.rda", compress = "xz")

cat("Wrote data/framework_summary.rda\n")
print(framework_summary)
