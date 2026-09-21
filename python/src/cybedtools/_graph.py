"""Graph backend for parsed N-Triples data.

The default backend is `rdflib <https://rdflib.readthedocs.io/>`_, a pure
Python RDF library with no compiled dependency, matching the low-friction
install the R package gets from ``rdflib`` (the R package of the same name,
itself a wrapper). A second backend, `pyoxigraph
<https://pyoxigraph.readthedocs.io/>`_, is available as an optional extra
(``pip install cybedtools[oxigraph]``) for callers who load the full
multi-framework corpus and want faster SPARQL evaluation; pyoxigraph ships
compiled wheels for the common platforms, so it is kept optional rather than
a hard dependency.

Query helpers (``framework_metadata()``, ``unit_element_bindings()``, and so
on) are out of scope for this module. This module only owns turning a set of
N-Triples file paths into one shared graph object.
"""

from __future__ import annotations

from pathlib import Path
from typing import Literal

GraphBackend = Literal["rdflib", "pyoxigraph"]

_DEFAULT_BACKEND: GraphBackend = "rdflib"


class BackendNotAvailableError(ImportError):
    """Raised when a requested graph backend is not installed."""


def parse_graph(paths: list[Path], *, backend: GraphBackend = _DEFAULT_BACKEND) -> object:
    """Parse one or more N-Triples files into a single shared graph.

    Parameters
    ----------
    paths : list[Path]
        Paths to plain-text (already decompressed) N-Triples files.
    backend : {"rdflib", "pyoxigraph"}
        Which graph implementation to build. ``"rdflib"`` is the default and
        has no extra install requirement. ``"pyoxigraph"`` requires the
        ``oxigraph`` extra.

    Returns
    -------
    object
        An ``rdflib.Graph`` when ``backend="rdflib"``, or a
        ``pyoxigraph.Store`` when ``backend="pyoxigraph"``.

    Raises
    ------
    BackendNotAvailableError
        If ``backend="pyoxigraph"`` is requested but pyoxigraph is not
        installed.
    ValueError
        If ``backend`` is not one of the two supported values.
    """
    if backend == "rdflib":
        return _parse_rdflib(paths)
    if backend == "pyoxigraph":
        return _parse_pyoxigraph(paths)
    msg = f"Unknown graph backend: {backend!r}. Expected 'rdflib' or 'pyoxigraph'."
    raise ValueError(msg)


def _parse_rdflib(paths: list[Path]) -> object:
    try:
        import rdflib
    except ImportError as exc:  # pragma: no cover - rdflib is a hard dependency
        msg = "rdflib is required for the default graph backend."
        raise BackendNotAvailableError(msg) from exc

    graph = rdflib.Graph()
    for path in paths:
        graph.parse(str(path), format="nt")
    return graph


def _parse_pyoxigraph(paths: list[Path]) -> object:
    try:
        import pyoxigraph
    except ImportError as exc:
        msg = (
            "pyoxigraph is not installed. Install it with "
            "`pip install cybedtools[oxigraph]` to use backend='pyoxigraph'."
        )
        raise BackendNotAvailableError(msg) from exc

    store = pyoxigraph.Store()
    for path in paths:
        store.bulk_load(path=str(path), format=pyoxigraph.RdfFormat.N_TRIPLES)
    return store
