# Construct a `cybed:UnitRelation` node

**\[experimental\]**

A qualified relation between two organizing units, used when the
publisher says more than "these are related": a required proficiency
level, or a named relation type. The matching plain edge is asserted
separately with
[`build_related_unit_metadata()`](https://ryanstraight.github.io/cybedtools/reference/build_related_unit_metadata.md).

A statement's identity is (from unit, to unit and its framework,
relation label, level), and the node `@id` is built from all of them, so
the same pair at two levels, under two labels, or pointing into two
frameworks gives distinct nodes. Identical inputs give identical nodes:
when a source prints the same statement twice, deduplicate rows before
calling.

`proficiency_level` is stored as a string exactly as printed. Pass it as
character. Frameworks use incompatible scales (1 to 6, 1 to 5, Basic /
Intermediate / Advanced), and a shared numeric type would assert a
comparability the sources do not.

## Usage

``` r
build_unit_relation_node(
  from_unit_id,
  to_unit_id,
  from_prefix,
  to_prefix = from_prefix,
  relation_label = NA_character_,
  proficiency_level = NA_character_,
  source_section = NA_character_,
  framework_id = NA_character_
)
```

## Arguments

- from_unit_id, to_unit_id:

  Character, unit identifiers.

- from_prefix:

  Character, Tier 2 prefix of the source unit. The relation node is
  minted under this prefix.

- to_prefix:

  Character, Tier 2 prefix of the target unit. Defaults to
  `from_prefix`; set it when the relation crosses frameworks.

- relation_label:

  Character, the publisher's own word for the relation (e.g.,
  `"requires"`, `"supports"`).

- proficiency_level:

  Character, the level as printed.

- source_section:

  Character, where the relation appears in the source.

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
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/reference/build_organizing_unit_node.md),
[`build_related_unit_metadata()`](https://ryanstraight.github.io/cybedtools/reference/build_related_unit_metadata.md),
[`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_element_node.md),
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)

## Examples

``` r
rel <- build_unit_relation_node(
  from_unit_id      = "ot-security-engineer",
  to_unit_id        = "network-security",
  from_prefix       = "otccf",
  relation_label    = "requires",
  proficiency_level = "4",
  framework_id      = "otccf-v1.1"
)
rel[["@type"]]
#> [1] "cybed:UnitRelation"
rel[["cybed:proficiencyLevel"]]
#> [1] "4"
```
