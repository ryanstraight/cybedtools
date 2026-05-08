# Cross-framework Analysis with cybedtools

## What you’ll find here

The eight frameworks in cybedtools were authored independently by
different bodies with different audiences (NIST and DoD writing for the
US workforce, ENISA and JRC writing for the EU citizen and policy
audiences, Cyber.org and CSTA writing for K-12 educators, ACM/IEEE for
higher-ed curricula, SFIA Foundation for the global IT-skills market).
They specify at incommensurable units of analysis: work role, skill
level, competence, learning standard, Knowledge Area, competence area.
They reflect different design philosophies: granular specification
versus profile-level interoperability frames versus citizen
self-assessment instruments. They do not agree on what to count, how to
count it, or how to organize what they count.

That heterogeneity is the reason a cross-framework comparison layer
needs to exist. cybedtools does not erase the differences. It makes them
queryable.

The findings below are what shows up when you put eight
differently-organized frameworks in the same graph and run the same
queries against each. Read them as demonstrations of what the comparison
layer surfaces, not as claims about which framework is “more thorough”
or “more granular” in absolute terms.

### Element volume varies by ~140x across the corpus

DCWF declares 2,945 elements; DigComp 2.2 declares 21.
Per-organizing-unit density correspondingly spreads from NICE’s 51.6
elements per work role to DigComp’s 4.2 elements per competence area, a
12x ratio. The spread reflects each framework’s design philosophy, not
differences in care or completeness: NICE/DCWF are granular by design as
the basis for hiring and training pipelines; ECSF and DigComp are
intentionally high-level as interoperability frames and citizen
self-assessment instruments. cybedtools does not normalize across this
asymmetry; downstream analyses that aggregate “framework coverage”
should account for it explicitly. The sub-point parser surfaces hidden
granularity in prose-encoded frameworks (most visibly Cyber.org K-12,
where the parser lifts ~393 sub-points out of 123 numbered standards’
Clarification statements).

### The corpus skews US-heavy by element volume

US frameworks contribute roughly 5,716 elements (NICE, DCWF, Cyber.org
K-12, CSTA); EU frameworks contribute roughly 411 (ECSF, DigComp). The
14:1 ratio reflects design philosophy more than relative investment:
ENISA designed ECSF as profile-level for national elaboration, and JRC
designed DigComp 2.2 as a citizen self-assessment instrument. ECSF
profiles also embed e-CF 4.0 cross-references that cybedtools does not
currently materialize as triples; full ECSF coverage requires consulting
those pointers separately. Researchers using element counts as a
coverage metric should attribute the asymmetry to design intent, not
corpus completeness.

### Encoding strategy varies across the corpus

Some frameworks encode pedagogical or specification detail in numbered
standards (NICE, DCWF, the body of DigComp); others encode it in prose
(“such as” lists, “including” patterns, semicolon-delimited examples)
inside element-text literals. Cyber.org K-12 most strongly: 100% of its
standards have a “Clarification statement:” segment with enumerated
examples scaffolding teacher level-of-rigor expectations. SFIA 9 and
CSTA modestly: example clauses are illustrative more than enumerative.
The cybedtools sub-point parser lifts these prose enumerations to
first-class graph elements (the `cybed:Subpoint` type), with
`cybed:elaborates` linking each sub-point back to its parent.

A caveat for interpretation: Cyber.org and CSTA’s Clarification
statements are formally teacher-facing scaffolding, not enumerable
sub-standards. A teacher who teaches one example has met the standard.
The current schema types promoted sub-points as if they were
sub-standards (a roughly 4x inflation for Cyber.org K-12), which
materially overstates what the framework expects when the goal is to
count required learning. Treat the inflated counts as a fine-grained
search index, not a measure of required coverage.

### The five highest-element-load NICE work roles concentrate disproportionate specification

Security Control Assessment (307 elements), Secure Systems Development
(232), Cybersecurity Architecture (219), Defensive Cybersecurity (206),
and Systems Security Management (204). Curricula that “cover NICE” by
surveying these five look thorough; curricula that cover the long tail
of 41 roles look thin by element count alone. This is a property of
NICE’s internal weighting, not a finding about the corpus.

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

Density varies dramatically across heterogeneous denominators. DCWF has
2,945 elements across 74 work roles (about 40 per work role). NICE has
2,115 elements across 41 work roles (about 52 per work role). At the
other end, DigComp 2.2 has 21 elements across 5 competence areas (about
4 per area). A schema that generalizes across both extremes is doing
real work. v0.1.1’s sub-point parser surfaces additional granularity
hidden in prose for Cyber.org K-12 (500 leaf elements, ~4.3 per
grade-band cluster), SFIA 9 (830 leaf elements, ~5.6 per skill), CSTA,
ECSF, NICE, and CSEC2017. DCWF and DigComp 2.2 produce no sub-points
because their source-text formats encode each statement atomically.

The same numbers, plotted from
[`cybedtools::framework_summary`](https://ryanstraight.github.io/cybedtools/reference/framework_summary.md)
(no staged graph required, since the data object ships with the
package). Hover for role and element counts:

``` r

library(ggplot2)
library(plotly)

# Hover text built from per-framework metadata so readers can verify the
# cross-framework density spread directly from the chart, without scanning a tibble.
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
# Surfaces the ~14:1 US-vs-EU asymmetry in the corpus.
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
