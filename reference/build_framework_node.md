# Construct a `cybed:Framework` top-level node

**\[stable\]**

Every framework rendered through cybedtools produces exactly one of
these nodes. Downstream Role and RoleElement nodes attach to it via
`cybed:partOf`.

## Usage

``` r
build_framework_node(
  framework_id,
  framework_name,
  framework_prefix,
  version,
  publisher,
  jurisdiction,
  sector,
  specificity,
  license = NA_character_,
  date_published = NA_character_
)
```

## Arguments

- framework_id:

  Character, internal identifier (e.g., `"nice-v2"`, `"ecf-2.0"`,
  `"ecsf-2022"`, `"sfia-9"`, `"dcwf-2024"`).

- framework_name:

  Character, human-readable name.

- framework_prefix:

  Character, the Tier 2 prefix for this framework.

- version:

  Character, publisher version string.

- publisher:

  Character, publisher name.

- jurisdiction:

  Character, one of `"US"`, `"EU"`, `"UK"`, `"global"`.

- sector:

  Character, one of `"civilian"`, `"defense"`, `"general"`.

- specificity:

  Character, one of `"general-IT"`, `"cybersecurity-specific"`.

- license:

  Character, license URI or SPDX identifier.

- date_published:

  Character, ISO-8601 date.

## Value

Named list (JSON-LD node) describing the framework.

## See also

Other JSON-LD construction:
[`assemble_framework_document()`](https://ryanstraight.github.io/cybedtools/reference/assemble_framework_document.md),
[`build_jsonld_context()`](https://ryanstraight.github.io/cybedtools/reference/build_jsonld_context.md),
[`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/reference/build_multi_framework_context.md),
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/reference/build_organizing_unit_node.md),
[`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_element_node.md),
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)

## Examples

``` r
fw <- build_framework_node(
  framework_id     = "nice-v2",
  framework_name   = "NICE Framework v2",
  framework_prefix = "nice",
  version          = "2.0.0",
  publisher        = "NIST",
  jurisdiction     = "US",
  sector           = "civilian",
  specificity      = "cybersecurity-specific"
)
fw[["@id"]]
#> cybed:framework/nice-v2
fw[["@type"]]
#> [1] "nice:Framework"  "cybed:Framework"
```
