# Domain helper: statement text keyed by element

**\[stable\]**

One row per element that carries a `cybed:elementText` literal, from the
single basic graph pattern `sparql_pairs(rdf, "cybed:elementText")`
renamed from `s`/`o`. This is the statement text itself – the task,
knowledge, skill, competency, or standard wording as the framework
publishes it.

## Usage

``` r
element_text(rdf)
```

## Arguments

- rdf:

  An rdf object.

## Value

A tibble with columns `element` (character, the element's full URI) and
`text` (character, the statement literal).

## Details

Nothing is filtered, normalised, or de-duplicated beyond what the graph
holds. Elements without a `cybed:elementText` triple simply do not
appear, and an element carrying more than one `cybed:elementText`
literal yields one row per literal, so `element` is not guaranteed
unique. A graph with no `cybed:elementText` triples at all returns a
zero-row tibble with the same two columns.

Sub-points and examples are elements too, and they carry their own text:
a `cybed:Subpoint` holds the enumerated fragment lifted out of its
parent's wording, and a `cybed:Example` holds the pedagogical
"Clarification statement:" content. A caller who wants parent statements
only should anti-join both child sets away, matching each helper's own
identifier column against `element`:
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/subpoint_framework_bindings.md)
returns `subpoint`, and
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md)
returns `example`.

## See also

[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md)
to attach framework attribution,
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/subpoint_framework_bindings.md)
and
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md)
to separate child elements from parent statements.

Other SPARQL helpers:
[`element_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/element_framework_bindings.md),
[`example_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/example_framework_bindings.md),
[`framework_metadata()`](https://ryanstraight.github.io/cybedtools/reference/framework_metadata.md),
[`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md),
[`role_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_element_bindings.md),
[`role_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/role_framework_bindings.md),
[`sparql_pairs()`](https://ryanstraight.github.io/cybedtools/reference/sparql_pairs.md),
[`sparql_subjects()`](https://ryanstraight.github.io/cybedtools/reference/sparql_subjects.md),
[`subpoint_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/subpoint_framework_bindings.md)

## Examples

``` r
rdf <- make_demo_graph()
# The demo graph carries no cybed:elementText, so this is a zero-row
# tibble with the columns `element` and `text`.
element_text(rdf)
#> # A tibble: 0 × 2
#> # ℹ 2 variables: element <chr>, text <chr>

if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
texts <- element_text(rdf)

# Parent statements only: drop sub-points and examples.
texts |>
  dplyr::anti_join(
    dplyr::rename(subpoint_framework_bindings(rdf), element = "subpoint"),
    by = "element"
  ) |>
  dplyr::anti_join(
    dplyr::rename(example_framework_bindings(rdf), element = "example"),
    by = "element"
  )
} # }
```
