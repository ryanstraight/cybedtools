# Parse subpoints out of a parent element's text

**\[stable\]**

Heuristic regex parser. Extracts enumerated sub-points from a parent
element's prose, returning a tibble of one row per sub-point. Returns an
empty tibble for atomic statements that have no list to lift.

Recognizes two payload shapes common across the supported frameworks:
Cyber.org K-12's "Clarification statement: ..." segments, and the "such
as / including / examples of ..." pattern that appears in NICE, SFIA,
ECSF, CSTA, and CSEC2017. The full algorithm and known limitations are
documented in `docs/framework-data-sources.md`.

Per-framework opt-out: set the `CYBED_DISABLE_SUBPOINT_PARSER` env var
(comma-separated framework slugs) and pass the slug as `framework_slug`.

## Usage

``` r
parse_subpoints(text, framework_slug = NULL)
```

## Arguments

- text:

  Character scalar. A parent element's `cybed:elementText`.

- framework_slug:

  Character, optional. Framework slug for the per-framework opt-out
  check. Defaults to `NULL` (no opt-out).

## Value

Tibble with columns `ordinal` (integer, 1-based) and `text` (character).
Empty tibble when fewer than two sub-points are found.

## See also

Other Sub-point parsing:
[`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md),
[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md),
[`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md)

## Examples

``` r
# Cyber.org K-12 "Clarification statement:" pattern.
parse_subpoints(
  "Describe a good password. Clarification statement: At this level,
  focus on examples such as not using common words; using pass phrases;
  combining letters, numbers, and symbols."
)
#> # A tibble: 2 × 2
#>   ordinal text                  
#>     <int> <chr>                 
#> 1       1 not using common words
#> 2       2 using pass phrases    

# "Such as ..." comma list. Common in SFIA, NICE, CSTA.
parse_subpoints(
  "Authentication methods such as certificate, token-based, two-factor,
  multifactor, and biometric."
)
#> # A tibble: 3 × 2
#>   ordinal text       
#>     <int> <chr>      
#> 1       1 certificate
#> 2       2 token-based
#> 3       3 two-factor 

# Atomic statement returns an empty tibble.
parse_subpoints(
  "Provides authoritative consultation on financial impact assessment."
)
#> # A tibble: 0 × 2
#> # ℹ 2 variables: ordinal <int>, text <chr>
```
