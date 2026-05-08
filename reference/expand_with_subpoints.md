# Expand parent element nodes with sub-point and example child nodes

**\[stable\]**

Walks a list of parent element nodes, parses each one's
`cybed:elementText` for enumerated child fragments, and returns a list
with the parents plus newly-minted child nodes. Each child is routed per
its parsed `node_type`:

- `node_type == "Subpoint"` (framework-as-specified enumeration from
  "such as", "including", semicolon-list patterns) becomes a
  [cybed:Subpoint](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md)
  node, carries its parent's framework subtype, and appears in default
  `cybed:hasElement` traversals.

- `node_type == "Example"` (pedagogical scaffolding from "Clarification
  statement:" sources) becomes a
  [cybed:Example](https://ryanstraight.github.io/cybedtools/reference/build_example_node.md)
  node, carries no framework-native subtype, and is reachable only via
  the parent's `cybed:hasExample` predicate (Examples are excluded from
  default `cybed:hasElement` collections).

Parents that emit any Example children are mutated in place to add
`cybed:hasExample` triples linking to those Examples. Parents whose text
yields no fragments pass through unchanged. The returned list preserves
parent order and appends children after their parents.

Child IRIs are deterministic: `<parent_iri>.sub.<ordinal>` for Subpoints
and `<parent_iri>.example.<ordinal>` for Examples.

## Usage

``` r
expand_with_subpoints(
  element_nodes,
  framework_prefix,
  framework_id,
  framework_slug = NULL,
  parent_subtype = NULL
)
```

## Arguments

- element_nodes:

  List of named lists produced by
  [`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_element_node.md).

- framework_prefix:

  Character, Tier 2 prefix.

- framework_id:

  Character, framework identifier.

- framework_slug:

  Character, framework slug for per-framework opt-out via
  `CYBED_DISABLE_SUBPOINT_PARSER` env var. Optional.

- parent_subtype:

  Character, the framework's element subtype name (e.g., `"Standard"`,
  `"SkillLevel"`). Defaults to `"RoleElement"` if unknown.

## Value

List with two named entries: `nodes` (the expanded list of parent +
child nodes) and `subnode_index` (a tibble with one row per child:
`parent_id`, `subnode_id`, `ordinal`, `node_type`). The index drives
[`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md),
which back-fills the parent role's `cybed:hasElement` list with Subpoint
IDs (Examples excluded).

## See also

Other Sub-point parsing:
[`build_example_node()`](https://ryanstraight.github.io/cybedtools/reference/build_example_node.md),
[`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md),
[`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md),
[`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
