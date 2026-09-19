# Precompute NICE work-role element-count distribution for the top-work-roles
# query page. Reads the staged combined N-Triples graph and writes a tibble
# of role_name + element_count to _data/top_work_roles.rds.
#
# Run from the cybedtools repo root: Rscript concordance/_data-prep-top-work-roles.R
suppressPackageStartupMessages({
  library(cybedtools)
  library(dplyr)
  library(here)
})

rdf <- load_combined_ntriples_graph()

# Publication terms per framework. Nothing here persists statement text, only
# role titles and counts, so role_name is declared as structure below. The
# guard inspects every character column, so a text column added later stops the
# write instead of shipping.
source(here("concordance", "_publication-guard.R"))
invisible(publication_policy(rdf))

## ---- reproduce-pull ----
nice_role_counts <- role_framework_bindings(rdf) |>
  filter(grepl("^NICE", framework_name)) |>
  inner_join(
    role_element_bindings(rdf) |> count(role, name = "element_count"),
    by = "role"
  ) |>
  arrange(desc(element_count)) |>
  select(role_name, element_count)
## ---- reproduce-end ----

cat("NICE work roles:", nrow(nice_role_counts), "\n")
cat("Top 5 by element count:\n")
print(nice_role_counts |> slice_head(n = 5))
top5_share <- sum(head(nice_role_counts$element_count, 5)) /
  sum(nice_role_counts$element_count) * 100
cat("\nTop-5 share of NICE element total:",
    round(top5_share, 1), "%\n")

out_path <- here("concordance", "_data", "top_work_roles.rds")
dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
assert_no_unpublishable_text(nice_role_counts, structure_cols = "role_name")
saveRDS(nice_role_counts, out_path)
cat("Saved", out_path, "\n")
