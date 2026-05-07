# Cross-framework Analysis with cybedtools

## What you’ll find here

Three findings the package surfaces directly from the eight-framework
graph, then the SPARQL primitives and dplyr patterns that produce them.

**Element density per framework varies by 50x.** NICE expresses 51.5
elements per role. Cyber.org K-12 expresses 1.1. Some of this is
framework purpose (workforce specification vs. K-12 learning outcomes).
Some is uneven specification within the same framework type. Either way,
“covers the NICE Framework” and “covers the CSEC2017 guidelines” are not
comparable curricular claims.

**Jurisdictional element coverage is dominated by US frameworks 13 to
1.** US frameworks (NICE, DCWF, Cyber.org K-12, CSTA) contribute 5,299
elements. EU frameworks (ECSF, DigComp) contribute 395. Comparative work
in cybersecurity education has been operating against an asymmetric
corpus.

**The five highest-element-load NICE work roles concentrate
disproportionate competency specification.** Security Control Assessment
(307 elements), Secure Systems Development (232), Cybersecurity
Architecture (219), Defensive Cybersecurity (206), Systems Security
Management (204). Curricula that “cover NICE” by surveying these five
roles look thorough. Curricula that cover the long tail of 41 roles look
thin by element count alone.

The rest of this vignette is the technical apparatus that produces these
and other comparative findings, organized by query family:

- **Family A: structural.** Framework metadata, role and element counts,
  structural comparisons.
- **Family B: cross-framework pivots.** Jurisdiction, sector,
  specificity.

## Why R-side joins, not multi-pattern SPARQL?

The `librdf` C library that `rdflib` wraps exhibits poor performance and
silent zero-row results on conjunctive triple patterns at this graph’s
scale. Multi-pattern SPARQL queries hang for many minutes.
Multi-property selects on a single subject silently return no rows.
Single basic graph patterns (one triple match per SPARQL call) execute
fast and correctly.

The package’s discipline:

1.  SPARQL queries are single basic graph patterns.
2.  Joins, multi-property assembly, and aggregation happen in R via
    dplyr.

The helpers in `R/sparql-helpers.R` implement this discipline. Most
users of this vignette will never write SPARQL directly. They call the
domain helpers and compose the results in dplyr.

``` r

library(cybedtools)
library(dplyr)

# N-Triples is the recommended backend; parses fast, runs single-BGP
# queries correctly. Pre-built by scripts/025-export-ntriples.R.
rdf <- load_combined_ntriples_graph()
```

## Family A: structural queries

### Framework inventory with metadata

``` r

# One row per framework with name, jurisdiction, sector, specificity.
# This is the metadata foundation every cross-framework pivot joins onto.
framework_metadata(rdf) |>
  arrange(jurisdiction, name)
```

Expected output (8 frameworks):

    # A tibble: 8 × 5
      framework                                name                               jurisdiction sector              specificity
      <chr>                                    <chr>                              <chr>        <chr>               <chr>
    1 https://w3id.org/cybed/.../digcomp-2.2  DigComp 2.2                        EU           citizen-education   general-digital-competence
    2 https://w3id.org/cybed/.../ecsf-v1      ECSF v1                            EU           civilian            cybersecurity-specific
    3 https://w3id.org/cybed/.../csec2017-v1  CSEC2017 Curricular Guidelines...  global       higher-education    cybersecurity-specific
    4 https://w3id.org/cybed/.../sfia-9       SFIA 9                             global       general             general-IT
    5 https://w3id.org/cybed/.../csta-2017    CSTA K-12 Computer Science...      US           K-12-education      general-computing
    6 https://w3id.org/cybed/.../cyberorg...  Cyber.org K-12 Learning...         US           K-12-education      cybersecurity-specific
    7 https://w3id.org/cybed/.../dcwf-v51     DCWF v5.1                          US           defense             cybersecurity-specific
    8 https://w3id.org/cybed/.../nice-v2      NICE v2 (NIST SP 800-181 Rev 1...) US           civilian            cybersecurity-specific

### Role counts per framework

``` r

# How many roles each framework declares, sorted high to low.
role_framework_bindings(rdf) |>
  count(framework_name, sort = TRUE, name = "role_count")
```

### Element volume per framework

``` r

# How many atomic elements (tasks, knowledge statements, standards, etc.)
# each framework declares, sorted high to low.
element_framework_bindings(rdf) |>
  count(framework_name, sort = TRUE, name = "element_count")
```

Density varies dramatically. DCWF has roughly 2,945 elements across 74
roles (about 40 elements per role). Cyber.org K-12 has 123 elements
across 116 grade-band clusters (near 1:1). DigComp has 21 elements
across 5 areas. A schema that generalizes across both extremes is doing
real work.

The same numbers, plotted from
[`cybedtools::framework_summary`](https://ryanstraight.github.io/cybedtools/reference/framework_summary.md)
(no staged graph required, since the data object ships with the
package). Hover for role and element counts:

``` r

library(ggplot2)
library(plotly)

# Hover text built from per-framework metadata so readers can verify the
# 50x density spread directly from the chart, without scanning a tibble.
fs <- cybedtools::framework_summary

p <- ggplot(
  fs,
  aes(
    x    = elements_per_role,
    y    = reorder(framework_name, elements_per_role),
    fill = framework_type,
    text = paste0(
      "<b>", framework_name, "</b><br>",
      role_count, " roles, ",
      format(element_count, big.mark = ","), " elements<br>",
      elements_per_role, " elements per role<br>",
      jurisdiction, " · ", license
    )
  )
) +
  geom_col(width = 0.7) +
  scale_fill_manual(
    values = c(workforce = "#0F172A", pedagogy = "#38BDF8"),
    name   = NULL
  ) +
  labs(x = "Elements per role", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    legend.position    = "top"
  )

ggplotly(p, tooltip = "text") |>
  config(displayModeBar = FALSE)
```

### Largest roles by element count

``` r

# Cache the two binding tibbles to avoid re-running queries when iterating.
reb <- role_element_bindings(rdf)
rfb <- role_framework_bindings(rdf)

# Count elements per role, attach role name and parent framework, take the
# heaviest 10 across the entire eight-framework graph.
reb |>
  count(role, name = "element_count") |>
  left_join(rfb |> select(role, role_name, framework_name), by = "role") |>
  arrange(desc(element_count)) |>
  slice_head(n = 10)
```

## Family B: cross-framework pivots

### Element volume by jurisdiction

``` r

# Pivot total elements onto each framework's jurisdiction (US/EU/global).
# Surfaces the 13:1 US-vs-EU asymmetry in the corpus.
element_framework_bindings(rdf) |>
  left_join(
    framework_metadata(rdf) |> transmute(framework, jurisdiction),
    by = "framework"
  ) |>
  count(jurisdiction, name = "element_count") |>
  arrange(desc(element_count))
```

### Element volume by sector

``` r

# Same shape, pivoting on sector (civilian / defense / K-12-education / etc.).
element_framework_bindings(rdf) |>
  left_join(
    framework_metadata(rdf) |> transmute(framework, sector),
    by = "framework"
  ) |>
  count(sector, name = "element_count") |>
  arrange(desc(element_count))
```

### Element volume by specificity

``` r

# Same shape, pivoting on specificity (cybersecurity-specific vs. general-IT,
# general-computing, general-digital-competence).
element_framework_bindings(rdf) |>
  left_join(
    framework_metadata(rdf) |> transmute(framework, specificity),
    by = "framework"
  ) |>
  count(specificity, name = "element_count") |>
  arrange(desc(element_count))
```

## Recipe: pairwise comparison between two frameworks

``` r

# Compare role density: NICE (role-first specification) vs SFIA (skill-first).
rfb <- role_framework_bindings(rdf)
reb <- role_element_bindings(rdf)

# Filter to the two frameworks of interest, attach element counts to each
# role, then aggregate role-count and element-density statistics per
# framework. Useful when arguing about how differently the two structure
# their workforce specifications.
rfb |>
  filter(framework_name %in% c("NICE v2 (NIST SP 800-181 Rev 1 components)", "SFIA 9")) |>
  left_join(reb |> count(role, name = "element_count"), by = "role") |>
  group_by(framework_name) |>
  summarize(
    role_count      = n(),
    mean_elements   = round(mean(element_count, na.rm = TRUE), 1),
    median_elements = median(element_count, na.rm = TRUE),
    max_elements    = max(element_count, na.rm = TRUE)
  )
```

## Going beyond the helpers: writing your own single-BGP queries

When you need data the domain helpers do not expose, drop down to the
primitives:

- `sparql_subjects(rdf, predicate, object)` returns subjects of triples
  whose predicate and object are both fixed (e.g.,
  `sparql_subjects(rdf, "a", "cybed:Role")`).
- `sparql_pairs(rdf, predicate)` returns subject-object pairs for all
  triples with a given predicate (e.g.,
  `sparql_pairs(rdf, "schema:name")`).

Both run a single triple match, which librdf handles correctly. Compose
multiple calls and join the results in dplyr. Do not write SPARQL
queries with multiple BGPs joined on shared variables. They will hang or
silently return zero rows on this graph.

## Notes on rdflib and librdf behavior

- **Aggregates unreliable.** `COUNT`, `GROUP BY`, and `HAVING` in SPARQL
  1.1 are inconsistent in the librdf backend. Aggregate in R via dplyr.
- **Conjunctive joins are not supported in practice.** The combination
  of librdf’s planner and rdflib’s wrapper produces hangs and silent
  zero-row results on multi-pattern joins. The package’s helpers all use
  single basic graph patterns and join in R.
- **Use N-Triples for querying, JSON-LD for authoring.**
  [`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md)
  parses in under a second.
  [`load_combined_rdf_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_rdf_graph.md)
  (JSON-LD) is canonical for downstream semantic-web interop but
  performs poorly under librdf for large graphs.
- **`OPTIONAL` clauses.** Use with care. librdf occasionally returns 0
  rows for queries that should return bindings with unbound optional
  variables.
