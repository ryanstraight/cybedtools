

<!-- README.md is generated from README.qmd. Please edit README.qmd and run `quarto render README.qmd` to regenerate. -->

# cybedtools <a href="https://ryanstraight.github.io/cybedtools/"><img src="man/figures/logo.png" align="right" height="139" alt="cybedtools website" /></a>

<!-- badges: start -->

[![R-CMD-check](https://github.com/ryanstraight/cybedtools/actions/workflows/r-cmd-check.yaml/badge.svg)](https://github.com/ryanstraight/cybedtools/actions/workflows/r-cmd-check.yaml)
[![test-coverage](https://github.com/ryanstraight/cybedtools/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/ryanstraight/cybedtools/actions/workflows/test-coverage.yaml)
[![Codecov test
coverage](https://codecov.io/gh/ryanstraight/cybedtools/graph/badge.svg)](https://app.codecov.io/gh/ryanstraight/cybedtools)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![License:
MIT](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/license/MIT)
[![R \>=
4.1](https://img.shields.io/badge/R-%3E%3D%204.1-276DC3.svg?logo=r)](https://www.r-project.org/)
[![DOI](https://zenodo.org/badge/1232333517.svg)](https://doi.org/10.5281/zenodo.20076116)
[![Context7](https://img.shields.io/badge/Context7-indexed-4f46e5)](https://context7.com/ryanstraight/cybedtools)
<!-- badges: end -->

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

<table class="table sortable">

<thead>

<tr>

<th>

Framework
</th>

<th>

Type
</th>

<th>

Jurisdiction
</th>

<th>

Roles
</th>

<th>

Elements
</th>

<th>

License
</th>

</tr>

</thead>

<tbody>

<tr>

<td>

NICE v2
</td>

<td>

workforce
</td>

<td>

US
</td>

<td>

41
</td>

<td>

2,115
</td>

<td>

public domain
</td>

</tr>

<tr>

<td>

DCWF v5.1
</td>

<td>

workforce
</td>

<td>

US
</td>

<td>

74
</td>

<td>

2,945
</td>

<td>

public domain
</td>

</tr>

<tr>

<td>

ECSF v1
</td>

<td>

workforce
</td>

<td>

EU
</td>

<td>

12
</td>

<td>

390
</td>

<td>

CC BY 4.0
</td>

</tr>

<tr>

<td>

SFIA 9
</td>

<td>

workforce
</td>

<td>

global
</td>

<td>

147
</td>

<td>

830
</td>

<td>

SFIA Use Policy
</td>

</tr>

<tr>

<td>

Cyber.org K-12 v1.0
</td>

<td>

pedagogy
</td>

<td>

US
</td>

<td>

116
</td>

<td>

500
</td>

<td>

CC BY-NC 4.0
</td>

</tr>

<tr>

<td>

CSTA K-12 CS (Rev 2017)
</td>

<td>

pedagogy
</td>

<td>

US
</td>

<td>

25
</td>

<td>

140
</td>

<td>

CC BY-NC-SA 4.0
</td>

</tr>

<tr>

<td>

ACM/IEEE CSEC2017
</td>

<td>

pedagogy
</td>

<td>

global
</td>

<td>

8
</td>

<td>

40
</td>

<td>

ACM/IEEE educational-use
</td>

</tr>

<tr>

<td>

DigComp 2.2
</td>

<td>

pedagogy
</td>

<td>

EU
</td>

<td>

5
</td>

<td>

21
</td>

<td>

EU open re-use
</td>

</tr>

</tbody>

</table>

The “Roles” column reports each framework’s top-level organizing unit,
whatever the framework calls it: work roles for NICE / DCWF / ECSF,
skills for SFIA, level-concept buckets for CSTA, grade-band cells for
Cyber.org K-12, Knowledge Areas for CSEC2017, competence areas for
DigComp 2.2. The schema collapses these distinct structural commitments
under a single `cybed:Role` abstraction. See
`docs/framework-data-sources.md` for the per-framework structural
mapping.

## What you can find with this

The eight frameworks were authored independently, for different
audiences, at different units of analysis (work role, skill level,
competence, learning standard, Knowledge Area, competence area). They
specify in different formats, under different licenses, with different
design philosophies. They do not agree on what to count. cybedtools
makes them queryable in one graph anyway. Three findings illustrate what
that surfaces.

### Per-organizing-unit density varies by 12x across the corpus

NICE v2 expresses 51.6 elements per its top-level unit; DigComp 2.2
expresses 4.2. The spread reflects framework design philosophy more than
relative completeness: NICE / DCWF are granular by intent as the basis
for hiring and training pipelines; ENISA’s ECSF and JRC’s DigComp are
intentionally high-level as interoperability frames and citizen
self-assessment instruments. Treat per-unit density as a comparison aid,
not a quality claim.

### Jurisdictional element volume skews US-heavy 14 to 1

US frameworks (NICE v2, DCWF v5.1, Cyber.org K-12 v1.0, CSTA K-12 CS
(Rev 2017)) contribute 5,700 elements; EU frameworks (ECSF v1 + DigComp
2.2) contribute 411. The ratio reflects design intent: ECSF profiles
embed e-CF 4.0 cross-references that cybedtools does not currently
materialize, and DigComp 2.2’s annexes carry examples-per-competence
that the package does not yet extract. Researchers using element counts
as a coverage metric should attribute the asymmetry to design philosophy
(and incomplete extraction on the EU side), not to relative effort.

### The five highest-element-load NICE work roles concentrate disproportionate specification

Security Control Assessment (307 elements), Secure Systems Development
(232), Cybersecurity Architecture (219), Defensive Cybersecurity (206),
Systems Security Management (204). Curricula that “cover NICE” by
surveying these five look thorough. Curricula that cover the long tail
of 41 roles look thin by element count alone. This is a property of
NICE’s internal weighting, not a finding about the broader corpus.

Each finding is one query and a few lines of dplyr. See below.

## Quick check after install

`make_demo_graph()` returns an in-memory two-framework synthetic graph
that exercises every domain helper without staged data. If this runs
cleanly, your install is sound:

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
`make_demo_graph()` for `load_combined_ntriples_graph()`.

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
#> 1 NICE v2 (NIST SP 800-181 Rev 1 com…         41          2115              51.6
#> 2 DCWF v5.1                                   74          2945              39.8
#> 3 ECSF v1                                     12           390              32.5
#> 4 CSTA K-12 Computer Science Standar…         25           140               5.6
#> 5 SFIA 9                                     147           830               5.6
#> 6 CSEC2017 Curricular Guidelines v1.0          8            40               5  
#> 7 Cyber.org K-12 Learning Standards …        116           500               4.3
#> 8 DigComp 2.2                                  5            21               4.2
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
[`docs/framework-data-sources.md`](docs/framework-data-sources.md):

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
[`CITATION.cff`](CITATION.cff) or run `citation("cybedtools")` for the
canonical citation.

## License

Package code is MIT (see [`LICENSE.md`](LICENSE.md)). Each framework
retains its upstream license; source text is not bundled. Users stage
source files locally per
[`docs/framework-data-sources.md`](docs/framework-data-sources.md), and
each ingestion script writes a per-framework `provenance.yml`. See
[`LICENSING.md`](LICENSING.md) for layered guidance on academic
vs. commercial use.

## Code of Conduct

Please note that the cybedtools project is released with a [Contributor
Code of
Conduct](https://ryanstraight.github.io/cybedtools/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
