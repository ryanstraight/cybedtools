# cybedtools: Cross-framework Analysis of Cybersecurity Workforce and Learning Frameworks

Eight cybersecurity workforce and learning frameworks (NICE, DCWF, SFIA,
ENISA ECSF, Cyber.org K-12, CSTA K-12 CS, ACM/IEEE CSEC2017, DigComp
2.2) expressed in a shared `cybed:` semantic schema, with R helpers that
query across them as if they were one corpus. The package adds a
comparison layer over existing frameworks rather than proposing a
replacement.

Use it for cross-framework curricular comparison, workforce-development
role-to-training mapping, structural coverage checks against peer
frameworks, or dissertation work that needs cross-framework empirical
claims. The package's design discipline is single-BGP SPARQL queries
with R-side joins and aggregation. See the `cross-framework-analysis`
vignette for worked examples.

## Where to start

- [`make_demo_graph()`](https://ryanstraight.github.io/cybedtools/reference/make_demo_graph.md)
  returns a small in-memory two-framework graph that exercises every
  helper without staged data. One-line sanity check after install.

- The `getting-started` vignette walks through loading a graph and
  running the domain helpers.

- The `cross-framework-analysis` vignette shows worked findings across
  the full eight-framework graph.

- The `adding-a-framework` vignette covers extending the package with a
  new framework.

- Function reference is grouped by family (JSON-LD construction, File
  I/O, RDF graph loading, SPARQL helpers, Validation).

## See also

Useful links:

- <https://github.com/ryanstraight/cybedtools>

- <https://ryanstraight.github.io/cybedtools/>

- Report bugs at <https://github.com/ryanstraight/cybedtools/issues>

## Author

**Maintainer**: Ryan Straight <ryanstraight@arizona.edu>
([ORCID](https://orcid.org/0000-0002-6251-5662)) \[copyright holder\]

Authors:

- Ryan Straight <ryanstraight@arizona.edu>
  ([ORCID](https://orcid.org/0000-0002-6251-5662)) \[copyright holder\]
