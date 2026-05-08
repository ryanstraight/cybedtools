# Construct a `cybed:Subpoint` node

**\[stable\]**

A subpoint is a granular pedagogical or specification fragment lifted
out of a parent element's prose (typically from a "such as", "examples
of", or semicolon-delimited list inside `cybed:elementText`). Subpoints
carry the framework-native subtype `cybed:Subpoint` plus the parent's
framework subtype, retain `cybed:partOf` to the cluster, and link back
to the parent element via `cybed:elaborates`.

Use
[`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
to derive subpoint records from a parent's text; this constructor turns
one such record into a JSON-LD node.

## Usage

``` r
build_subpoint_node(
  parent_element_id,
  ordinal,
  text,
  framework_prefix,
  framework_id,
  parent_subtype = "RoleElement"
)
```

## Arguments

- parent_element_id:

  Character, the framework-local id of the parent element (without
  prefix), e.g., `"K-2.SEC.AUTH"`.

- ordinal:

  Integer, the 1-based subpoint ordinal within the parent.

- text:

  Character, the subpoint's text fragment.

- framework_prefix:

  Character, Tier 2 prefix.

- framework_id:

  Character, framework identifier for `cybed:partOf`.

- parent_subtype:

  Character, the parent element's framework subtype (e.g., `"Standard"`,
  `"SkillLevel"`). The subpoint is also typed as this subtype so it
  appears in framework-native queries.

## Value

Named list (JSON-LD node) for the subpoint.

## See also

Other Sub-point parsing:
[`build_example_node()`](https://ryanstraight.github.io/cybedtools/reference/build_example_node.md),
[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md),
[`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md),
[`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)

## Examples

``` r
sp <- build_subpoint_node(
  parent_element_id = "K-2.SEC.AUTH",
  ordinal           = 1,
  text              = "not using common words as passwords",
  framework_prefix  = "cyberorg",
  framework_id      = "cyberorg-k12-v1.0",
  parent_subtype    = "Standard"
)
sp[["@id"]]
#> cyberorg:K-2.SEC.AUTH.sub.1
sp[["cybed:elaborates"]]
#> $`@id`
#> cyberorg:K-2.SEC.AUTH
#> 
```
