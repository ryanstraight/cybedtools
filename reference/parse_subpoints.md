# Parse subpoints out of a parent element's text

**\[stable\]**

Heuristic regex parser. Extracts enumerated child fragments from a
parent element's prose, returning a tibble of one row per fragment.
Returns an empty tibble for atomic statements that have no list to lift.

Two source patterns are recognized, and each row is tagged with the
`node_type` it should be promoted to in the JSON-LD graph:

- **"Clarification statement:" segments** (Cyber.org K-12 and CSTA
  convention). These are teacher-facing pedagogical scaffolding rather
  than framework-as-specified enumerations. Rows derived from this
  pattern carry `node_type == "Example"` and are promoted to
  [cybed:Example](https://ryanstraight.github.io/cybedtools/reference/build_example_node.md)
  nodes by
  [`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md).

- **"such as / including / examples of ..." patterns** (NICE, SFIA,
  ECSF, CSEC2017). These are within-text enumerations the framework
  specifies as part of the parent's normative content. Rows derived from
  this pattern carry `node_type == "Subpoint"` and are promoted to
  [cybed:Subpoint](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md)
  nodes.

The full algorithm and known limitations are documented in
`docs/framework-data-sources.md`.

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

Tibble with columns `ordinal` (integer, 1-based), `text` (character),
and `node_type` (character, `"Subpoint"` or `"Example"`). Empty tibble
(with the same column shape) when fewer than two fragments are found.

## See also

Other Sub-point parsing:
[`build_example_node()`](https://ryanstraight.github.io/cybedtools/reference/build_example_node.md),
[`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md),
[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md),
[`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md)

## Examples

``` r
# Cyber.org K-12 "Clarification statement:" pattern -> Examples.
parse_subpoints(
  "Describe a good password. Clarification statement: At this level,
  focus on examples such as not using common words; using pass phrases;
  combining letters, numbers, and symbols."
)
#> # A tibble: 2 × 3
#>   ordinal text                   node_type
#>     <int> <chr>                  <chr>    
#> 1       1 not using common words Example  
#> 2       2 using pass phrases     Example  

# "Such as ..." comma list -> Subpoints. Common in SFIA, NICE, CSEC2017.
parse_subpoints(
  "Authentication methods such as certificate, token-based, two-factor,
  multifactor, and biometric."
)
#> # A tibble: 3 × 3
#>   ordinal text        node_type
#>     <int> <chr>       <chr>    
#> 1       1 certificate Subpoint 
#> 2       2 token-based Subpoint 
#> 3       3 two-factor  Subpoint 

# Atomic statement returns an empty tibble.
parse_subpoints(
  "Provides authoritative consultation on financial impact assessment."
)
#> # A tibble: 0 × 3
#> # ℹ 3 variables: ordinal <int>, text <chr>, node_type <chr>
```
