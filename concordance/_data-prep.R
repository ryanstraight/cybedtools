# Populates _data/ from the combined RDF graph.

suppressPackageStartupMessages({
  library(cybedtools)
  library(dplyr)
  library(here)
})

data_dir <- here("concordance", "_data")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

graph_path <- here("data", "processed", "ntriples", "_combined.nt")
g <- load_combined_ntriples_graph(graph_path)

# Publication terms per framework. framework_summary and density_spread carry
# framework names, counts and licences, no statement text, so every character
# column is declared as structure below. The guard inspects them all, so a text
# column added later stops the write instead of shipping.
source(here("concordance", "_publication-guard.R"))
invisible(publication_policy(g))

summary_structure_cols <- c("framework_slug", "framework_name",
                            "framework_type", "jurisdiction", "license")

assert_no_unpublishable_text(framework_summary,
                             structure_cols = summary_structure_cols)
saveRDS(framework_summary, file.path(data_dir, "framework_summary.rds"))

density_spread <- framework_summary |>
  arrange(desc(elements_per_organizing_unit_with_examples)) |>
  select(
    framework_name,
    framework_slug,
    framework_type,
    jurisdiction,
    organizing_unit_count,
    element_count_strict,
    element_count_with_examples,
    elements_per_organizing_unit_strict,
    elements_per_organizing_unit_with_examples,
    license
  )
assert_no_unpublishable_text(density_spread,
                             structure_cols = summary_structure_cols)
saveRDS(density_spread, file.path(data_dir, "density_spread.rds"))
