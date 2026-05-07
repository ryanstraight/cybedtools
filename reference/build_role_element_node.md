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
  framework_id = NA_character_
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

## Value

Named list (JSON-LD node).

## See also

Other JSON-LD construction:
[`assemble_framework_document()`](https://ryanstraight.github.io/cybedtools/reference/assemble_framework_document.md),
[`build_framework_node()`](https://ryanstraight.github.io/cybedtools/reference/build_framework_node.md),
[`build_jsonld_context()`](https://ryanstraight.github.io/cybedtools/reference/build_jsonld_context.md),
[`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/reference/build_multi_framework_context.md),
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)

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
