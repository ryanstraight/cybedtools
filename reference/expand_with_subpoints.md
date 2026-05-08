# Expand parent element nodes with subpoint child nodes

**\[stable\]**

Convenience wrapper that walks a list of parent element nodes, parses
each one's `cybed:elementText` for sub-points, and returns a list with
the parents plus newly-minted sub-point nodes. Sub-point IDs are
deterministic (parent_iri + ".sub." + ordinal).

Parents whose text yields no sub-points pass through unchanged. The
returned list preserves parent order and appends sub-points after their
parents.

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
sub-point nodes) and `subpoint_index` (a tibble with one row per
sub-point: `parent_id`, `subpoint_id`, `ordinal`). The index is useful
for back-filling the parent role's `cybed:hasElement` list.

## See also

Other Sub-point parsing:
[`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md),
[`extend_role_element_ids()`](https://ryanstraight.github.io/cybedtools/reference/extend_role_element_ids.md),
[`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
