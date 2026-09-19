# Licence facts for the package code and every framework

**\[experimental\]**

The single owner of licence facts in cybedtools. One row for the
package's own code (MIT) and one row per framework, built by
`data-raw/build-framework-licenses.R` from each source's own document,
licence file, or published terms page.
[framework_summary](https://ryanstraight.github.io/cybedtools/dev/reference/framework_summary.md)`$license`
is derived from this tibble's `license_short` column, so the short label
and the detail can never disagree. Reach a single row with
[`cybed_license()`](https://ryanstraight.github.io/cybedtools/dev/reference/cybed_license.md).

Nothing here is legal advice. The `license` column records what a source
says; deciding what that permits in your situation is your call, and for
several frameworks the honest answer is that the source says nothing and
the position is inferred.

## Usage

``` r
framework_licenses
```

## Format

A tibble with 12 rows and 10 columns.

- layer:

  Character. `"code"` for the package's own code, or `"framework"` for a
  framework's source content. Exactly one `"code"` row exists.

- slug:

  Character. `"cybedtools"` for the code row; otherwise the framework
  slug, equal to
  [framework_summary](https://ryanstraight.github.io/cybedtools/dev/reference/framework_summary.md)`$framework_slug`.
  Unique.

- framework_name:

  Character. Short display name, matching
  [framework_summary](https://ryanstraight.github.io/cybedtools/dev/reference/framework_summary.md)`$framework_name`
  for framework rows.

- license_short:

  Character. A short honest label, under 40 characters. The value
  [framework_summary](https://ryanstraight.github.io/cybedtools/dev/reference/framework_summary.md)`$license`
  carries.

- license:

  Character. What the source's own document, licence file, or published
  terms page says, verbatim or as a faithful close quotation, naming the
  document or page it was read from. Where a source states nothing, the
  row says so rather than filling the gap.

- attribution:

  Character. The attribution string to use, verbatim where the steward
  prescribed one. `NA` where none is prescribed; the package does not
  invent citation wording and attribute it to a steward. This is the
  only column that may be `NA`.

- public_redistribution:

  Character. One of `"unrestricted"`, `"full_with_attribution"`,
  `"structure_only"`, or `"local_only"`, as described above.

- terms_url:

  Character. A public URL for the terms or the source document. Always
  `https`. Where a source publishes no framework-specific terms page,
  this is the publisher's own page for the document.

- granted:

  Logical. `TRUE` only where a steward gave cybedtools specific written
  permission. An open licence anyone may rely on is not a grant to
  cybedtools and is `FALSE`.

- verified:

  Date. When the terms were last read from the source.

## Source

Each framework's own published document or terms page, cited in the
`license` and `terms_url` columns. See
`data-raw/build-framework-licenses.R`, `LICENSING.md`, and
`docs/framework-data-sources.md`.

## What the redistribution classes mean

`public_redistribution` is the package's own operating rule for what it
will publish from a framework, and it agrees by construction with
`docs/framework-invariants.yml`, where a framework carrying no
`public_redistribution` key means `"unrestricted"`.

- `"unrestricted"`:

  Structure and statement text may both be published, subject to the
  source's own attribution and non-commercial or share-alike terms where
  it has them. The class speaks to redistribution, not to commercial
  reuse: CSTA and Cyber.org K-12 are `"unrestricted"` here and still
  carry NC and NC-SA obligations recorded in `license`.

- `"full_with_attribution"`:

  As above, with attribution the steward asked for explicitly.

- `"structure_only"`:

  Titles, categories, levels, codes, counts and mappings may be
  published. Statement text may not.

- `"local_only"`:

  Nothing beyond aggregate counts is published. Analysis happens on the
  user's own machine, where no distribution occurs.

## See also

Other licensing:
[`cybed_license()`](https://ryanstraight.github.io/cybedtools/dev/reference/cybed_license.md)

## Examples

``` r
framework_licenses
#> # A tibble: 12 × 10
#>    layer     slug              framework_name  license_short license attribution
#>    <chr>     <chr>             <chr>           <chr>         <chr>   <chr>      
#>  1 code      cybedtools        cybedtools (R … MIT           "LICEN… Copyright …
#>  2 framework nice-v2           NICE v2.2.0     US public do… "The i… NA         
#>  3 framework dcwf-v5.1         DCWF v5.1       US Governmen… "The D… NA         
#>  4 framework ecsf-v1           ECSF v1         CC BY 4.0 (r… "Two t… European U…
#>  5 framework sfia-9            SFIA 9          SFIA Foundat… "SFIA … NA         
#>  6 framework cyberorg-k12-v1.0 Cyber.org K-12… CC BY-NC 4.0  "From … K-12 Cyber…
#>  7 framework csta-2017         CSTA K-12 CS (… CC BY-NC-SA … "The i… Computer S…
#>  8 framework csec2017-v1       ACM/IEEE CSEC2… All rights r… "From … NA         
#>  9 framework digcomp-2.2       DigComp 2.2     CC BY 4.0     "From … Vuorikari,…
#> 10 framework cyqual-v1.2.0     CyQUAL 1.2.0    Open data, a… "The o… CyQUAL, th…
#> 11 framework ccssf-2022        CCSSF 2022      Government o… "The C… Canadian C…
#> 12 framework otccf-v1.1        OTCCF v1.1      CSA copyrigh… "\"(c)… Derived fr…
#> # ℹ 4 more variables: public_redistribution <chr>, terms_url <chr>,
#> #   granted <lgl>, verified <date>
subset(framework_licenses, granted)
#> # A tibble: 2 × 10
#>   layer     slug          framework_name license_short       license attribution
#>   <chr>     <chr>         <chr>          <chr>               <chr>   <chr>      
#> 1 framework cyqual-v1.2.0 CyQUAL 1.2.0   Open data, attribu… "The o… CyQUAL, th…
#> 2 framework otccf-v1.1    OTCCF v1.1     CSA copyright; non… "\"(c)… Derived fr…
#> # ℹ 4 more variables: public_redistribution <chr>, terms_url <chr>,
#> #   granted <lgl>, verified <date>
subset(framework_licenses, public_redistribution != "unrestricted",
       select = c("slug", "license_short", "public_redistribution"))
#> # A tibble: 9 × 3
#>   slug              license_short                          public_redistribution
#>   <chr>             <chr>                                  <chr>                
#> 1 ecsf-v1           CC BY 4.0 (report); data files unmark… full_with_attribution
#> 2 sfia-9            SFIA Foundation licence required       local_only           
#> 3 cyberorg-k12-v1.0 CC BY-NC 4.0                           full_with_attribution
#> 4 csta-2017         CC BY-NC-SA 4.0                        full_with_attribution
#> 5 csec2017-v1       All rights reserved; educational use   structure_only       
#> 6 digcomp-2.2       CC BY 4.0                              full_with_attribution
#> 7 cyqual-v1.2.0     Open data, attribution required        full_with_attribution
#> 8 ccssf-2022        Government of Canada copyright         structure_only       
#> 9 otccf-v1.1        CSA copyright; non-commercial academic structure_only       
```
