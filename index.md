# cybedtools

> [Concordance](https://ryanstraight.github.io/cybedtools/concordance/)
> renders the framework data, the cross-framework comparisons, and the
> working scenarios without requiring R. Cite Concordance for site
> content, and cybedtools for the methodology and any element-level
> analysis.

A corpus of cybersecurity workforce and learning frameworks. Each
carries a different schema and a different vocabulary. Comparing them
(what’s specified where, where they overlap, how their structural
commitments differ) has historically meant rebuilding the comparison
from scratch every time, in a spreadsheet.

cybedtools makes the comparison one simple query.

The package ingests seven workforce competency frameworks
([NICE](https://www.nist.gov/itl/applied-cybersecurity/nice/nice-framework-resource-center),
[DCWF](https://www.cyberworkforce.mil/Department-Cyber-Workforce-Framework/),
[SFIA](https://sfia-online.org/en), [ENISA
ECSF](https://www.enisa.europa.eu/topics/skills-and-competences/skills-development/european-cybersecurity-skills-framework-ecsf),
the Czech [CyQUAL](https://platform.cyqual.cz/en), the [Canadian Cyber
Security Skills
Framework](https://www.cyber.gc.ca/en/education-community/cyber-skills-development/canadian-cyber-security-skills-framework),
and Singapore’s
[OTCCF](https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/))
and four pedagogical or learning-standards frameworks ([Cyber.org
K-12](https://cyber.org/k-12-cybersecurity-learning-standards), [CSTA
K-12 CS](https://csteachers.org/2017standards/interactive/), [ACM/IEEE
CSEC2017](https://cybered.acm.org/), [JRC DigComp
2.2](https://joint-research-centre.ec.europa.eu/scientific-activities/key-competences-lifelong-learning/digital-competence-framework-digcomp_en)).
All eleven are expressed in a shared `cybed:` semantic schema. A small
set of R helpers queries across them as if they were one corpus.

It does not propose a replacement framework or attempt to re-author
framework content. Existing frameworks retain their structure and
vocabulary. The package adds a comparison layer.

A native Python package is in development. The name is reserved on
[PyPI](https://pypi.org/project/cybedtools/).

The documentation is indexed in
[Context7](https://context7.com/ryanstraight/cybedtools) and published
as [llms.txt](https://ryanstraight.github.io/cybedtools/llms.txt) for AI
assistants.

Who it’s for:

- cybersecurity education researchers comparing curricula across
  frameworks
- workforce-development analysts mapping job roles to training
  requirements
- framework authors and revisers checking structural coverage against
  peer frameworks
- doctoral students writing dissertations that need cross-framework
  empirical claims

| Framework | Type | Jurisdiction | Top-level units | Elements | License |
|----|----|----|----|----|----|
| NICE v2.2.0 | workforce | US | 53 | 2,225 | US public domain + NIST worldwide grant |
| DCWF v5.1 | workforce | US | 74 | 4,052 | US Government work, no US copyright |
| ECSF v1 | workforce | EU | 12 | 390 | CC BY 4.0 (report); data files unmarked |
| SFIA 9 | workforce | global | 147 | 821 | SFIA Foundation licence required |
| Cyber.org K-12 v1.0 | pedagogy | US | 116 | 492 | CC BY-NC 4.0 |
| CSTA K-12 CS (Rev 2017) | pedagogy | US | 25 | 258 | CC BY-NC-SA 4.0 |
| ACM/IEEE CSEC2017 | pedagogy | global | 8 | 40 | All rights reserved; educational use |
| DigComp 2.2 | pedagogy | EU | 5 | 21 | CC BY 4.0 |
| CyQUAL 1.2.0 | workforce | CZ | 161 | 3,340 | Open data, attribution required |
| CCSSF 2022 | workforce | CA | 59 | 1,345 | Government of Canada copyright |
| OTCCF v1.1 | workforce | SG | 61 | 1,612 | CSA copyright; non-commercial academic |

The “Top-level units” column reports each framework’s own top-level
enumerated unit, and those units are not the same kind of thing. NICE,
DCWF, ECSF, CyQUAL, the Canadian framework, and OTCCF declare roles.
SFIA declares skills, CSEC2017 declares Knowledge Areas, DigComp 2.2
declares competence areas, and Cyber.org K-12 and CSTA use unnamed
groupings that cybedtools labels `StandardGroup`. All of them subclass
`cybed:OrganizingUnit`, so cross-framework queries reach them uniformly.
How the “Elements” column counts, and how `framework_summary` reports
strict, augmented, and per-role totals, is in
[`docs/framework-data-sources.md`](https://ryanstraight.github.io/cybedtools/docs/framework-data-sources.md).

## What you could not do before

Counting what is in a framework is easy. Download it and count. The
harder questions run across frameworks, and those used to mean parsing a
NIST JSON file, a DoD spreadsheet, a SQLite database, an open-data
export and two PDFs into one shape before the first comparison.
cybedtools does that part. Three examples follow. Each runs in about a
second.

### Which frameworks are made of the same sentences?

``` r

library(cybedtools)
library(dplyr)
library(stringr)

rdf <- load_combined_ntriples_graph()

statements <- element_framework_bindings(rdf) |>
  anti_join(subpoint_framework_bindings(rdf), by = c("element" = "subpoint")) |>
  anti_join(example_framework_bindings(rdf), by = c("element" = "example")) |>
  inner_join(element_text(rdf), by = "element") |>
  mutate(
    text = text |>
      str_to_lower() |>
      str_remove("^\\s*\\*\\s+") |>
      str_remove("[[:punct:]\\s]+$") |>
      str_squish()
  ) |>
  filter(nchar(text) > 15) |>
  distinct(framework_name, text)

statements |>
  inner_join(statements, by = "text", suffix = c("", "_2"),
             relationship = "many-to-many") |>
  filter(framework_name < framework_name_2) |>
  count(framework_name, framework_name_2, sort = TRUE) |>
  slice_head(n = 6)
#> # A tibble: 6 × 3
#>   framework_name                                          framework_name_2     n
#>   <chr>                                                   <chr>            <int>
#> 1 CyQUAL 1.2.0                                            DCWF v5.1         1400
#> 2 CyQUAL 1.2.0                                            ECSF v1            132
#> 3 CyQUAL 1.2.0                                            NICE v2.2.0 (NI…   100
#> 4 DCWF v5.1                                               NICE v2.2.0 (NI…   100
#> 5 Canadian Cyber Security Skills Framework 2022 (ITSM.00… CyQUAL 1.2.0         2
#> 6 Canadian Cyber Security Skills Framework 2022 (ITSM.00… DCWF v5.1            2
```

The largest block of shared text in the corpus is between CyQUAL, the
Czech national framework, and DCWF, the US Department of Defense
framework: 1,400 statements, word for word. Neither names the other as a
source. Each shares only 100 statements with the current NICE Framework.
What they have in common is the 2017 NICE Framework. Checked against
NIST’s 2017 release, nearly all of what the two share is 2017 NICE text,
and under 5 percent of that 2017 text survives in NICE v2.2.0. The 2017
edition is better preserved in Prague and at the Pentagon than at NIST.
Canada’s framework describes itself as an adaptation of NICE and shares
under 1 percent of its statements with anything.

### Which frameworks have nothing to say about a topic?

``` r

library(purrr)

topics <- c(
  ai           = "machine learning|artificial intelligence|neural network",
  ethics       = "ethic|moral",
  cryptography = "cryptograph|encrypt",
  supply_chain = "supply chain|third.party"
)

all_text <- element_framework_bindings(rdf) |>
  inner_join(element_text(rdf), by = "element")

imap(topics, \(pattern, topic) {
  all_text |>
    summarise(
      "{topic}" := sum(str_detect(text, regex(pattern, ignore_case = TRUE))),
      .by = framework_name
    )
}) |>
  reduce(left_join, by = "framework_name") |>
  left_join(
    count(all_text, framework_name, name = "statements"),
    by = "framework_name"
  ) |>
  relocate(statements, .after = framework_name) |>
  arrange(desc(statements)) |>
  print(n = Inf)
#> # A tibble: 11 × 6
#>    framework_name              statements    ai ethics cryptography supply_chain
#>    <chr>                            <int> <int>  <int>        <int>        <int>
#>  1 DCWF v5.1                         4052    24     12           52           18
#>  2 CyQUAL 1.2.0                      3340     1      9           29           18
#>  3 NICE v2.2.0 (NIST SP 800-1…       2225     2      3           26           22
#>  4 Operational Technology Cyb…       1612     1      6           31           12
#>  5 Canadian Cyber Security Sk…       1345     0      5           36           29
#>  6 SFIA 9                             821     6     15            0           11
#>  7 Cyber.org K-12 Learning St…        492     0      8           10            0
#>  8 ECSF v1                            390     0      4            0            1
#>  9 CSTA K-12 Computer Science…        258     2      8            3            0
#> 10 CSEC2017 Curricular Guidel…         40     0      3            1            1
#> 11 DigComp 2.2                         21     0      0            0            0
```

Five of the eleven frameworks contain no statement that mentions
artificial intelligence or machine learning. DCWF has 24 such
statements, more than the other ten frameworks combined. NICE has three
statements that mention ethics, out of 2,225. SFIA, ECSF and DigComp
have none that mention cryptography.

This measures the words a framework uses. It does not measure what a
framework covers. OTCCF is a framework about operational technology and
scores zero on the phrase “operational technology”, because CSA writes
“OT”. A zero in this table is a reason to go and read the framework.

### Which frameworks reuse statements across roles?

``` r

role_element_bindings(rdf) |>
  semi_join(role_framework_bindings(rdf), by = "role") |>
  count(element, name = "n_roles") |>
  inner_join(element_framework_bindings(rdf), by = "element") |>
  summarise(
    statements    = n(),
    mean_roles    = round(mean(n_roles), 1),
    max_roles     = max(n_roles),
    used_once_pct = round(100 * mean(n_roles == 1)),
    .by = framework_name
  ) |>
  arrange(desc(mean_roles))
#> # A tibble: 6 × 5
#>   framework_name                   statements mean_roles max_roles used_once_pct
#>   <chr>                                 <int>      <dbl>     <int>         <dbl>
#> 1 CyQUAL 1.2.0                           3151        5          50            33
#> 2 NICE v2.2.0 (NIST SP 800-181 Re…       1877        2.9        41            51
#> 3 DCWF v5.1                              4052        2.4        74            55
#> 4 ECSF v1                                 390        1           1           100
#> 5 Canadian Cyber Security Skills …       1345        1           1           100
#> 6 Operational Technology Cybersec…        270        1           1           100
```

Three of the role-based frameworks attach one statement to many roles.
Three never do. In DCWF, 8 statements are attached to all 74 work roles,
which makes them a common core the framework does not name. In CyQUAL
the most widely shared statement reaches 50 of 102 roles. In ECSF, CCSSF
and OTCCF every statement belongs to exactly one role, so “how many
roles need this skill” cannot be answered from those frameworks’ own
data, and an element count does not show the difference. OTCCF’s row
counts the key tasks attached to its job roles. Its skill statements
attach to skills.

## Finding things with `cybedtools`

The frameworks in the corpus were authored independently, for different
audiences, at different times and with different units of analysis (work
role, skill level, competence, learning standard, Knowledge Area,
competence area). They specify in different formats and under different
licenses. They do not agree on what to count. cybedtools makes them
queryable in one graph anyway. Three findings follow.

### Per-unit density varies by 13x across the corpus

DCWF v5.1 expresses 54.8 elements per top-level unit. Cyber.org K-12
v1.0 expresses 4.2. The spread reflects design philosophy more than
completeness. NICE and DCWF are granular by intent, as the basis for
hiring and training pipelines. ENISA’s ECSF and JRC’s DigComp are
high-level by intent, as an interoperability frame and a citizen
self-assessment instrument. Per-unit density is a comparison aid across
unlike denominators. It is not a quality claim. `framework_summary` also
carries a `_strict` variant for analyses that prefer each framework’s
own count.

### US frameworks are about 48 percent of the corpus, and NICE’s reach is wider than that

The corpus spans 6 jurisdictions and 14,596 elements, counted with
parsed examples included. US frameworks (NICE v2.2.0, DCWF v5.1,
Cyber.org K-12 v1.0, CSTA K-12 CS (Rev 2017)) contribute 7,027 of them.
The two EU-level frameworks (ECSF v1 and DigComp 2.2) contribute 411,
which reflects design intent: ECSF profiles point to e-CF 4.0
competences instead of restating them, and DigComp 2.2’s annex examples
are not yet extracted. Counting by jurisdiction understates how far one
framework travels. Canada’s framework describes itself as an adaptation
of NICE for the Canadian labour market and cites NICE work roles
throughout. CyQUAL says its structure and elements were adopted from
NICE, and its task list carries the 2017 NICE task codes. Both describe
the borrowing openly. The graph makes it countable. Element counts used
as a coverage metric are evidence of lineage and design, and they do not
measure how much work a framework represents.

### Five NICE work roles carry a disproportionate share of the specification

Security Control Assessment (304 elements), Secure Systems Development
(237), Cybersecurity Architecture (218), Defensive Cybersecurity (205),
Systems Security Management (201). Curricula that “cover NICE” by
surveying these five look thorough. Curricula that cover the long tail
of 42 work roles look thin by element count alone. This describes NICE’s
internal weighting and says nothing about the rest of the corpus.

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

The same helpers run against the staged framework graph by swapping
[`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)
for
[`load_combined_ntriples_graph()`](https://ryanstraight.github.io/cybedtools/reference/load_combined_ntriples_graph.md).

## A query against the framework corpus

Once the combined graph is staged (see [Getting
started](#getting-started)), one expression returns per-unit density per
framework, sorted descending:

``` r

rdf <- load_combined_ntriples_graph()

organizing_unit_framework_bindings(rdf) |>
  count(framework_name, name = "top_level_unit_count") |>
  left_join(
    element_framework_bindings(rdf) |>
      count(framework_name, name = "element_count"),
    by = "framework_name"
  ) |>
  mutate(elements_per_unit = round(element_count / top_level_unit_count, 1)) |>
  arrange(desc(elements_per_unit))
#> # A tibble: 11 × 4
#>   framework_name            top_level_unit_count element_count elements_per_unit
#>   <chr>                                    <int>         <int>             <dbl>
#> 1 DCWF v5.1                                   74          4052              54.8
#> 2 NICE v2.2.0 (NIST SP 800…                   53          2225              42  
#> 3 ECSF v1                                     12           390              32.5
#> 4 Operational Technology C…                   61          1612              26.4
#> 5 Canadian Cyber Security …                   59          1345              22.8
#> 6 CyQUAL 1.2.0                               161          3340              20.7
#> 7 CSTA K-12 Computer Scien…                   25           258              10.3
#> 8 SFIA 9                                     147           821               5.6
#> # ℹ 3 more rows
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

The package **does not** redistribute source framework text. To run the
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
or run `citation("cybedtools")` for the canonical citation. Dropping me
a line would also be appreciated!

## License

Package code is MIT (see
[`LICENSE.md`](https://ryanstraight.github.io/cybedtools/LICENSE.md)).
Each framework retains its upstream license, and source text is not
bundled. Users stage source files locally per
[`docs/framework-data-sources.md`](https://ryanstraight.github.io/cybedtools/docs/framework-data-sources.md),
and each ingestion script writes a per-framework `provenance.yml`. See
[`LICENSING.md`](https://ryanstraight.github.io/cybedtools/LICENSING.md)
for layered guidance on academic vs. commercial use.

Three frameworks here come on terms narrower than MIT. Two of them are
represented by written permission of their stewards, and the Canadian
framework is referenced as its steward asked. Those terms were given to
cybedtools and do not pass to you.

- Derived from the Operational Technology Cybersecurity Competency
  Framework (OTCCF), published by the Cyber Security Agency of Singapore
  (CSA). Available at:
  <https://www.csa.gov.sg/resources/publications/operational-technology-cybersecurity-competency-framework--otccf-/>
  CSA’s permission covers the framework’s structure, for non-commercial,
  academic and research use.
- Canadian Centre for Cyber Security, The Canadian Cyber Security Skills
  Framework (ITSM.00.039), 2022 edition. Copyright Government of Canada.
  Referenced as the Canadian Centre for Cyber Security asked.
- CyQUAL, the Czech national cybersecurity qualifications framework,
  developed at Masaryk University. Open data, version 1.2.0,
  <https://platform.cyqual.cz/>.

## Code of Conduct

Please note that the cybedtools project is released with a [Contributor
Code of
Conduct](https://ryanstraight.github.io/cybedtools/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
