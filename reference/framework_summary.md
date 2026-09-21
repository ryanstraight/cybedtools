# Framework summary tibble

One row per framework in the cybedtools corpus. All count columns are
computed from the staged combined N-Triples graph at package-build time
via `data-raw/build-framework-summary.R`. Display name, framework type
(workforce vs pedagogy), and license are hand-curated because they
originate outside the JSON-LD graph.

## Usage

``` r
framework_summary
```

## Format

A tibble with 14 rows and 16 columns.

- framework_slug:

  Character. Stable slug used as the URI tail (e.g., `"nice-v2"`,
  `"sfia-9"`, `"otccf-v1.1"`). Unique.

- framework_name:

  Character. Short curated display name suitable for tables and prose.
  Not the graph's `schema:name` literal, which carries the full
  published title.

- framework_type:

  Character. Content-focus classification, one of `"workforce"` or
  `"pedagogy"`. Independent of the structural `cybed:Role` vs
  `cybed:OrganizingUnit` distinction.

- jurisdiction:

  Character. One of `"US"`, `"EU"`, `"CZ"`, `"CA"`, `"SG"`, `"SA"`,
  `"UK"`, or `"global"`.

- organizing_unit_count:

  Integer. Distinct subjects typed `cybed:OrganizingUnit` and bound to
  the framework via `cybed:partOf`. A mixed denominator where a
  framework publishes more than one kind of unit, as described above.

- role_count:

  Integer. Distinct subjects typed `cybed:Role` and bound to the
  framework via `cybed:partOf`. A subset of `organizing_unit_count`.
  `NA` for the frameworks that assert no roles at all (SFIA, Cyber.org
  K-12, CSTA 2017, CSTA 2026, CSEC2017, DigComp 3.0, CyBOK). `NA` rather
  than zero, because "this framework does not use the role construct" is
  a different statement from "this framework has zero roles".

- element_count_strict:

  Integer. Distinct parent elements only. Equals
  `element_count_with_examples` less `subpoint_count` less
  `example_count`. Use this column when the comparison must exclude both
  enumeration splitting and pedagogical scaffolding.

- subpoint_count:

  Integer. Distinct `cybed:Subpoint` instances: enumeration-list splits
  parsed out of a parent's text at assembly time, plus sub-points the
  source itself prints or draws beneath a parent: CCSSF's sub-bullets
  and CyBOK's Indicative Material. Zero where the parser is disabled and
  the source has none (OTCCF, csta-2026, DigComp 3.0, SCyWF) or where
  the parser finds nothing.

- example_count:

  Integer. Distinct `cybed:Example` instances: Clarification-statement
  scaffolding for Cyber.org K-12 and CSTA 2017, and published
  implementation examples for CSTA 2026. Zero everywhere else.

- element_count_with_examples:

  Integer. Distinct elements typed `cybed:RoleElement` and bound to the
  framework: parents plus Subpoints plus Examples.

- unit_relation_count:

  Integer. Distinct `cybed:UnitRelation` nodes bound to the framework:
  qualified unit-to-unit statements, each carrying its published
  proficiency level. Nonzero for OTCCF only
  (role-to-Technical-Skill-Competency plus role-to-Critical-Core-Skill
  relations), zero everywhere else, since no other framework in the
  corpus publishes a skills map of this shape.

- elements_per_organizing_unit_strict:

  Numeric. `element_count_strict / organizing_unit_count`, rounded to
  one decimal. The supplementary density figure, reported in the
  cross-framework-analysis vignette.

- elements_per_organizing_unit_with_examples:

  Numeric. `element_count_with_examples / organizing_unit_count`,
  rounded to one decimal. The headline density figure used in the
  README. The vignette shows it alongside the strict column to make
  visible how Examples inflate the apparent specification density of
  Cyber.org K-12 and both CSTA editions.

- elements_per_role_strict:

  Numeric. The count of DISTINCT parent elements reachable by
  `cybed:hasElement` from a role-typed organizing unit, divided by
  `role_count`, rounded to one decimal. `NA` where `role_count` is `NA`.
  Distinct, not summed per role, because NICE, CyQUAL and DCWF share
  statements across roles, so an edge count would measure reuse rather
  than coverage and would not be comparable with the per-organizing-unit
  columns.

- elements_per_role_with_examples:

  Numeric. As above but counting every element type, so parents plus
  Subpoints plus Examples reachable from role-typed units, divided by
  `role_count`. `NA` where `role_count` is `NA`.

- license:

  Character. Short licence label, **derived**: taken by slug from
  [framework_licenses](https://ryanstraight.github.io/cybedtools/reference/framework_licenses.md)`$license_short`
  when this tibble is built, never hand-typed here.
  [framework_licenses](https://ryanstraight.github.io/cybedtools/reference/framework_licenses.md)
  owns the detail, including what the source's own document says, the
  prescribed attribution wording, the public-redistribution class, the
  terms URL, and the date the terms were last read. Use
  [`cybed_license()`](https://ryanstraight.github.io/cybedtools/reference/cybed_license.md)
  to reach it. Do not treat this column as a statement of terms; it is a
  label.

## Source

Computed from the combined graph produced by
`scripts/025-export-ntriples.R`. See
`data-raw/build-framework-summary.R`.

## Details

`framework_slug` is the **versioned** slug vocabulary. A second,
**short** vocabulary is used by the public data release's files (e.g.
`"nice"` for `"nice-v2"`); see the "Two slug vocabularies" section of
[`cybed_fetch()`](https://ryanstraight.github.io/cybedtools/reference/cybed_fetch.md)
for the full mapping and which functions accept either form.

Several frameworks were added in v0.3.0 on steward terms: CyQUAL (Czech
Republic, open data, attribution to CyQUAL and Masaryk University),
CCSSF (Canada, Government of Canada copyright, used with permission of
the Canadian Centre for Cyber Security), and OTCCF (Singapore, Cyber
Security Agency of Singapore copyright, permission for non-commercial
academic and research use). The build script fails loudly in both
directions if the graph and the curated display table disagree about
which frameworks exist.

The 2026 CSTA PK-12 Computer Science Standards (`csta-2026`) were added
after v0.3.0 as a framework of their own alongside the 2017 edition
(`csta-2017`), whose row is unchanged. Its organizing units are level x
concept groups for the foundational tier and tier x specialty area
groups for the specialty tier (see `organizing_unit_count` for the
current total). Its Examples are CSTA's published implementation
examples.

The Saudi Cybersecurity Workforce Framework (`scywf-1.5`, SCyWF - 1.5 :
2026) was added after v0.3.0 by written permission of the National
Cybersecurity Authority (NCA), which requires its content to be carried
verbatim. Its organizing units span job roles, competency areas,
specialty areas and categories (see `organizing_unit_count` and
`role_count` for current totals). Only the job roles assert
`cybed:Role`. The links from a specialty area to its category and from a
role to its specialty area are cybedtools-derived, not NCA content.

The Cyber Security Body of Knowledge (`cybok-v1.1.0`, CyBOK v1.1.0, July
2021) was added after v0.3.0 under the Open Government Licence v3.0. Its
organizing units are its Knowledge Areas, which assert no `cybed:Role`.
Its parent elements are the Topics of each KA's Knowledge Tree, and the
Indicative Material the trees draw under each Topic is carried as
`cybed:Subpoint`. Those Subpoints are source-drawn, not parser output.

Statement codes are unique only within a framework. NICE, CCSSF and
SCyWF all print codes in the T0516 shape, and they denote different
statements. SCyWF reuses a block of NICE v2.2.0 codes and prints
different text under every one of them. Never join two frameworks on a
bare statement code. Join on the full IRI, or carry a framework column
alongside the code.

## What the element counts mean

`element_count_with_examples` counts every `cybed:RoleElement` bound to
the framework: parents, plus `cybed:Subpoint` children, plus
`cybed:Example` children. `element_count_strict` counts parents only,
that is with-examples less both the Subpoint and the Example
populations. OTCCF, csta-2026, DigComp 3.0 and SCyWF have zero Subpoints
(parser disabled for all four on fidelity grounds. See
docs/framework-invariants.yml). CyBOK runs with the parser disabled too,
and its Subpoints are the Indicative Material its Knowledge Trees draw.
Only OTCCF and SCyWF have zero of both children, so strict equals
with-examples there. DigComp 3.0 still has a nonzero `example_count`
with the parser off: its Learning Outcomes attach as `cybed:Example`
children of each Competence unit, so strict is less than with-examples
there.

`element_count_strict` excludes both `cybed:Subpoint` and
`cybed:Example` content; see NEWS.md for the 2026-08-14 correction to
this definition. The README headline "density spread" finding uses the
with-examples count, which counts what each framework puts in front of a
teacher, trainee, or curriculum designer. The strict count is the
supplementary figure, reported in the cross-framework-analysis vignette.

The related count in `docs/framework-invariants.yml`,
`total_elements_with_subpoints`, is parents plus Subpoints excluding
Examples. This tibble's `element_count_strict` is parents only.

## Units, roles, and density

`organizing_unit_count` counts every `cybed:OrganizingUnit`, which for
several frameworks mixes more than one kind of unit: NICE contributes
work roles plus competency areas, CyQUAL work roles plus competencies,
OTCCF job roles plus Technical Skills and Competencies plus Critical
Core Skills, SCyWF job roles plus competency areas, specialty areas and
categories (see `organizing_unit_count` and `role_count` for the current
per-framework split). A density taken over that mixed denominator is not
like-for-like against a framework whose units are all roles, such as
DCWF. The `role_count` and `elements_per_role_*` columns added in v0.3.0
give the role-only cut. The `elements_per_organizing_unit_*` columns
keep the definition they have always had, because they are published
figures.

The `framework_type` column denotes content focus (workforce
competencies vs educational standards), not the structural distinction
that drives `cybed:Role` assertion. SFIA carries
`framework_type == "workforce"` because it specifies workforce skills,
but its parent units assert `cybed:OrganizingUnit` only (not
`cybed:Role`) because SFIA enumerates skills rather than work roles, so
its `role_count` is `NA`. For structural questions, query `cybed:Role`
and `cybed:OrganizingUnit` directly.

## Examples

``` r
framework_summary
#> # A tibble: 14 × 16
#>    framework_slug    framework_name          framework_type jurisdiction
#>    <chr>             <chr>                   <chr>          <chr>       
#>  1 nice-v2           NICE v2.2.0             workforce      US          
#>  2 dcwf-v5.1         DCWF v5.1               workforce      US          
#>  3 ecsf-v1           ECSF v1                 workforce      EU          
#>  4 sfia-9            SFIA 9                  workforce      global      
#>  5 cyberorg-k12-v1.0 Cyber.org K-12 v1.0     pedagogy       US          
#>  6 csta-2017         CSTA K-12 CS (Rev 2017) pedagogy       US          
#>  7 csec2017-v1       ACM/IEEE CSEC2017       pedagogy       global      
#>  8 digcomp-3.0       DigComp 3.0             pedagogy       EU          
#>  9 cyqual-v1.2.0     CyQUAL 1.2.0            workforce      CZ          
#> 10 ccssf-2022        CCSSF 2022              workforce      CA          
#> 11 otccf-v1.1        OTCCF v1.1              workforce      SG          
#> 12 csta-2026         CSTA PK-12 CS (2026)    pedagogy       US          
#> 13 scywf-1.5         SCyWF 1.5               workforce      SA          
#> 14 cybok-v1.1.0      CyBOK v1.1.0            pedagogy       UK          
#> # ℹ 12 more variables: organizing_unit_count <int>, role_count <int>,
#> #   element_count_strict <int>, subpoint_count <int>, example_count <int>,
#> #   element_count_with_examples <int>, unit_relation_count <int>,
#> #   elements_per_organizing_unit_strict <dbl>,
#> #   elements_per_organizing_unit_with_examples <dbl>,
#> #   elements_per_role_strict <dbl>, elements_per_role_with_examples <dbl>,
#> #   license <chr>
subset(framework_summary, framework_type == "workforce")
#> # A tibble: 8 × 16
#>   framework_slug framework_name framework_type jurisdiction
#>   <chr>          <chr>          <chr>          <chr>       
#> 1 nice-v2        NICE v2.2.0    workforce      US          
#> 2 dcwf-v5.1      DCWF v5.1      workforce      US          
#> 3 ecsf-v1        ECSF v1        workforce      EU          
#> 4 sfia-9         SFIA 9         workforce      global      
#> 5 cyqual-v1.2.0  CyQUAL 1.2.0   workforce      CZ          
#> 6 ccssf-2022     CCSSF 2022     workforce      CA          
#> 7 otccf-v1.1     OTCCF v1.1     workforce      SG          
#> 8 scywf-1.5      SCyWF 1.5      workforce      SA          
#> # ℹ 12 more variables: organizing_unit_count <int>, role_count <int>,
#> #   element_count_strict <int>, subpoint_count <int>, example_count <int>,
#> #   element_count_with_examples <int>, unit_relation_count <int>,
#> #   elements_per_organizing_unit_strict <dbl>,
#> #   elements_per_organizing_unit_with_examples <dbl>,
#> #   elements_per_role_strict <dbl>, elements_per_role_with_examples <dbl>,
#> #   license <chr>
subset(framework_summary, !is.na(role_count))
#> # A tibble: 7 × 16
#>   framework_slug framework_name framework_type jurisdiction
#>   <chr>          <chr>          <chr>          <chr>       
#> 1 nice-v2        NICE v2.2.0    workforce      US          
#> 2 dcwf-v5.1      DCWF v5.1      workforce      US          
#> 3 ecsf-v1        ECSF v1        workforce      EU          
#> 4 cyqual-v1.2.0  CyQUAL 1.2.0   workforce      CZ          
#> 5 ccssf-2022     CCSSF 2022     workforce      CA          
#> 6 otccf-v1.1     OTCCF v1.1     workforce      SG          
#> 7 scywf-1.5      SCyWF 1.5      workforce      SA          
#> # ℹ 12 more variables: organizing_unit_count <int>, role_count <int>,
#> #   element_count_strict <int>, subpoint_count <int>, example_count <int>,
#> #   element_count_with_examples <int>, unit_relation_count <int>,
#> #   elements_per_organizing_unit_strict <dbl>,
#> #   elements_per_organizing_unit_with_examples <dbl>,
#> #   elements_per_role_strict <dbl>, elements_per_role_with_examples <dbl>,
#> #   license <chr>
```
