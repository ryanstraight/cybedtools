# Build a standard JSON-LD `@context` block

**\[stable\]**

Only the relevant framework prefix is included alongside base
vocabularies, keeping per-framework contexts compact. For
multi-framework graphs used in cross-framework queries, use
[`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/reference/build_multi_framework_context.md).

## Usage

``` r
build_jsonld_context(framework_prefix)
```

## Arguments

- framework_prefix:

  Character, one of the valid framework prefixes. Workforce: `"nice"`,
  `"dcwf"`, `"ecf"`, `"sfia"`, `"ecsf"`. Pedagogical: `"cyberorg"`,
  `"csta"`, `"csec"`, `"digcomp"`.

## Value

Named list suitable for use as JSON-LD `@context`.

## See also

Other JSON-LD construction:
[`assemble_framework_document()`](https://ryanstraight.github.io/cybedtools/reference/assemble_framework_document.md),
[`build_framework_node()`](https://ryanstraight.github.io/cybedtools/reference/build_framework_node.md),
[`build_multi_framework_context()`](https://ryanstraight.github.io/cybedtools/reference/build_multi_framework_context.md),
[`build_role_element_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_element_node.md),
[`build_role_node()`](https://ryanstraight.github.io/cybedtools/reference/build_role_node.md)

## Examples

``` r
ctx <- build_jsonld_context("nice")
names(ctx)
#> [1] "schema" "skos"   "rdfs"   "cybed"  "nice"  
# "schema" "skos" "rdfs" "cybed" "nice"
```
