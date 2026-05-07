# Construct a `cybed:Role` node

**\[stable\]**

A "role" in the cybed sense is the top-level organizing unit the
framework uses. For role-first frameworks (NICE, DCWF, ECSF) it is a
work role or role profile. For competence-first frameworks (e-CF) it is
a competence-at- proficiency-level. For skill-first frameworks (SFIA) it
is a skill-at- responsibility-level.

## Usage

``` r
build_role_node(
  role_id,
  role_name,
  framework_prefix,
  framework_role_type,
  description = NA_character_,
  element_ids = character(0),
  framework_id = NA_character_,
  metadata = list()
)
```

## Arguments

- role_id:

  Character, framework-local identifier (e.g., `"OG-WRL-015"`).

- role_name:

  Character, human-readable name.

- framework_prefix:

  Character, Tier 2 prefix.

- framework_role_type:

  Character, specific subclass name within the framework vocabulary
  (e.g., `"WorkRole"`, `"RoleProfile"`, `"Competence"`).

- description:

  Character, role description text.

- element_ids:

  Character vector of role-element identifiers to link.

- framework_id:

  Character, framework identifier (e.g., `"nice-v2"`) to populate
  `cybed:partOf`. Enables SPARQL queries that traverse role to
  framework. Recommended. Defaults to `NA` for backward compatibility.

- metadata:

  Named list, optional additional fields to include.

## Value

Named list (JSON-LD node).

## See also

Other JSON-LD construction:
[`assemble_framework_document()`](https://ryanstraight.github.io/cybedtools/reference/assemble_framework_document.md),
[`build_framework_node()`](https://ryanstraight.github.io/cybedtools/reference/build_framework_node.md),
[`build_jsonld_context()`](https://ryanstraight.github.io/cybedtools/reference/build_jsonld_context.md),
[`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/reference/build_multi_framework_context.md),
[`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_element_node.md)

## Examples

``` r
role <- build_role_node(
  role_id              = "OG-WRL-015",
  role_name            = "Cybersecurity Architecture",
  framework_prefix     = "nice",
  framework_role_type  = "WorkRole",
  description          = "Designs enterprise security architectures.",
  element_ids          = c("T0001", "K0001"),
  framework_id         = "nice-v2"
)
role[["@id"]]
#> nice:OG-WRL-015
role[["cybed:partOf"]]
#> $`@id`
#> cybed:framework/nice-v2
#> 
```
