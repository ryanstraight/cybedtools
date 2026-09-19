# cybedtools

cybedtools harmonizes cybersecurity workforce competency frameworks and cybersecurity-related learning frameworks into a single RDF graph with one shared vocabulary, so that roles, organizing units, and competency statements from different frameworks can be queried together instead of one document at a time.

## Status of this release

This is a placeholder. It installs, it imports, and it reports its version. It does not query anything yet. The release exists to reserve the `cybedtools` name on PyPI while the Python interface is built.

## Use the R package today

The mature interface is the R package, which builds the graph and ships the query helpers. It lives in the same repository: https://github.com/ryanstraight/cybedtools

## How the two packages will relate

The Python package will read the same published per-framework graph files that the R package produces, so both languages work from one set of data rather than two parallel builds. Function names and the column names of returned tables will match the R package, so one description in a paper covers both implementations.

## Licensing

The package code is MIT licensed. The framework content itself is not: each source framework keeps its own terms, and some of them restrict redistribution. Per-framework licensing is documented in `LICENSING.md` in the repository: https://github.com/ryanstraight/cybedtools/blob/main/LICENSING.md

## Citation

Cite the software through its concept DOI, which always resolves to the most recent version: https://doi.org/10.5281/zenodo.20076116
