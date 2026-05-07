# Eight-framework summary tibble

One row per framework in the cybedtools corpus. Counts (`role_count`,
`element_count`, `elements_per_role`) are computed from the staged
combined N-Triples graph at package-build time via
`data-raw/build-framework-summary.R`. Display name, framework type
(workforce vs. pedagogy), and license are hand-curated because they
originate outside the JSON-LD graph (license terms come from each
framework's own materials; the workforce/pedagogy distinction is a
cybedtools-side classification).

## Usage

``` r
framework_summary
```

## Format

A tibble with 8 rows and 8 columns.

- framework_slug:

  Character. Stable slug used as the URI tail (e.g., `"nice-v2"`,
  `"sfia-9"`).

- framework_name:

  Character. Short display name suitable for tables and prose.

- framework_type:

  Character. One of `"workforce"` or `"pedagogy"`.

- jurisdiction:

  Character. One of `"US"`, `"EU"`, or `"global"`.

- role_count:

  Integer. Distinct roles bound to the framework via `cybed:partOf` in
  the assembled graph.

- element_count:

  Integer. Distinct role elements bound to the framework via
  `cybed:partOf`.

- elements_per_role:

  Numeric. `element_count / role_count`, rounded to one decimal.
  Surfaces specification density across frameworks of different
  structural types.

- license:

  Character. Distribution license as published by the framework owner.

## Source

Computed from the eight-framework combined graph produced by
`scripts/025-export-ntriples.R`. See
`data-raw/build-framework-summary.R`.

## Examples

``` r
framework_summary
#> # A tibble: 8 × 8
#>   framework_slug    framework_name        framework_type jurisdiction role_count
#>   <chr>             <chr>                 <chr>          <chr>             <int>
#> 1 nice-v2           NICE v2               workforce      US                   41
#> 2 dcwf-v5.1         DCWF v5.1             workforce      US                   74
#> 3 ecsf-v1           ECSF v1               workforce      EU                   12
#> 4 sfia-9            SFIA 9                workforce      global              147
#> 5 cyberorg-k12-v1.0 Cyber.org K-12 v1.0   pedagogy       US                  116
#> 6 csta-2017         CSTA K-12 CS (Rev 20… pedagogy       US                   25
#> 7 csec2017-v1       ACM/IEEE CSEC2017     pedagogy       global                8
#> 8 digcomp-2.2       DigComp 2.2           pedagogy       EU                    5
#> # ℹ 3 more variables: element_count <int>, elements_per_role <dbl>,
#> #   license <chr>
subset(framework_summary, framework_type == "workforce")
#> # A tibble: 4 × 8
#>   framework_slug framework_name framework_type jurisdiction role_count
#>   <chr>          <chr>          <chr>          <chr>             <int>
#> 1 nice-v2        NICE v2        workforce      US                   41
#> 2 dcwf-v5.1      DCWF v5.1      workforce      US                   74
#> 3 ecsf-v1        ECSF v1        workforce      EU                   12
#> 4 sfia-9         SFIA 9         workforce      global              147
#> # ℹ 3 more variables: element_count <int>, elements_per_role <dbl>,
#> #   license <chr>
```
