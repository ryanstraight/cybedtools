# Domain helper: role-to-framework bindings with framework name attached

**\[stable\]**

One row per (role, framework) pair where the role is typed `cybed:Role`
and its `partOf` target is typed `cybed:Framework`. As of v0.2.0,
`cybed:Role` is reserved for workforce frameworks (NICE work roles, DCWF
work roles, ENISA ECSF profiles); SFIA skills, Cyber.org K-12 grade-band
x sub-concept cells, CSTA level x concept cells, CSEC2017 Knowledge
Areas, and DigComp competence areas are not roles and are not returned
by this helper. Use
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md)
for the cross-framework "top-level enumerated unit" cut that includes
all eight frameworks.

Roles without a `cybed:partOf` triple, or whose partOf target is not
typed `cybed:Framework`, are excluded.

## Usage

``` r
role_framework_bindings(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `role`, `role_name`, `framework`,
`framework_name`.

## See also

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md)

## Examples

``` r
if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
role_framework_bindings(rdf)
} # }
```
