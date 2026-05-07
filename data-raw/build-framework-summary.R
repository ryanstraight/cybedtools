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

roles <- role_framework_bindings(rdf) |>
  count(framework, name = "role_count")

elements <- element_framework_bindings(rdf) |>
  count(framework, name = "element_count")

# Display + classification metadata not present in the JSON-LD. License
# and workforce/pedagogy classification come from each framework's own
# materials and rarely change. Slug-keyed for stability across revisions.
display <- tibble::tribble(
  ~framework,                                                    ~display_order, ~display_name,             ~framework_type, ~license,
  "https://w3id.org/cybed/ontology#framework/nice-v2",           1L,             "NICE v2",                 "workforce",     "public domain",
  "https://w3id.org/cybed/ontology#framework/dcwf-v5.1",         2L,             "DCWF v5.1",               "workforce",     "public domain",
  "https://w3id.org/cybed/ontology#framework/ecsf-v1",           3L,             "ECSF v1",                 "workforce",     "CC BY 4.0",
  "https://w3id.org/cybed/ontology#framework/sfia-9",            4L,             "SFIA 9",                  "workforce",     "SFIA non-commercial",
  "https://w3id.org/cybed/ontology#framework/cyberorg-k12-v1.0", 5L,             "Cyber.org K-12 v1.0",     "pedagogy",      "CC BY-NC 4.0",
  "https://w3id.org/cybed/ontology#framework/csta-2017",         6L,             "CSTA K-12 CS (Rev 2017)", "pedagogy",      "CC BY-NC-SA 4.0",
  "https://w3id.org/cybed/ontology#framework/csec2017-v1",       7L,             "ACM/IEEE CSEC2017",       "pedagogy",      "ACM/IEEE educational-use",
  "https://w3id.org/cybed/ontology#framework/digcomp-2.2",       8L,             "DigComp 2.2",             "pedagogy",      "EU open re-use"
)

framework_summary <- meta |>
  inner_join(roles,    by = "framework") |>
  inner_join(elements, by = "framework") |>
  inner_join(display,  by = "framework") |>
  mutate(elements_per_role = round(element_count / role_count, 1)) |>
  arrange(display_order) |>
  transmute(
    framework_slug    = sub("^.*/", "", framework),
    framework_name    = display_name,
    framework_type,
    jurisdiction,
    role_count,
    element_count,
    elements_per_role,
    license
  )

# Defensive: every framework typed in the graph must produce one row, and
# every entry in the display table must match an actual framework. If
# either fails, the build script is out of sync with the staged graph and
# the user should refresh data-raw/.
stopifnot(
  "framework_summary should have 8 rows; got fewer" = nrow(framework_summary) == 8L,
  "no NA values expected in framework_summary" = !any(is.na(framework_summary))
)

if (!dir.exists("data")) dir.create("data")
save(framework_summary, file = "data/framework_summary.rda", compress = "xz")

cat("Wrote data/framework_summary.rda\n")
print(framework_summary)
