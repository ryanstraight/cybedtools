# Cross-framework unit-text similarity, top-n matches per unit

**\[experimental\]**

Reproduces, as the one public entry point, the "full-document" Jaccard
similarity computed script-locally by the concordance data-prep scripts
(`concordance/_data-prep-*.R`, e.g. `_data-prep-nice-ecsf-alignment.R`'s
`build_full_doc()`): each organizing unit's comparison text is its own
`schema:name`, its own `cybed:elementText` when it carries one directly
(true for pedagogy units where the unit and its top-level statement
share one IRI, e.g. Cyber.org/CSTA cells), and the concatenated
`cybed:elementText` of every element reachable via
[`unit_element_bindings()`](https://ryanstraight.github.io/cybedtools/reference/unit_element_bindings.md)
(true for workforce units, whose task/ knowledge/skill statements are
separate elements linked by `cybed:hasElement`). This single
text-assembly rule is what lets one function serve both structural
shapes. Every (from-unit, to-unit) pair is then scored with `jaccard()`,
the top `n` matches per from-unit are kept via `top_n_matches()`, and
each score's `similarity_strength()` is attached. The tokenizer, the
Jaccard set-similarity, the stopword list and the ranking tie-break are
internal (`@noRd`) and may change without notice; only this function's
signature and output shape are the contract.

`from` and `to` select organizing units by `framework_slug`
([`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md)`$framework_slug`),
matching how the concordance scripts partition units before scoring
(`framework_slug == "cyberorg-k12"` vs `"csta-2017"`, for example). A
unit with no name, no own text, and no child element text at all
contributes no rows on either side (empty document, nothing to compare).

## Usage

``` r
framework_similarity(rdf, from, to, n = 5)
```

## Arguments

- rdf:

  An rdf object.

- from, to:

  Character scalars, the `framework_slug` values (from
  [`organizing_unit_framework_bindings()`](https://ryanstraight.github.io/cybedtools/reference/organizing_unit_framework_bindings.md))
  whose organizing units are compared, either as the versioned slug
  (`"nice-v2"`) or the short release-file slug (`"nice"`; see
  [`cybed_fetch()`](https://ryanstraight.github.io/cybedtools/reference/cybed_fetch.md)).
  May be identical, to find near-duplicate units within one framework.
  An unknown slug (in either vocabulary, and not present in `rdf`)
  errors with class `cybedtools_framework_not_found` rather than
  silently returning an empty result.

- n:

  Integer, matches to keep per from-unit (default `5`).

## Value

A tibble with one row per (from unit, match): columns `from_unit`,
`to_unit` (both full IRIs), `score` (numeric in `[0, 1]`), `strength`
(`"strong"`/`"moderate"`/`"weak"`/`"none"`), and `rank` (integer,
`1..k`, dense per `from_unit`). A `from`-side unit with zero candidates
on the `to` side contributes no rows. A `from`-side unit whose only
candidates all score 0 still appears, ranked, with `strength == "none"`.

## Examples

``` r
rdf <- make_demo_graph()
# make_demo_graph()'s two frameworks carry no cybed:elementText or
# cybed:hasElement text, so this is a zero-row tibble with the columns
# from_unit/to_unit/score/strength/rank.
framework_similarity(rdf, from = "demo-fw-a", to = "demo-fw-b")
#> # A tibble: 2 × 5
#>   from_unit                                    to_unit      score strength  rank
#>   <chr>                                        <chr>        <dbl> <chr>    <int>
#> 1 https://w3id.org/cybed/ontology#role/demo-a1 https://w3i…     0 none         1
#> 2 https://w3id.org/cybed/ontology#role/demo-a2 https://w3i…     0 none         1

if (FALSE) { # \dontrun{
rdf <- load_combined_ntriples_graph()
framework_similarity(rdf, from = "cyberorg-k12", to = "csta-2017", n = 3)
} # }
```
