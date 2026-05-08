# Append subpoint IDs to a role's child-element id list

**\[stable\]**

Helper for the assembly pipeline. Given a vector of parent element IDs
(the role's children before subpoint expansion) and a subpoint index
from
[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md),
returns the original IDs plus all subpoint IDs whose parent is in the
input vector. Preserves order: parents first, sub-points second.
De-duplicates.

## Usage

``` r
extend_role_element_ids(parent_element_ids, subpoint_index)
```

## Arguments

- parent_element_ids:

  Character vector of parent element IDs.

- subpoint_index:

  A tibble with columns `parent_id`, `subpoint_id`, `ordinal` (typically
  the `subpoint_index` field returned by
  [`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md)).

## Value

Character vector of parent IDs plus matching subpoint IDs.

## See also

Other Sub-point parsing:
[`build_subpoint_node()`](https://ryanstraight.github.io/cybedtools/reference/build_subpoint_node.md),
[`expand_with_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/expand_with_subpoints.md),
[`parse_subpoints()`](https://ryanstraight.github.io/cybedtools/reference/parse_subpoints.md)
