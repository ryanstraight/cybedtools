# Pairwise text similarity between NICE work roles and ENISA ECSF
# role profiles, with each unit's full document (parent description +
# all child elements concatenated) as the comparison surface.

suppressPackageStartupMessages({
  library(cybedtools)
  library(dplyr)
  library(tidyr)
  library(stringr)
  library(purrr)
  library(here)
  library(rdflib)
})

data_dir <- here("concordance", "_data")
dir.create(data_dir, showWarnings = FALSE, recursive = TRUE)

graph_path <- here("data", "processed", "ntriples", "_combined.nt")
g <- load_combined_ntriples_graph(graph_path)

# ---------------------------------------------------------------------------
# Helpers (same idiom as nice_csec2017 prep)
# ---------------------------------------------------------------------------

stopwords <- c(
  "the","a","an","of","in","to","for","with","and","or","is","are","be","by",
  "on","at","as","that","this","their","they","it","its","from","how","can",
  "use","using","used","may","will","such","but","not","do","have","has",
  "what","which","when","between","into","about","also","than","then","there",
  "these","those","while","each","other","both","more","most","some","many",
  "include","including","includes","example","examples","based","through",
  "any","all","new","one","two","three","work","perform","performs","ensure"
)

tokenize <- function(x) {
  if (is.na(x) || nchar(x) == 0) return(character(0))
  toks <- str_split(str_to_lower(x), "[^a-z0-9]+", simplify = FALSE)[[1]]
  toks <- toks[nchar(toks) >= 3 & !toks %in% stopwords]
  unique(toks)
}

jaccard <- function(a, b) {
  if (length(a) == 0 || length(b) == 0) return(0)
  i <- length(intersect(a, b))
  u <- length(union(a, b))
  if (u == 0) 0 else i / u
}

# ---------------------------------------------------------------------------
# Pull NICE work roles + ECSF role profiles, attach full-document text
# ---------------------------------------------------------------------------

unit_bindings <- organizing_unit_framework_bindings(g)
nice_roles <- unit_bindings |>
  filter(grepl("^NICE", framework_name)) |>
  select(unit, unit_name)
ecsf_profiles <- unit_bindings |>
  filter(grepl("ECSF", framework_name)) |>
  select(unit, unit_name)

elem_text <- sparql_pairs(g, "cybed:elementText") |>
  transmute(element = s, text = o)
unit_to_element <- role_element_bindings(g) |>
  rename(unit = role)
unit_descriptions <- sparql_pairs(g, "schema:description") |>
  transmute(unit = s, description = o)

build_full_doc <- function(unit_tbl) {
  child_text <- unit_to_element |>
    semi_join(unit_tbl, by = "unit") |>
    inner_join(elem_text, by = "element") |>
    group_by(unit) |>
    summarise(child_text = paste(text, collapse = " "), .groups = "drop")

  unit_tbl |>
    left_join(unit_descriptions, by = "unit") |>
    left_join(child_text, by = "unit") |>
    mutate(full_text = paste(
      replace_na(unit_name, ""),
      replace_na(description, ""),
      replace_na(child_text, ""),
      sep = " "))
}

nice_full <- build_full_doc(nice_roles) |>
  mutate(tokens = lapply(full_text, tokenize),
         n_tok  = lengths(tokens))
ecsf_full <- build_full_doc(ecsf_profiles) |>
  mutate(tokens = lapply(full_text, tokenize),
         n_tok  = lengths(tokens))

# ---------------------------------------------------------------------------
# Pairwise similarity (NICE x ECSF; 41 x 12 = 492 pairs)
# ---------------------------------------------------------------------------

grid <- expand_grid(ni = seq_len(nrow(nice_full)),
                    ei = seq_len(nrow(ecsf_full))) |>
  mutate(similarity = map2_dbl(ni, ei,
    ~ jaccard(nice_full$tokens[[.x]], ecsf_full$tokens[[.y]])))

top_per_role <- grid |>
  arrange(ni, desc(similarity)) |>
  group_by(ni) |>
  slice_head(n = 3) |>
  mutate(rank = row_number()) |>
  ungroup() |>
  transmute(
    nice_id    = nice_full$unit[ni],
    nice_name  = nice_full$unit_name[ni],
    rank,
    ecsf_id    = ecsf_full$unit[ei],
    ecsf_name  = ecsf_full$unit_name[ei],
    similarity = round(similarity, 3)
  )

best_per_role <- top_per_role |> filter(rank == 1L)

saveRDS(top_per_role,  file.path(data_dir, "nice_ecsf_alignment.rds"))
saveRDS(best_per_role, file.path(data_dir, "nice_ecsf_best.rds"))

cat("\nNICE x ECSF alignment data written.\n")
cat("  NICE work roles: ", nrow(nice_full), "\n", sep = "")
cat("  ECSF profiles:   ", nrow(ecsf_full), "\n", sep = "")
cat("  pair candidates: ", nrow(grid),      "\n", sep = "")

cat("\n=== Best-match similarity distribution ===\n")
print(summary(best_per_role$similarity))

cat("\n=== ECSF profile frequency as top-1 match ===\n")
print(best_per_role |> count(ecsf_name, sort = TRUE))

cat("\n=== Top 10 strongest NICE -> ECSF best matches ===\n")
best_per_role |>
  arrange(desc(similarity)) |>
  slice_head(n = 10) |>
  print(width = 200)
