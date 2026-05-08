# Build a JSON-LD `@context` block covering multiple frameworks

**\[stable\]**

Use when assembling a combined graph that spans more than one framework,
so a single SPARQL query can traverse all included vocabularies.

## Usage

``` r
build_multi_framework_context(framework_prefixes)
```

## Arguments

- framework_prefixes:

  Character vector of framework prefixes.

## Value

Named list suitable for use as JSON-LD `@context`.

## See also

Other JSON-LD construction:
[`assemble_framework_document()`](https://ryanstraight.github.io/cybedtools/reference/assemble_framework_document.md),
[`build_framework_node()`](https://ryanstraight.github.io/cybedtools/reference/build_framework_node.md),
[`build_jsonld_context()`](https://ryanstraight.github.io/cybedtools/reference/build_jsonld_context.md),
[`build_organizing_unit_node()`](https://ryanstraight.github.io/cybedtools/reference/build_organizing_unit_node.md),
[`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_element_node.md),
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)

## Examples

``` r
ctx <- build_multi_framework_context(c("nice", "sfia", "ecsf"))
names(ctx)
#> [1] "schema" "skos"   "rdfs"   "cybed"  "nice"   "sfia"   "ecsf"  
# "schema" "skos" "rdfs" "cybed" "nice" "sfia" "ecsf"
```
