# Look up the licence terms for the package or one framework

**\[experimental\]**

Returns rows of
[framework_licenses](https://ryanstraight.github.io/cybedtools/reference/framework_licenses.md),
the package's single owner of licence facts. Called with no argument it
returns the whole tibble: one row for the package's own code and one row
per framework. Called with a slug it returns that one row.

The `license_short` column is the short label that
[framework_summary](https://ryanstraight.github.io/cybedtools/reference/framework_summary.md)`$license`
is derived from. The `license` column holds what the source's own
document or terms page says, quoted and attributed to the document it
was read from. The `attribution` column holds the wording to reproduce
when the framework's content is used: the steward's own wording verbatim
where one is prescribed, a minimal attribution composed by the package
where the licence requires credit but the steward prescribes no wording,
and `NA` where neither applies. The `license` cell says which of the two
a given row carries.

## Usage

``` r
cybed_license(slug = NULL)
```

## Arguments

- slug:

  Character scalar, or `NULL`. Either `"cybedtools"` for the package's
  own code, a framework slug as carried by
  [framework_summary](https://ryanstraight.github.io/cybedtools/reference/framework_summary.md)`$framework_slug`
  (for example `"nice-v2"`, `"otccf-v1.1"`), or the short release-file
  slug (e.g. `"nice"`, `"otccf"`) documented on
  [`cybed_fetch()`](https://ryanstraight.github.io/cybedtools/reference/cybed_fetch.md).
  Either form resolves to the same row. `NULL`, the default, returns
  every row.

## Value

A tibble. One row per licence layer when `slug` is `NULL`, and a
single-row tibble otherwise.

## See also

Other licensing:
[`framework_licenses`](https://ryanstraight.github.io/cybedtools/reference/framework_licenses.md)

## Examples

``` r
cybed_license()
#> # A tibble: 15 × 10
#>    layer     slug              framework_name  license_short license attribution
#>    <chr>     <chr>             <chr>           <chr>         <chr>   <chr>      
#>  1 code      cybedtools        cybedtools (R … MIT           "LICEN… Copyright …
#>  2 framework nice-v2           NICE v2.2.0     US public do… "The i… NA         
#>  3 framework dcwf-v5.1         DCWF v5.1       US Governmen… "The D… NA         
#>  4 framework ecsf-v1           ECSF v1         CC BY 4.0 (r… "Two t… European U…
#>  5 framework sfia-9            SFIA 9          SFIA Foundat… "SFIA … NA         
#>  6 framework cyberorg-k12-v1.0 Cyber.org K-12… CC BY-NC 4.0  "From … K-12 Cyber…
#>  7 framework csta-2017         CSTA K-12 CS (… CC BY-NC-SA … "The i… Computer S…
#>  8 framework csta-2026         CSTA PK-12 CS … CC BY-NC-SA … "From … Computer S…
#>  9 framework csec2017-v1       ACM/IEEE CSEC2… All rights r… "From … NA         
#> 10 framework digcomp-3.0       DigComp 3.0     CC BY 4.0     "From … Cosgrove, …
#> 11 framework cyqual-v1.2.0     CyQUAL 1.2.0    Open data, a… "The o… CyQUAL, th…
#> 12 framework ccssf-2022        CCSSF 2022      Government o… "The C… Canadian C…
#> 13 framework otccf-v1.1        OTCCF v1.1      CSA copyrigh… "\"(c)… Derived fr…
#> 14 framework scywf-1.5         SCyWF 1.5       NCA written … "The S… The Saudi …
#> 15 framework cybok-v1.1.0      CyBOK v1.1.0    OGL v3.0      "From … CyBOK © Cr…
#> # ℹ 4 more variables: public_redistribution <chr>, terms_url <chr>,
#> #   granted <lgl>, verified <date>
cybed_license("otccf-v1.1")
#> # A tibble: 1 × 10
#>   layer     slug       framework_name license_short          license attribution
#>   <chr>     <chr>      <chr>          <chr>                  <chr>   <chr>      
#> 1 framework otccf-v1.1 OTCCF v1.1     CSA copyright; non-co… "\"(c)… Derived fr…
#> # ℹ 4 more variables: public_redistribution <chr>, terms_url <chr>,
#> #   granted <lgl>, verified <date>
cybed_license("cybedtools")$license_short
#> [1] "MIT"

# Which frameworks may not be redistributed publicly at all?
lic <- cybed_license()
lic$slug[lic$public_redistribution == "local_only"]
#> [1] "sfia-9"
```
