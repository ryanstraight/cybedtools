# Construct a `cybed:OrganizingUnit` node

**\[stable\]**

Every framework's top-level enumerated unit is an instance of
`cybed:OrganizingUnit` (subClassOf `skos:Concept`), the cross-framework
abstract that lets one SPARQL query reach all eight frameworks' parent
units uniformly. Workforce frameworks (NICE, DCWF, ENISA ECSF) where the
unit is genuinely a work role or work profile additionally assert
`cybed:Role` (itself `subClassOf cybed:OrganizingUnit`); pass
`is_role = TRUE` for those. Non-workforce frameworks (SFIA enumerates
skills; Cyber.org K-12, CSTA, CSEC2017, DigComp 2.2 enumerate other
organizing units) assert `cybed:OrganizingUnit` only.

Each unit also carries a per-framework subtype (e.g., `nice:WorkRole`,
`sfia:Skill`, `csta:StandardGroup`, `cyberorg:StandardGroup`).
Cross-framework queries target `cybed:OrganizingUnit`;
framework-specific queries target the per-framework subtype;
workforce-only queries target `cybed:Role`.

For backward-compatible workforce-only construction, see
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md).

## Usage

``` r
build_organizing_unit_node(
  unit_id,
  unit_name,
  framework_prefix,
  framework_subtype,
  is_role = FALSE,
  description = NA_character_,
  element_ids = character(0),
  framework_id = NA_character_,
  metadata = list()
)
```

## Arguments

- unit_id:

  Character, framework-local identifier (e.g., `"OG-WRL-015"`, `"PROG"`,
  `"3A-AP-13"`).

- unit_name:

  Character, human-readable name.

- framework_prefix:

  Character, Tier 2 prefix.

- framework_subtype:

  Character, the framework's specific subtype name (e.g., `"WorkRole"`,
  `"Skill"`, `"StandardGroup"`, `"StandardGroup"`, `"KnowledgeArea"`,
  `"CompetenceArea"`).

- is_role:

  Logical, whether to additionally assert `cybed:Role`. `TRUE` for NICE
  work roles, DCWF work roles, and ENISA ECSF profiles; `FALSE` for SFIA
  skills, Cyber.org K-12 grade-band cells, CSTA level x concept cells,
  CSEC2017 Knowledge Areas, and DigComp competence areas. Defaults to
  `FALSE`.

- description:

  Character, unit description text.

- element_ids:

  Character vector of role-element identifiers to link via
  `cybed:hasElement`.

- framework_id:

  Character, framework identifier (e.g., `"nice-v2"`) to populate
  `cybed:partOf`.

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
[`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_element_node.md),
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)

## Examples

``` r
# Workforce framework: assert cybed:Role.
role <- build_organizing_unit_node(
  unit_id           = "OG-WRL-015",
  unit_name         = "Cybersecurity Architecture",
  framework_prefix  = "nice",
  framework_subtype = "WorkRole",
  is_role           = TRUE,
  description       = "Designs enterprise security architectures.",
  element_ids       = c("T0001", "K0001"),
  framework_id      = "nice-v2"
)
role[["@type"]]
#> [1] "nice:WorkRole"        "cybed:Role"           "cybed:OrganizingUnit"
# c("nice:WorkRole", "cybed:Role", "cybed:OrganizingUnit")

# Non-workforce framework: cybed:OrganizingUnit only.
bucket <- build_organizing_unit_node(
  unit_id           = "3A-IC",
  unit_name         = "Level 3A / Impacts of Computing",
  framework_prefix  = "csta",
  framework_subtype = "StandardGroup",
  is_role           = FALSE,
  framework_id      = "csta-2017"
)
bucket[["@type"]]
#> [1] "csta:StandardGroup"   "cybed:OrganizingUnit"
# c("csta:StandardGroup", "cybed:OrganizingUnit")
```
