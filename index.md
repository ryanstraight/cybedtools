# cybedtools

Eight cybersecurity workforce and learning frameworks. Eight different
schemas, eight different vocabularies. Comparing them (what’s specified
where, where they overlap, how their structural commitments differ) has
historically meant rebuilding the comparison from scratch every time, in
a spreadsheet.

cybedtools makes the comparison one query.

The package ingests four workforce competency frameworks (NICE, DCWF,
SFIA, ENISA ECSF) and four pedagogical or learning-standards frameworks
(Cyber.org K-12, CSTA K-12 CS, ACM/IEEE CSEC2017, JRC DigComp 2.2),
expresses them all in a shared `cybed:` semantic schema, and exposes a
small set of R helpers that let you query across them as if they were
one corpus.

It does not propose a replacement framework or attempt to re-author
framework content. Existing frameworks retain their structure and
vocabulary. The package adds a comparison layer.

Who it’s for:

- cybersecurity education researchers comparing curricula across
  frameworks
- workforce-development analysts mapping job roles to training
  requirements
- framework authors and revisers checking structural coverage against
  peer frameworks
- doctoral students writing dissertations that need cross-framework
  empirical claims

| Framework | Type | Jurisdiction | Roles | Elements | License |
|----|----|----|----|----|----|
| NICE v2 | workforce | US | 41 | 2,111 | public domain |
| DCWF v5.1 | workforce | US | 74 | 2,945 | public domain |
| ECSF v1 | workforce | EU | 12 | 374 | CC BY 4.0 |
| SFIA 9 | workforce | global | 147 | 672 | SFIA non-commercial |
| Cyber.org K-12 v1.0 | pedagogy | US | 116 | 123 | CC BY-NC 4.0 |
| CSTA K-12 CS (Rev 2017) | pedagogy | US | 25 | 120 | CC BY-NC-SA 4.0 |
| ACM/IEEE CSEC2017 | pedagogy | global | 8 | 38 | ACM/IEEE educational-use |
| DigComp 2.2 | pedagogy | EU | 5 | 21 | EU open re-use |

## What you can find with this

Three findings, one R query each.

**Element density per framework varies by 50x.** NICE v2 expresses 51.5
elements per role. Cyber.org K-12 v1.0 expresses 1.1. Some of this is
framework purpose (workforce specification vs. K-12 learning outcomes).
Some is uneven specification within the same framework type. Either way,
“covers the NICE Framework” and “covers the CSEC2017 guidelines” are not
comparable curricular claims.

**Jurisdictional element coverage is dominated by US frameworks 13 to
1.** US frameworks (NICE v2, DCWF v5.1, Cyber.org K-12 v1.0, CSTA K-12
CS (Rev 2017)) contribute 5,299 elements. EU frameworks (ECSF v1 +
DigComp 2.2) contribute 395. Comparative work in cybersecurity education
has been operating against an asymmetric corpus.

**The five highest-element-load NICE work roles concentrate
disproportionate competency specification.** Security Control Assessment
(307 elements), Secure Systems Development (232), Cybersecurity
Architecture (219), Defensive Cybersecurity (206), Systems Security
Management (204). Curricula that “cover NICE” by surveying these five
roles look thorough. Curricula that cover the long tail of 41 roles look
thin by element count alone.

Each finding is one query and a few lines of dplyr. See below.

## Quick check after install

[`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)
returns an in-memory two-framework synthetic graph that exercises every
domain helper without staged data. If this runs cleanly, your install is
sound:

``` r

library(cybedtools)
library(dplyr)

rdf <- make_demo_graph()

# One row per framework with jurisdiction, sector, and specificity attached.
framework_metadata(rdf) |>
  arrange(jurisdiction, name)
#> # A tibble: 2 × 5
#>   framework                                name  jurisdiction sector specificity
#>   <chr>                                    <chr> <chr>        <chr>  <chr>      
#> 1 https://w3id.org/cybed/ontology#framewo… Demo… EU           gener… general-IT 
#> 2 https://w3id.org/cybed/ontology#framewo… Demo… US           civil… cybersecur…
```

The same helpers run against a staged eight-framework graph by swapping
[`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)
for
[`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md).

## A query against the eight-framework corpus

Once the combined graph is staged (see [Getting
started](#getting-started)), one expression returns density per
framework, sorted descending:

``` r

rdf <- load_combined_ntriples_graph()

role_framework_bindings(rdf) |>
  count(framework_name, name = "role_count") |>
  left_join(
    element_framework_bindings(rdf) |>
      count(framework_name, name = "element_count"),
    by = "framework_name"
  ) |>
  mutate(elements_per_role = round(element_count / role_count, 1)) |>
  arrange(desc(elements_per_role))
#> # A tibble: 8 × 4
#>   framework_name                      role_count element_count elements_per_role
#>   <chr>                                    <int>         <int>             <dbl>
#> 1 NICE v2 (NIST SP 800-181 Rev 1 com…         41          2111              51.5
#> 2 DCWF v5.1                                   74          2945              39.8
#> 3 ECSF v1                                     12           374              31.2
#> 4 CSEC2017 Curricular Guidelines v1.0          8            38               4.8
#> 5 CSTA K-12 Computer Science Standar…         25           120               4.8
#> 6 SFIA 9                                     147           672               4.6
#> 7 DigComp 2.2                                  5            21               4.2
#> 8 Cyber.org K-12 Learning Standards …        116           123               1.1
```

Jurisdiction pivots, top-load NICE roles, pairwise framework
comparisons, and the librdf single-BGP discipline are covered in the
[`cross-framework-analysis`](https://ryanstraight.github.io/cybedtools/articles/cross-framework-analysis.html)
vignette. Extending the schema to a new framework is covered in
[`adding-a-framework`](https://ryanstraight.github.io/cybedtools/articles/adding-a-framework.html).

## Getting started

``` r

# install.packages("remotes")
remotes::install_github("ryanstraight/cybedtools")
```

The package does not redistribute upstream framework text. To run the
pipeline end-to-end, clone the repository and stage each framework’s
source file at `data/raw/<framework>/` per
[`docs/framework-data-sources.md`](https://ryanstraight.github.io/cybedtools/docs/framework-data-sources.md):

``` sh
git clone https://github.com/ryanstraight/cybedtools
cd cybedtools

# Stage source files, then:
Rscript scripts/000-build.R   # ingestion + verification + assembly + export
```

The
[`getting-started`](https://ryanstraight.github.io/cybedtools/articles/getting-started.html)
vignette walks through each stage, and the [function
reference](https://ryanstraight.github.io/cybedtools/reference/) indexes
the public API.

## Citing

If you use cybedtools in published work, see
[`CITATION.cff`](https://ryanstraight.github.io/cybedtools/CITATION.cff)
or run `citation("cybedtools")` for the canonical citation.

## License

Package code is MIT (see
[`LICENSE.md`](https://ryanstraight.github.io/cybedtools/LICENSE.md)).
Each framework retains its upstream license; source text is not bundled.
Users stage source files locally per
[`docs/framework-data-sources.md`](https://ryanstraight.github.io/cybedtools/docs/framework-data-sources.md),
and each ingestion script writes a per-framework `provenance.yml`. See
[`LICENSE-NOTES.md`](https://ryanstraight.github.io/cybedtools/LICENSE-NOTES.md)
for layered guidance on academic vs. commercial use.

## Code of Conduct

Please note that the cybedtools project is released with a [Contributor
Code of
Conduct](https://ryanstraight.github.io/cybedtools/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
