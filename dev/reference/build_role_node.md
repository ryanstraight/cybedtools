# Construct a `cybed:Role` node (workforce frameworks)

**\[stable\]**

Convenience wrapper around
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_organizing_unit_node.md)
for workforce frameworks (NICE, DCWF, ENISA ECSF). Asserts `cybed:Role`
in addition to `cybed:OrganizingUnit` and the per-framework subtype. For
non-workforce frameworks (SFIA, Cyber.org K-12, CSTA, CSEC2017, DigComp
2.2), call
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_organizing_unit_node.md)
directly with `is_role = FALSE`.

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
  opm_codes = character(0),
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
  (e.g., `"WorkRole"`, `"RoleProfile"`).

- description:

  Character, role description text.

- element_ids:

  Character vector of role-element identifiers to link.

- framework_id:

  Character, framework identifier (e.g., `"nice-v2"`) to populate
  `cybed:partOf`. Enables SPARQL queries that traverse role to
  framework. Recommended. Defaults to `NA` for backward compatibility.

- opm_codes:

  Character vector of OPM occupational-series codes to attach as the
  multi-valued literal property `cybed:opmCode`. NICE v2.2.0 publishes
  Federal-use OPM cybersecurity data standard codes per work role; a
  role may carry zero, one, or several codes (e.g., NICE `DD-WRL-004`
  carries two). The codes are modeled as literals, not nodes: the
  published `opm_code` elements have no descriptive payload (title/text
  are empty; the code is the identifier). Empty vector (the default) and
  `NA` entries omit the property. Merged via the same metadata-merge
  path used for `cybed:ecfCrossReference`, `cybed:cybokCrossReference`,
  and `cybed:niceCrossReference` (the framework's own cited NICE
  work-role ids, recorded as literals where the cited ids do not resolve
  to elements in this graph).

- metadata:

  Named list, optional additional fields to include.

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
[`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_role_element_node.md),
[`build_unit_relation_node()`](https://ryanstraight.github.io/cybedtools/dev/reference/build_unit_relation_node.md)

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
role[["@type"]]
#> [1] "nice:WorkRole"        "cybed:Role"           "cybed:OrganizingUnit"
# c("nice:WorkRole", "cybed:Role", "cybed:OrganizingUnit")

# Multi-valued OPM codes (NICE v2.2.0 Federal-use annotation).
role_opm <- build_role_node(
  role_id              = "DD-WRL-004",
  role_name            = "Enterprise Architecture",
  framework_prefix     = "nice",
  framework_role_type  = "WorkRole",
  framework_id         = "nice-v2",
  opm_codes            = c("631", "632")
)
role_opm[["cybed:opmCode"]]
#> [1] "631" "632"
```
