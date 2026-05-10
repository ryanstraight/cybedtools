# Pairwise text similarity between Cyber.org K-12 and CSTA K-12 standards.
# Two passes:
#   1. parent-only Jaccard
#   2. full-document Jaccard (parent + cybed:Subpoint + cybed:Example,
#      concatenated per parent)
# The contrast between the two is the worked-example page's finding.

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
# Helpers
# ---------------------------------------------------------------------------

prefix_block <- paste0(
  "PREFIX cybed: <https://w3id.org/cybed/ontology#>\n",
  "PREFIX schema: <http://schema.org/>\n",
  "PREFIX cyberorg: <https://cyber.org/standards/terms#>\n",
  "PREFIX csta: <https://csteachers.org/k12standards/terms#>\n"
)

query_subjects <- function(rdf, type_iri) {
  q <- paste0(prefix_block, sprintf("SELECT ?s WHERE { ?s a %s }", type_iri))
  res <- rdflib::rdf_query(rdf, q)
  if (nrow(res) == 0) tibble::tibble(s = character(0)) else tibble::as_tibble(res)
}

stopwords <- c(
  "the","a","an","of","in","to","for","with","and","or","is","are","be","by",
  "on","at","as","that","this","their","they","it","its","from","how","can",
  "use","using","used","may","will","such","but","not","do","have","has",
  "what","which","when","between","into","about","also","than","then","there",
  "these","those","while","each","other","both","more","most","some","many",
  "include","including","includes","example","examples","based","through"
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
# Pull elements: parents (cyberorg:Standard / csta:Standard) plus all
# children (cybed:Subpoint, cybed:Example) and parent membership via
# cybed:hasElement / cybed:hasExample.
# ---------------------------------------------------------------------------

cyberorg_parents <- query_subjects(g, "cyberorg:Standard") |>
  transmute(element = s, framework_slug = "cyberorg-k12")
csta_parents <- query_subjects(g, "csta:Standard") |>
  transmute(element = s, framework_slug = "csta-2017")
parents_iri <- bind_rows(cyberorg_parents, csta_parents)

elem_text <- sparql_pairs(g, "cybed:elementText") |>
  transmute(element = s, text = o)

# parent -> child via cybed:hasElement (Subpoints) and cybed:hasExample.
has_element <- sparql_pairs(g, "cybed:hasElement") |>
  transmute(parent = s, child = o)
has_example <- sparql_pairs(g, "cybed:hasExample") |>
  transmute(parent = s, child = o)
all_links <- bind_rows(has_element, has_example)

# Filter links to those whose parent is one of our K-12 parents.
k12_links <- all_links |>
  semi_join(parents_iri |> select(parent = element), by = "parent") |>
  inner_join(elem_text, by = c("child" = "element")) |>
  rename(child_text = text)

# Concat full document text per parent.
full_docs <- k12_links |>
  group_by(parent) |>
  summarise(child_text = paste(child_text, collapse = " "), .groups = "drop") |>
  rename(element = parent)

parents <- parents_iri |>
  inner_join(elem_text, by = "element") |>
  left_join(full_docs, by = "element") |>
  mutate(full_text = paste(text, replace_na(child_text, ""), sep = " "))

# Attach OrganizingUnit metadata.
unit_bindings <- organizing_unit_framework_bindings(g) |>
  filter(grepl("^Cyber\\.org|^CSTA", framework_name))
unit_to_element <- role_element_bindings(g) |>
  rename(unit = role) |>
  semi_join(unit_bindings, by = "unit")

parents <- parents |>
  inner_join(unit_to_element, by = "element") |>
  inner_join(unit_bindings |> select(unit, unit_name, framework_name), by = "unit") |>
  group_by(element) |>
  slice_head(n = 1) |>
  ungroup()

# ---------------------------------------------------------------------------
# Tokenize parent-only and full-document text
# ---------------------------------------------------------------------------

parents <- parents |>
  mutate(
    parent_tokens = lapply(text,      tokenize),
    full_tokens   = lapply(full_text, tokenize),
    parent_n      = lengths(parent_tokens),
    full_n        = lengths(full_tokens)
  )

cyberorg_p <- parents |> filter(framework_slug == "cyberorg-k12")
csta_p     <- parents |> filter(framework_slug == "csta-2017")

# ---------------------------------------------------------------------------
# Pairwise similarity, two passes
# ---------------------------------------------------------------------------

grid <- expand_grid(ci = seq_len(nrow(cyberorg_p)), cj = seq_len(nrow(csta_p)))

grid <- grid |>
  mutate(
    sim_parent = map2_dbl(ci, cj,
      ~ jaccard(cyberorg_p$parent_tokens[[.x]], csta_p$parent_tokens[[.y]])),
    sim_full   = map2_dbl(ci, cj,
      ~ jaccard(cyberorg_p$full_tokens[[.x]],   csta_p$full_tokens[[.y]]))
  )

# Best CSTA match per Cyber.org standard, both passes, no threshold yet.
best_parent <- grid |>
  arrange(ci, desc(sim_parent)) |>
  group_by(ci) |>
  slice_head(n = 1) |>
  ungroup() |>
  transmute(ci, best_parent_cj = cj, best_parent_sim = sim_parent)

best_full <- grid |>
  arrange(ci, desc(sim_full)) |>
  group_by(ci) |>
  slice_head(n = 1) |>
  ungroup() |>
  transmute(ci, best_full_cj = cj, best_full_sim = sim_full)

best <- best_parent |>
  inner_join(best_full, by = "ci") |>
  mutate(
    cyberorg_id      = cyberorg_p$element[ci],
    cyberorg_unit    = cyberorg_p$unit_name[ci],
    cyberorg_text    = cyberorg_p$text[ci],

    parent_csta_id   = csta_p$element[best_parent_cj],
    parent_csta_unit = csta_p$unit_name[best_parent_cj],
    parent_csta_text = csta_p$text[best_parent_cj],

    full_csta_id     = csta_p$element[best_full_cj],
    full_csta_unit   = csta_p$unit_name[best_full_cj],
    full_csta_text   = csta_p$text[best_full_cj],

    full_csta_full_text = csta_p$full_text[best_full_cj]
  ) |>
  select(-ci, -best_parent_cj, -best_full_cj) |>
  rename(parent_sim = best_parent_sim, full_sim = best_full_sim) |>
  mutate(
    parent_sim = round(parent_sim, 3),
    full_sim   = round(full_sim, 3),
    delta      = round(full_sim - parent_sim, 3)
  )

# Strength tiering on the full-document similarity.
best <- best |>
  mutate(
    full_strength = case_when(
      full_sim >= 0.30 ~ "strong",
      full_sim >= 0.20 ~ "moderate",
      full_sim >= 0.10 ~ "weak",
      TRUE             ~ "none"
    ),
    parent_strength = case_when(
      parent_sim >= 0.30 ~ "strong",
      parent_sim >= 0.20 ~ "moderate",
      parent_sim >= 0.10 ~ "weak",
      TRUE               ~ "none"
    )
  )

# ---------------------------------------------------------------------------
# Save
# ---------------------------------------------------------------------------

saveRDS(best, file.path(data_dir, "k12_alignment.rds"))
saveRDS(parents |> select(-parent_tokens, -full_tokens),
        file.path(data_dir, "k12_alignment_parents.rds"))

cat("\nk12 alignment data written.\n")
cat("  cyberorg parents: ", nrow(cyberorg_p), "\n", sep = "")
cat("  csta parents:     ", nrow(csta_p),     "\n", sep = "")

cat("\n=== Token-count distribution ===\n")
parents |> group_by(framework_slug) |>
  summarise(parent_med = median(parent_n),
            parent_max = max(parent_n),
            full_med   = median(full_n),
            full_max   = max(full_n)) |>
  print()

cat("\n=== Strength tiers, parent-only ===\n")
print(table(best$parent_strength))
cat("\n=== Strength tiers, full-document ===\n")
print(table(best$full_strength))

cat("\n=== Top 10 by full-doc similarity ===\n")
best |>
  arrange(desc(full_sim)) |>
  slice_head(n = 10) |>
  mutate(across(c(cyberorg_text, parent_csta_text, full_csta_text),
                ~ stringr::str_trunc(.x, 70))) |>
  select(cyberorg_unit, cyberorg_text,
         parent_sim, full_csta_unit, full_csta_text, full_sim) |>
  print(width = 240)
