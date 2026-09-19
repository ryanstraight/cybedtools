# Assemble a framework-level `@graph` document

**\[stable\]**

Convenience constructor that wraps the supplied framework, role, and
element nodes into a single top-level JSON-LD document with the
appropriate `@context`.

## Usage

``` r
assemble_framework_document(
  framework_node,
  role_nodes,
  element_nodes,
  framework_prefix,
  relation_nodes = list()
)
```

## Arguments

- framework_node:

  Named list produced by
  [`build_framework_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_framework_node.md).

- role_nodes:

  List of named lists produced by
  [`build_role_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_role_node.md).

- element_nodes:

  List of named lists produced by
  [`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_role_element_node.md).

- framework_prefix:

  Character, the Tier 2 prefix.

- relation_nodes:

  List of named lists produced by
  [`build_unit_relation_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_unit_relation_node.md).
  Optional: frameworks that publish no qualified unit-to-unit statements
  pass nothing and the `@graph` is unchanged.

## Value

Top-level JSON-LD document with `@context` and `@graph`.

## See also

Other JSON-LD construction:
[`build_framework_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_framework_node.md),
[`build_jsonld_context()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_jsonld_context.md),
[`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_multi_framework_context.md),
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_organizing_unit_node.md),
[`build_related_unit_metadata()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_related_unit_metadata.md),
[`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_role_element_node.md),
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_role_node.md),
[`build_unit_relation_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_unit_relation_node.md)

## Examples

``` r
fw <- build_framework_node(
  framework_id     = "nice-v2",
  framework_name   = "NICE",
  framework_prefix = "nice",
  version          = "2.0.0",
  publisher        = "NIST",
  jurisdiction     = "US",
  sector           = "civilian",
  specificity      = "cybersecurity-specific"
)
role <- build_role_node(
  role_id              = "OG-WRL-015",
  role_name            = "Cybersecurity Architecture",
  framework_prefix     = "nice",
  framework_role_type  = "WorkRole",
  framework_id         = "nice-v2"
)
doc <- assemble_framework_document(fw, list(role), list(), "nice")
names(doc)
#> [1] "@context" "@graph"  
```
