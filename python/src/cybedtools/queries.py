"""Query helpers over a loaded graph.

Python port of ``R/sparql-helpers.R``. The R package's design discipline is
single-basic-graph-pattern queries (one triple match per query call), with
all joins, multi-property assembly, and aggregation done afterward via
``dplyr``. This module mirrors that discipline: each single-BGP step is a
direct rdflib triple lookup (``graph.subjects()`` / ``graph.subject_objects()``,
the Python equivalent of a one-triple-pattern SPARQL SELECT), and the
domain-level helpers stitch those results together with ``pandas`` merges
that reproduce the R functions' ``inner_join`` / ``left_join`` / ``semi_join``
semantics column-for-column, including NA propagation and fan-out on
duplicate keys.

Function names, argument names, return column names and order, the
``framework_slug`` derivation, and NA semantics all match the R helpers
exactly; see ``inst/conformance/README.md`` for the golden-file contract
these functions are tested against.
"""

from __future__ import annotations

import warnings

import pandas as pd
import rdflib

__all__ = [
    "framework_metadata",
    "role_framework_bindings",
    "organizing_unit_framework_bindings",
    "element_framework_bindings",
    "example_framework_bindings",
    "subpoint_framework_bindings",
    "unit_element_bindings",
    "unit_relation_bindings",
    "element_text",
    "role_element_bindings",
]

_CYBED = "https://w3id.org/cybed/ontology#"
_SCHEMA = "http://schema.org/"
_RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"


def _cybed(term: str) -> str:
    return _CYBED + term


def framework_slug_of(framework_uri: pd.Series) -> pd.Series:
    """Derive a framework's stable slug from its framework IRI.

    The text after the final ``/`` of the IRI, matching
    ``framework_slug_of()`` in ``R/sparql-helpers.R``. ``NA`` input yields
    ``NA`` output.

    Parameters
    ----------
    framework_uri : pandas.Series
        The ``framework`` column of any of this module's helpers.

    Returns
    -------
    pandas.Series
        Slugs, same length and index as ``framework_uri``.
    """
    return framework_uri.map(lambda uri: uri.rsplit("/", 1)[-1] if pd.notna(uri) else pd.NA)


def _pairs(graph: rdflib.Graph, predicate: str) -> pd.DataFrame:
    """Single-BGP ``SELECT ?s ?o WHERE { ?s <predicate> ?o }`` equivalent."""
    rows = [(str(s), str(o)) for s, o in graph.subject_objects(rdflib.URIRef(predicate))]
    if not rows:
        return pd.DataFrame({"s": pd.Series(dtype="object"), "o": pd.Series(dtype="object")})
    return pd.DataFrame(rows, columns=["s", "o"])


def _subjects(graph: rdflib.Graph, predicate: str, obj: str) -> pd.DataFrame:
    """Single-BGP ``SELECT ?s WHERE { ?s <predicate> <obj> }`` equivalent."""
    rows = [str(s) for s in graph.subjects(rdflib.URIRef(predicate), rdflib.URIRef(obj))]
    if not rows:
        return pd.DataFrame({"s": pd.Series(dtype="object")})
    return pd.DataFrame({"s": rows})


def _semi_join_isin(frame: pd.DataFrame, column: str, allowed: pd.DataFrame, allowed_column: str) -> pd.DataFrame:
    """``dplyr::semi_join`` equivalent: filter rows without duplicating or adding columns."""
    allowed_values = set(allowed[allowed_column])
    return frame[frame[column].isin(allowed_values)]


def framework_metadata(rdf: rdflib.Graph) -> pd.DataFrame:
    """Tibble/DataFrame of framework metadata.

    Parameters
    ----------
    rdf : rdflib.Graph
        A graph from :func:`cybedtools._graph.parse_graph` or
        :func:`cybedtools.load_graph`.

    Returns
    -------
    pandas.DataFrame
        Columns ``framework``, ``name``, ``jurisdiction``, ``sector``,
        ``specificity``, ``framework_slug``. One row per framework typed
        ``cybed:Framework``.
    """
    fw = _subjects(rdf, _RDF_TYPE, _cybed("Framework")).rename(columns={"s": "framework"})
    names_ = _pairs(rdf, _SCHEMA + "name").rename(columns={"s": "framework", "o": "name"})
    juris = _pairs(rdf, _cybed("jurisdiction")).rename(columns={"s": "framework", "o": "jurisdiction"})
    sectors = _pairs(rdf, _cybed("sector")).rename(columns={"s": "framework", "o": "sector"})
    specs = _pairs(rdf, _cybed("specificity")).rename(columns={"s": "framework", "o": "specificity"})

    result = fw.merge(names_, on="framework", how="left")
    result = result.merge(juris, on="framework", how="left")
    result = result.merge(sectors, on="framework", how="left")
    result = result.merge(specs, on="framework", how="left")
    result["framework_slug"] = framework_slug_of(result["framework"])
    return result[["framework", "name", "jurisdiction", "sector", "specificity", "framework_slug"]]


def role_framework_bindings(rdf: rdflib.Graph) -> pd.DataFrame:
    """Role-to-framework bindings with framework name attached.

    Parameters
    ----------
    rdf : rdflib.Graph

    Returns
    -------
    pandas.DataFrame
        Columns ``role``, ``framework``, ``role_name``, ``framework_name``,
        ``framework_slug``.
    """
    roles = _subjects(rdf, _RDF_TYPE, _cybed("Role")).rename(columns={"s": "role"})
    fws = _subjects(rdf, _RDF_TYPE, _cybed("Framework"))
    names_ = _pairs(rdf, _SCHEMA + "name")
    partof = _pairs(rdf, _cybed("partOf")).rename(columns={"s": "role", "o": "framework"})

    result = roles.merge(partof, on="role", how="inner")
    result = _semi_join_isin(result, "framework", fws, "s")
    result = result.merge(names_.rename(columns={"s": "role", "o": "role_name"}), on="role", how="left")
    result = result.merge(
        names_.rename(columns={"s": "framework", "o": "framework_name"}), on="framework", how="left"
    )
    result["framework_slug"] = framework_slug_of(result["framework"])
    return result[["role", "framework", "role_name", "framework_name", "framework_slug"]]


def organizing_unit_framework_bindings(rdf: rdflib.Graph) -> pd.DataFrame:
    """Organizing-unit-to-framework bindings with framework name attached.

    Parameters
    ----------
    rdf : rdflib.Graph

    Returns
    -------
    pandas.DataFrame
        Columns ``unit``, ``framework``, ``unit_name``, ``framework_name``,
        ``framework_slug``.
    """
    units = _subjects(rdf, _RDF_TYPE, _cybed("OrganizingUnit")).rename(columns={"s": "unit"})
    fws = _subjects(rdf, _RDF_TYPE, _cybed("Framework"))
    names_ = _pairs(rdf, _SCHEMA + "name")
    partof = _pairs(rdf, _cybed("partOf")).rename(columns={"s": "unit", "o": "framework"})

    result = units.merge(partof, on="unit", how="inner")
    result = _semi_join_isin(result, "framework", fws, "s")
    result = result.merge(names_.rename(columns={"s": "unit", "o": "unit_name"}), on="unit", how="left")
    result = result.merge(
        names_.rename(columns={"s": "framework", "o": "framework_name"}), on="framework", how="left"
    )
    result["framework_slug"] = framework_slug_of(result["framework"])
    return result[["unit", "framework", "unit_name", "framework_name", "framework_slug"]]


def element_framework_bindings(rdf: rdflib.Graph) -> pd.DataFrame:
    """Element-to-framework bindings with framework name attached.

    Parameters
    ----------
    rdf : rdflib.Graph

    Returns
    -------
    pandas.DataFrame
        Columns ``element``, ``framework``, ``framework_name``,
        ``framework_slug``.
    """
    elements = _subjects(rdf, _RDF_TYPE, _cybed("RoleElement")).rename(columns={"s": "element"})
    fws = _subjects(rdf, _RDF_TYPE, _cybed("Framework"))
    partof = _pairs(rdf, _cybed("partOf")).rename(columns={"s": "element", "o": "framework"})
    fw_names = _pairs(rdf, _SCHEMA + "name").rename(columns={"s": "framework", "o": "framework_name"})

    result = elements.merge(partof, on="element", how="inner")
    result = _semi_join_isin(result, "framework", fws, "s")
    result = result.merge(fw_names, on="framework", how="left")
    result["framework_slug"] = framework_slug_of(result["framework"])
    return result[["element", "framework", "framework_name", "framework_slug"]]


def example_framework_bindings(rdf: rdflib.Graph) -> pd.DataFrame:
    """Example-to-framework bindings with framework name attached.

    Parameters
    ----------
    rdf : rdflib.Graph

    Returns
    -------
    pandas.DataFrame
        Columns ``example``, ``framework``, ``framework_name``,
        ``framework_slug``.
    """
    examples = _subjects(rdf, _RDF_TYPE, _cybed("Example")).rename(columns={"s": "example"})
    fws = _subjects(rdf, _RDF_TYPE, _cybed("Framework"))
    partof = _pairs(rdf, _cybed("partOf")).rename(columns={"s": "example", "o": "framework"})
    fw_names = _pairs(rdf, _SCHEMA + "name").rename(columns={"s": "framework", "o": "framework_name"})

    result = examples.merge(partof, on="example", how="inner")
    result = _semi_join_isin(result, "framework", fws, "s")
    result = result.merge(fw_names, on="framework", how="left")
    result["framework_slug"] = framework_slug_of(result["framework"])
    return result[["example", "framework", "framework_name", "framework_slug"]]


def subpoint_framework_bindings(rdf: rdflib.Graph) -> pd.DataFrame:
    """Subpoint-to-framework bindings with framework name attached.

    Parameters
    ----------
    rdf : rdflib.Graph

    Returns
    -------
    pandas.DataFrame
        Columns ``subpoint``, ``framework``, ``framework_name``,
        ``framework_slug``.
    """
    subpoints = _subjects(rdf, _RDF_TYPE, _cybed("Subpoint")).rename(columns={"s": "subpoint"})
    fws = _subjects(rdf, _RDF_TYPE, _cybed("Framework"))
    partof = _pairs(rdf, _cybed("partOf")).rename(columns={"s": "subpoint", "o": "framework"})
    fw_names = _pairs(rdf, _SCHEMA + "name").rename(columns={"s": "framework", "o": "framework_name"})

    result = subpoints.merge(partof, on="subpoint", how="inner")
    result = _semi_join_isin(result, "framework", fws, "s")
    result = result.merge(fw_names, on="framework", how="left")
    result["framework_slug"] = framework_slug_of(result["framework"])
    return result[["subpoint", "framework", "framework_name", "framework_slug"]]


def element_text(rdf: rdflib.Graph) -> pd.DataFrame:
    """Statement text keyed by element.

    Parameters
    ----------
    rdf : rdflib.Graph

    Returns
    -------
    pandas.DataFrame
        Columns ``element`` (the element's full URI) and ``text`` (the
        statement literal). Elements without a ``cybed:elementText`` triple
        do not appear; an element with more than one such literal yields
        one row per literal.
    """
    texts = _pairs(rdf, _cybed("elementText"))
    return texts.rename(columns={"s": "element", "o": "text"})


def unit_element_bindings(rdf: rdflib.Graph) -> pd.DataFrame:
    """Organizing-unit-to-element bindings.

    Parameters
    ----------
    rdf : rdflib.Graph

    Returns
    -------
    pandas.DataFrame
        Columns ``role``, ``element``, ``framework_slug``. Despite the
        ``role`` column name, it is not restricted to ``cybed:Role``
        subjects -- ``cybed:hasElement`` is the universal parent-child link
        used across all eleven frameworks. A ``role`` with no valid
        ``cybed:partOf`` to a ``cybed:Framework`` carries ``NA`` in
        ``framework_slug`` rather than dropping the row.
    """
    has_element = _pairs(rdf, _cybed("hasElement")).rename(columns={"s": "role", "o": "element"})
    units = organizing_unit_framework_bindings(rdf)[["unit", "framework_slug"]].rename(columns={"unit": "role"})
    return has_element.merge(units, on="role", how="left")


def role_element_bindings(rdf: rdflib.Graph) -> pd.DataFrame:
    """Deprecated alias for :func:`unit_element_bindings`.

    Deprecated as of cybedtools 0.4.0 in favor of
    :func:`unit_element_bindings`, which returns the identical result under
    a name that doesn't overstate the role restriction.

    Parameters
    ----------
    rdf : rdflib.Graph

    Returns
    -------
    pandas.DataFrame
        See :func:`unit_element_bindings`.
    """
    warnings.warn(
        "`role_element_bindings()` was deprecated in cybedtools 0.4.0. "
        "Use `unit_element_bindings()` instead.",
        DeprecationWarning,
        stacklevel=2,
    )
    return unit_element_bindings(rdf)


def unit_relation_bindings(rdf: rdflib.Graph) -> pd.DataFrame:
    """Unit-to-unit relation bindings.

    Parameters
    ----------
    rdf : rdflib.Graph

    Returns
    -------
    pandas.DataFrame
        Columns ``from_unit``, ``relation``, ``to_unit``,
        ``framework_slug``. ``relation`` is ``NA`` for a plain (unlabeled)
        relation; ``framework_slug`` is ``NA`` when the relation node
        carries no valid ``cybed:partOf`` to a ``cybed:Framework``.
    """
    relations = _subjects(rdf, _RDF_TYPE, _cybed("UnitRelation")).rename(columns={"s": "relation_id"})
    from_unit = _pairs(rdf, _cybed("fromUnit")).rename(columns={"s": "relation_id", "o": "from_unit"})
    to_unit = _pairs(rdf, _cybed("toUnit")).rename(columns={"s": "relation_id", "o": "to_unit"})
    labels = _pairs(rdf, _cybed("relationLabel")).rename(columns={"s": "relation_id", "o": "relation"})
    partof = _pairs(rdf, _cybed("partOf")).rename(columns={"s": "relation_id", "o": "framework"})
    fws = _subjects(rdf, _RDF_TYPE, _cybed("Framework"))

    fw_of_relation = _semi_join_isin(partof, "framework", fws, "s").copy()
    fw_of_relation["framework_slug"] = framework_slug_of(fw_of_relation["framework"])
    fw_of_relation = fw_of_relation[["relation_id", "framework_slug"]]

    result = relations.merge(from_unit, on="relation_id", how="left")
    result = result.merge(to_unit, on="relation_id", how="left")
    result = result.merge(labels, on="relation_id", how="left")
    result = result.merge(fw_of_relation, on="relation_id", how="left")
    return result[["from_unit", "relation", "to_unit", "framework_slug"]]
