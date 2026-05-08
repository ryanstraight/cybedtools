# Append Subpoint IDs to a role's child-element id list

**\[stable\]**

Helper for the assembly pipeline. Given a vector of parent element IDs
(the role's children before sub-point expansion) and a sub-node index
from
[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md),
returns the original IDs plus all Subpoint IDs whose parent is in the
input vector. Preserves order: parents first, Subpoints second.
De-duplicates.

Example IDs are deliberately excluded. `cybed:Example` instances are
reachable via the parent element's `cybed:hasExample` predicate rather
than via the role's `cybed:hasElement` collection; including them here
would route teacher-facing pedagogical scaffolding into role-level "all
elements" traversals where it does not belong.

## Usage

``` r
extend_role_element_ids(parent_element_ids, subnode_index)
```

## Arguments

- parent_element_ids:

  Character vector of parent element IDs.

- subnode_index:

  A tibble with columns `parent_id`, `subnode_id`, `ordinal`,
  `node_type` (typically the `subnode_index` field returned by
  [`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md)).

## Value

Character vector of parent IDs plus matching Subpoint IDs.

## See also

Other Sub-point parsing:
[`build_example_node()`](https://ryanstraight.github.io/cybedtools/reference/build_example_node.md),
[`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md),
[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md),
[`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
