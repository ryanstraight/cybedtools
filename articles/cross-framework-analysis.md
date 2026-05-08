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

DCWF declares 2,945 elements; DigComp 2.2 declares 21. Per-unit density
correspondingly spreads from NICE’s 51.6 elements per work role to
DigComp’s 4.2 elements per competence area, a roughly 12x ratio when
Cyber.org K-12 and CSTA’s Clarification-statement Examples are included.
The spread reflects each framework’s design philosophy more than care or
completeness: NICE/DCWF are granular by design as the basis for hiring
and training pipelines; ECSF and DigComp are intentionally high-level as
interoperability frames and citizen self-assessment instruments.
cybedtools does not normalize across this asymmetry; downstream analyses
that aggregate “framework coverage” should account for it explicitly.

For analyses that need to compare frameworks without including
pedagogical scaffolding, `framework_summary` carries
`elements_per_organizing_unit_strict`, which excludes `cybed:Example`
instances. Under the strict count Cyber.org K-12 drops to ~1.1 elements
per cell (numbered standards only) and the cross-framework spread widens
to ~49x; that view is structurally honest about each framework’s
normative content but invites the misreading “Cyber.org K-12 specifies
less content than NICE” when the more accurate framing is that the two
frameworks organize at different denominator granularities (work role vs
grade-band x sub-concept cell).

### The corpus skews US-heavy by element volume

US frameworks contribute the majority of strict elements (NICE, DCWF,
Cyber.org K-12, CSTA). EU frameworks (ECSF, DigComp) contribute under
one-fifteenth of that volume. The asymmetry reflects design philosophy
more than relative investment: ENISA designed ECSF as profile-level for
national elaboration, and JRC designed DigComp 2.2 as a citizen
self-assessment instrument. ECSF profiles also embed e-CF 4.0
cross-references that cybedtools does not currently materialize as
triples; full ECSF coverage requires consulting those pointers
separately. Researchers using element counts as a coverage metric should
attribute the asymmetry to design intent, not corpus completeness.

### Encoding strategy varies across the corpus

Some frameworks encode pedagogical or specification detail in numbered
standards (NICE, DCWF, the body of DigComp); others encode it in prose
(“such as” lists, “including” patterns, semicolon-delimited examples)
inside element-text literals. Cyber.org K-12 most strongly: every
numbered standard carries a “Clarification statement:” segment with
enumerated examples scaffolding teacher level-of-rigor expectations.
CSTA does the same modestly, on a subset of standards.

cybedtools’ sub-point parser lifts both pattern families to first-class
graph elements but routes them to two distinct types based on the source
framing. Framework-as-specified enumerations (“such as”, “including”,
semicolon lists in NICE / SFIA / ECSF / CSEC2017) become
`cybed:Subpoint` instances, retain their parent’s framework-native
subtype, and appear in default `cybed:hasElement` traversals.
“Clarification statement:” pedagogical scaffolding (Cyber.org K-12,
CSTA) becomes `cybed:Example` instances, carries no framework-native
subtype because the source framework treats the content as illustrative
rather than enumerable, and is reachable only via the parent’s
`cybed:hasExample` predicate. The two-type split keeps role-level “all
elements” traversals restricted to framework-as-specified content while
preserving the granular content as a queryable search index for analyses
that need it.

`framework_summary` surfaces both views: `element_count_strict` counts
parents and Subpoints only; `element_count_with_examples` adds the
Examples. The headline density figures use the strict count for
cross-framework parity. The vignette below shows both columns side by
side.

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

### Organizing-unit counts per framework

``` r

# Cross-framework parent count: every framework's top-level enumerated
# unit (work role, skill, grade-band x sub-concept cell, level x concept cell,
# Knowledge Area, competence area). The cybed:OrganizingUnit abstract
# reaches all eight frameworks in one query; cybed:Role is reserved for
# workforce frameworks (NICE / DCWF / ECSF) where the unit is genuinely a
# work role or work profile.
organizing_unit_framework_bindings(rdf) |>
  count(framework_name, sort = TRUE, name = "organizing_unit_count")

# Workforce-only cut: NICE / DCWF / ECSF only.
role_framework_bindings(rdf) |>
  count(framework_name, sort = TRUE, name = "role_count")
```

### Element volume per framework

``` r

# Strict count: parents and Subpoints only. The headline figure used to
# compare frameworks at the level of what they specify as their normative
# content.
element_framework_bindings(rdf) |>
  dplyr::anti_join(example_framework_bindings(rdf),
                   by = c("element" = "example")) |>
  count(framework_name, sort = TRUE, name = "element_count_strict")

# With-examples count: parents, Subpoints, AND Cyber.org K-12 / CSTA
# pedagogical-scaffolding Examples. Useful for granular search-index
# style work; not appropriate as a coverage metric.
element_framework_bindings(rdf) |>
  count(framework_name, sort = TRUE, name = "element_count_with_examples")
```

Density varies dramatically across heterogeneous denominators. DCWF has
2,945 elements across 74 work roles (about 40 per work role). NICE has
2,115 elements across 41 work roles (about 52 per work role). SFIA 9 has
830 leaf elements (parent skills + parsed Subpoints) across 147 skills
(~5.6 per skill). At the other end, Cyber.org K-12 has 123 strict
elements across 116 grade-band x sub-concept cells (~1.1 strict per
cell), or 500 with-Examples elements (~4.3 with-Examples per cell).
DigComp 2.2 has 21 elements across 5 competence areas (~4.2 per area). A
schema that generalizes across both extremes is doing real work.

The same numbers, plotted from
[`cybedtools::framework_summary`](https://ryanstraight.github.io/cybedtools/reference/framework_summary.md)
(no staged graph required, since the data object ships with the
package). Hover for organizing-unit and element counts:

``` r

library(ggplot2)
library(plotly)

# Hover text built from per-framework metadata so readers can verify the
# cross-framework density spread directly from the chart, without scanning a tibble.
fs <- cybedtools::framework_summary

p <- ggplot(
  fs,
  aes(
    x    = elements_per_organizing_unit_with_examples,
    y    = reorder(framework_name, elements_per_organizing_unit_with_examples),
    fill = framework_type,
    text = paste0(
      "<b>", framework_name, "</b><br>",
      organizing_unit_count, " top-level units, ",
      format(element_count_with_examples, big.mark = ","), " elements",
      ifelse(example_count > 0,
             paste0(" (incl. ", format(example_count, big.mark = ","),
                    " Clarification-statement examples)"),
             ""),
      "<br>",
      elements_per_organizing_unit_with_examples, " elements per unit<br>",
      jurisdiction, " · ", license
    )
  )
) +
  geom_col(width = 0.7) +
  scale_fill_manual(
    values = c(workforce = "#0F172A", pedagogy = "#38BDF8"),
    name   = NULL
  ) +
  labs(x = "Elements per top-level unit", y = NULL) +
  theme_minimal(base_size = 12) +
  theme(
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    legend.position    = "top"
  )

ggplotly(p, tooltip = "text") |>
  config(displayModeBar = FALSE)
```

### Largest organizing units by element count

``` r

# Cache the binding tibbles to avoid re-running queries when iterating.
reb <- role_element_bindings(rdf)
ofb <- organizing_unit_framework_bindings(rdf)

# Count elements per organizing unit, attach unit name and parent framework,
# take the heaviest 10 across the entire eight-framework graph. This is
# the cross-framework cut: it includes NICE / DCWF / ECSF work roles
# alongside SFIA skills, CSTA buckets, CSEC2017 Knowledge Areas, etc. To
# restrict to workforce frameworks only, swap organizing_unit_framework_bindings
# for role_framework_bindings.
reb |>
  count(role, name = "element_count") |>
  left_join(ofb |> select(unit, unit_name, framework_name),
            by = c("role" = "unit")) |>
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

# Compare per-unit density: NICE (role-first specification) vs SFIA
# (skill-first). NICE asserts cybed:Role on its work roles; SFIA asserts
# cybed:OrganizingUnit on its skills (skills are not roles in the
# workforce-framework sense). The cross-framework cut therefore queries
# cybed:OrganizingUnit, which reaches both.
ofb <- organizing_unit_framework_bindings(rdf)
reb <- role_element_bindings(rdf)

# Filter to the two frameworks of interest, attach element counts to each
# unit, then aggregate per-framework statistics. Useful when arguing
# about how differently the two structure their specifications.
ofb |>
  filter(framework_name %in% c("NICE v2 (NIST SP 800-181 Rev 1 components)", "SFIA 9")) |>
  left_join(reb |> count(role, name = "element_count"),
            by = c("unit" = "role")) |>
  group_by(framework_name) |>
  summarize(
    organizing_unit_count = n(),
    mean_elements         = round(mean(element_count, na.rm = TRUE), 1),
    median_elements       = median(element_count, na.rm = TRUE),
    max_elements          = max(element_count, na.rm = TRUE)
  )
```

## Going beyond the helpers: writing your own single-BGP queries

When you need data the domain helpers do not expose, drop down to the
primitives:

- `sparql_subjects(rdf, predicate, object)` returns subjects of triples
  whose predicate and object are both fixed (e.g.,
  `sparql_subjects(rdf, "a", "cybed:OrganizingUnit")` for
  cross-framework parents, `sparql_subjects(rdf, "a", "cybed:Role")` for
  the workforce-only cut, `sparql_subjects(rdf, "a", "cybed:Example")`
  for pedagogical-scaffolding nodes).
- `sparql_pairs(rdf, predicate)` returns subject-object pairs for all
  triples with a given predicate (e.g.,
  `sparql_pairs(rdf, "schema:name")`,
  `sparql_pairs(rdf, "cybed:hasExample")` for the
  parent-element-to-Example links).

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
