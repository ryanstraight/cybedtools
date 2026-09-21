# cybedtools

cybedtools harmonizes cybersecurity workforce competency frameworks and cybersecurity-related learning frameworks into a single RDF graph with one shared vocabulary, so that roles, organizing units, and competency statements from different frameworks can be queried together instead of one document at a time.

## Status of this release

This Python package mirrors the R package's public API: data loading, reference tables, query helpers (`*_bindings()`, `framework_metadata()`), `framework_similarity()`, and `cybed_fetch()`/`load_graph()` for downloading and verifying release graphs.

## How the two packages relate

The Python package reads the same published per-framework graph files that the R package produces, so both languages work from one set of data rather than two parallel builds. Function names and the column names of returned tables match the R package, so one description in a paper covers both implementations. The R package remains the reference implementation and lives in the same repository: https://github.com/ryanstraight/cybedtools

## Licensing

The package code is MIT licensed. The framework content itself is not: each source framework keeps its own terms, and some of them restrict redistribution. Per-framework licensing is documented in `LICENSING.md` in the repository: https://github.com/ryanstraight/cybedtools/blob/main/LICENSING.md

## Citation

Cite the software through its concept DOI, which always resolves to the most recent version: https://doi.org/10.5281/zenodo.20076116
