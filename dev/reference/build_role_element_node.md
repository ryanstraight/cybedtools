# Construct a `cybed:RoleElement` node

**\[stable\]**

A role element is one atomic statement attached to a role: a task, a
knowledge statement, a skill statement, a competence description, etc.
Framework-specific element types become subclasses of
`cybed:RoleElement`.

## Usage

``` r
build_role_element_node(
  element_id,
  framework_prefix,
  framework_element_type,
  element_text,
  source_section = NA_character_,
  framework_id = NA_character_,
  source_category = NA_character_
)
```

## Arguments

- element_id:

  Character, framework-local identifier.

- framework_prefix:

  Character, Tier 2 prefix.

- framework_element_type:

  Character, specific subclass name within the framework vocabulary
  (e.g., `"TaskStatement"`, `"KnowledgeStatement"`, `"SkillStatement"`,
  `"Competence"`).

- element_text:

  Character, full statement text.

- source_section:

  Character, where this element appears in the source.

- framework_id:

  Character, framework identifier to populate `cybed:partOf`.

- source_category:

  Character, the source framework's own per-element provenance tag, when
  the publisher labels which upstream body a statement was drawn from
  (e.g., DCWF's Master Task & KSA List tags each row `"NICE"`,
  `"JCT-T"`, `"JCT-KSA"`, `"Other-T"`, or `"Other-KSA"`). This is a
  categorical tag as published, not a link to a specific element in the
  named framework – the source data does not carry that level of
  precision. Distinct from `source_section`, which locates content
  within the SAME document rather than attributing it to a different
  one. 2026-08-14: added after a DCWF-vs-NICE alignment query returned
  an implausibly weak result and traced to this provenance column being
  dropped at ingest.

## Value

Named list (JSON-LD node).

## See also

Other JSON-LD construction:
[`assemble_framework_document()`](https://ryanstraight.github.io/cybedtools/dev/reference/assemble_framework_document.md),
[`build_framework_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_framework_node.md),
[`build_jsonld_context()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_jsonld_context.md),
[`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_multi_framework_context.md),
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_organizing_unit_node.md),
[`build_related_unit_metadata()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_related_unit_metadata.md),
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_role_node.md),
[`build_unit_relation_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_unit_relation_node.md)

## Examples

``` r
el <- build_role_element_node(
  element_id             = "T0001",
  framework_prefix       = "nice",
  framework_element_type = "TaskStatement",
  element_text           = "Acquire and manage the necessary resources.",
  framework_id           = "nice-v2"
)
el[["cybed:elementText"]]
#> [1] "Acquire and manage the necessary resources."
el[["cybed:partOf"]]
#> $`@id`
#> cybed:framework/nice-v2
#> 
```
