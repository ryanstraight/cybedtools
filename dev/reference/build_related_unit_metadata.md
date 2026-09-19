# Build `cybed:relatedUnit` metadata for an organizing unit

**\[experimental\]**

Some frameworks relate one organizing unit to another: a job role to the
skills it requires, a knowledge unit to the outcomes it supports. The
plain `cybed:relatedUnit` edge records that the publisher relates the
two units and nothing more, so "which units does this unit point at"
stays a one-hop query. When the publisher qualifies the relation (a
required proficiency level, a named relation type), also emit a
[`build_unit_relation_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_unit_relation_node.md)
for the pair.

Pass the result as (part of) the `metadata` argument of
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_organizing_unit_node.md)
or
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_role_node.md).
Call it ONCE per source unit with every target that unit has: two calls
merged with [`c()`](https://rdrr.io/r/base/c.html) give the node two
`cybed:relatedUnit` keys, which is not valid JSON-LD. Targets in several
frameworks go in one call, with `to_prefix` given per target.

## Usage

``` r
build_related_unit_metadata(to_unit_ids, to_prefix)
```

## Arguments

- to_unit_ids:

  Character vector of target unit identifiers.

- to_prefix:

  Character, Tier 2 prefix the targets live under: one value for all
  targets, or one per target. Differs from the source unit's prefix when
  the relation crosses frameworks.

## Value

Named list with one entry, `cybed:relatedUnit`, or an empty list when
there are no targets.

## See also

Other JSON-LD construction:
[`assemble_framework_document()`](https://ryanstraight.github.io/cybedtools/dev/reference/assemble_framework_document.md),
[`build_framework_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_framework_node.md),
[`build_jsonld_context()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_jsonld_context.md),
[`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_multi_framework_context.md),
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_organizing_unit_node.md),
[`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_role_element_node.md),
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_role_node.md),
[`build_unit_relation_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_unit_relation_node.md)

## Examples

``` r
build_related_unit_metadata(c("skill-a", "skill-b"), "otccf")
#> $`cybed:relatedUnit`
#> $`cybed:relatedUnit`[[1]]
#> $`cybed:relatedUnit`[[1]]$`@id`
#> [1] "otccf:skill-a"
#> 
#> 
#> $`cybed:relatedUnit`[[2]]
#> $`cybed:relatedUnit`[[2]]$`@id`
#> [1] "otccf:skill-b"
#> 
#> 
#> 

# Targets in two frameworks, one call.
build_related_unit_metadata(c("skill-a", "OG-WRL-015"), c("otccf", "nice"))
#> $`cybed:relatedUnit`
#> $`cybed:relatedUnit`[[1]]
#> $`cybed:relatedUnit`[[1]]$`@id`
#> [1] "otccf:skill-a"
#> 
#> 
#> $`cybed:relatedUnit`[[2]]
#> $`cybed:relatedUnit`[[2]]$`@id`
#> [1] "nice:OG-WRL-015"
#> 
#> 
#> 
```
