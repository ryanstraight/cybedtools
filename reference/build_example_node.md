# Construct a `cybed:Example` node

**\[stable\]**

An Example is a pedagogical-scaffolding fragment lifted from a parent
element's "Clarification statement:" prose. Distinct from
[`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md),
which represents enumerated sub-statements that the framework specifies
as part of a parent element's normative content. Examples carry `@type`
`[cybed:Example, cybed:RoleElement]` and no framework-native subtype:
Cyber.org K-12 and CSTA Clarification examples are teacher-facing
scaffolding rather than enumerable sub-standards, so framework-native
typing would overstate what the framework specifies.

Examples connect to their parent through the parent element's
`cybed:hasExample` predicate (parent → example direction). Examples do
not carry a back-pointer such as `cybed:elaborates`; the parent owns the
Example, not the converse. Examples are excluded from default
`cybed:hasElement` traversals: a role-level query for "all elements"
returns Subpoints but not Examples. Reach Examples by traversing the
parent element's `cybed:hasExample`.

[`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
flags rows from "Clarification statement:" sources as
`node_type == "Example"`;
[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md)
routes those rows to this constructor and emits the parent's
`cybed:hasExample` triples.

## Usage

``` r
build_example_node(
  parent_element_id,
  ordinal,
  text,
  framework_prefix,
  framework_id
)
```

## Arguments

- parent_element_id:

  Character, the framework-local id of the parent element (without
  prefix), e.g., `"K-2.SEC.AUTH"`.

- ordinal:

  Integer, the 1-based example ordinal within the parent.

- text:

  Character, the example's text fragment.

- framework_prefix:

  Character, Tier 2 prefix.

- framework_id:

  Character, framework identifier for `cybed:partOf`.

## Value

Named list (JSON-LD node) for the example.

## See also

Other Sub-point parsing:
[`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md),
[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md),
[`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md),
[`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)

## Examples

``` r
ex <- build_example_node(
  parent_element_id = "K-2.SEC.AUTH",
  ordinal           = 1,
  text              = "not using common words as passwords",
  framework_prefix  = "cyberorg",
  framework_id      = "cyberorg-k12-v1.0"
)
ex[["@id"]]
#> cyberorg:K-2.SEC.AUTH.example.1
ex[["@type"]]
#> [1] "cybed:Example"     "cybed:RoleElement"
```
