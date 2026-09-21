"""Cross-framework organizing-unit text similarity.

Ports ``R/similarity-helpers.R``. Per the approved API proposal
(``2026-09-21_cybedtools-0.4.0-api-proposal.md``, item 4), only
:func:`framework_similarity` is public. The tokenizer, the Jaccard
set-similarity, the stopword list, and the ranking tie-break stay private,
so their details can change without breaking anyone.

``from`` is a reserved word in Python, so the public function takes
``from_`` where the R signature has ``from``.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

import pandas as pd

__all__ = ["framework_similarity"]

_CYBED = "https://w3id.org/cybed/ontology#"
_RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"
_SCHEMA_NAME = "http://schema.org/name"
_ELEMENT_TEXT = _CYBED + "elementText"
_PART_OF = _CYBED + "partOf"
_HAS_ELEMENT = _CYBED + "hasElement"
_ORGANIZING_UNIT = _CYBED + "OrganizingUnit"
_FRAMEWORK = _CYBED + "Framework"

_TOKEN_SPLIT_RE = re.compile(r"[^a-z0-9]+")

# Verbatim port of similarity_stopwords()'s "workforce" profile (the
# default used by tokenize()/framework_similarity()). The "k12" profile
# (this base list without the ten extra words below) is not needed by the
# public Python surface, since tokenize() itself is not exported.
_STOPWORDS_BASE = frozenset(
    {
        "the", "a", "an", "of", "in", "to", "for", "with", "and", "or", "is", "are", "be", "by",
        "on", "at", "as", "that", "this", "their", "they", "it", "its", "from", "how", "can",
        "use", "using", "used", "may", "will", "such", "but", "not", "do", "have", "has",
        "what", "which", "when", "between", "into", "about", "also", "than", "then", "there",
        "these", "those", "while", "each", "other", "both", "more", "most", "some", "many",
        "include", "including", "includes", "example", "examples", "based", "through",
    }
)
_WORKFORCE_EXTRA = frozenset(
    {"any", "all", "new", "one", "two", "three", "work", "perform", "performs", "ensure"}
)
_STOPWORDS_WORKFORCE = _STOPWORDS_BASE | _WORKFORCE_EXTRA


class CybedtoolsScalarInputError(TypeError):
    """A function that expects a length-1 string input received something else."""


def _tokenize(text: str | None, stopwords: frozenset[str] = _STOPWORDS_WORKFORCE) -> list[str]:
    """Tokenize a text scalar for Jaccard comparison.

    Lowercases, splits on runs of characters outside ``a-z0-9``, drops
    tokens shorter than 3 characters and stopwords, and de-duplicates
    (set semantics, order-preserving -- matches R's ``unique()``).

    Mirrors R's ``tokenize()`` exactly, including its lossy behaviors:
    2-character domain terms ("AI", "OS", "5G") are dropped by the
    length-3 floor, and non-ASCII letters fall outside ``[^a-z0-9]+``'s
    complement so accented text is split on those boundaries too (both
    R's regex, evaluated byte/char-literally rather than via a Unicode
    letter class, and Python's ``re`` module with a plain ``str`` pattern
    treat ``[^a-z0-9]`` the same way: anything not in that literal ASCII
    range is a split point, not just non-word characters).

    Parameters
    ----------
    text : str or None
        A single piece of text, or ``None``/empty string.
    stopwords : frozenset[str]
        Stopword set; defaults to the "workforce" profile, matching
        ``framework_similarity()``'s use of R's ``tokenize()`` default.

    Returns
    -------
    list[str]
        Unique tokens, in first-seen order.
    """
    if text is None or text == "":
        return []

    lowered = text.lower()
    raw_tokens = _TOKEN_SPLIT_RE.split(lowered)

    seen: dict[str, None] = {}
    for token in raw_tokens:
        if len(token) >= 3 and token not in stopwords:
            seen.setdefault(token, None)
    return list(seen)


def _jaccard(a: list[str], b: list[str]) -> float:
    """Jaccard similarity of two token lists, treated as sets.

    Either side empty returns exactly 0 -- the deliberate empty-set
    convention `R/similarity-helpers.R` documents (not the
    mathematical-purist 1 for empty-empty).
    """
    set_a = set(a)
    set_b = set(b)
    if not set_a or not set_b:
        return 0.0
    return len(set_a & set_b) / len(set_a | set_b)


def _similarity_strength(score: float) -> str:
    """Strength tier for a similarity score. Boundaries inclusive (``>=``)."""
    if score >= 0.30:
        return "strong"
    if score >= 0.20:
        return "moderate"
    if score >= 0.10:
        return "weak"
    return "none"


@dataclass(frozen=True)
class _UnitDoc:
    unit: str
    tokens: list[str]


def _local_name(iri: str) -> str:
    """The final ``/``-delimited segment of an IRI (used as the framework slug)."""
    return iri.rsplit("/", 1)[-1]


def _iter_triples(graph: object):
    """Yield ``(subject, predicate, obj)`` triples as plain strings from an rdflib Graph."""
    for subject, predicate, obj in graph:  # type: ignore[misc]
        yield str(subject), str(predicate), str(obj)


def _element_text(graph: object) -> dict[str, str]:
    """Map element IRI -> its ``cybed:elementText`` literal.

    Mirrors ``element_text(rdf)``: any resource carrying a
    ``cybed:elementText`` triple, keyed by subject IRI.
    """
    texts: dict[str, str] = {}
    for subject, predicate, obj in _iter_triples(graph):
        if predicate == _ELEMENT_TEXT:
            texts[subject] = obj
    return texts


def _unit_element_bindings(graph: object) -> dict[str, list[str]]:
    """Map organizing-unit IRI -> its ``cybed:hasElement`` targets, in triple order.

    Mirrors the ``cybed:hasElement`` edges consumed by
    ``unit_element_bindings()`` -- deliberately not ``cybed:hasExample``,
    which R's ``framework_similarity()`` also excludes from child text.
    """
    bindings: dict[str, list[str]] = {}
    for subject, predicate, obj in _iter_triples(graph):
        if predicate == _HAS_ELEMENT:
            bindings.setdefault(subject, []).append(obj)
    return bindings


def _organizing_units_for_framework(graph: object, slug: str) -> list[tuple[str, str]]:
    """List ``(unit_iri, unit_name)`` pairs for organizing units in the framework `slug`.

    Mirrors ``organizing_unit_framework_bindings(rdf)`` filtered to one
    ``framework_slug``: a unit's slug is derived from the IRI of the
    ``cybed:Framework`` it's ``cybed:partOf``, taking that IRI's final
    path segment (matching how the shipped fixture's `framework_slug`
    values -- e.g. ``"fixture-wf1"`` -- are the local name of
    ``.../framework/fixture-wf1``).
    """
    unit_iris: set[str] = set()
    part_of: dict[str, str] = {}
    names: dict[str, str] = {}
    framework_iris: set[str] = set()

    for subject, predicate, obj in _iter_triples(graph):
        if predicate == _RDF_TYPE and obj == _ORGANIZING_UNIT:
            unit_iris.add(subject)
        elif predicate == _RDF_TYPE and obj == _FRAMEWORK:
            framework_iris.add(subject)
        elif predicate == _PART_OF:
            part_of[subject] = obj
        elif predicate == _SCHEMA_NAME:
            names[subject] = obj

    result: list[tuple[str, str]] = []
    for unit in unit_iris:
        framework_iri = part_of.get(unit)
        if framework_iri is None or framework_iri not in framework_iris:
            continue
        if _local_name(framework_iri) != slug:
            continue
        result.append((unit, names.get(unit, "")))
    result.sort(key=lambda pair: pair[0])
    return result


def _side_documents(graph: object, slug: str) -> list[_UnitDoc]:
    """Build one tokenized document per organizing unit in framework `slug`.

    Mirrors `framework_similarity()`'s internal `side()`: each unit's
    comparison text is its own name, its own `elementText` when the unit
    IRI itself carries one directly, and the concatenated `elementText`
    of every element reachable via `cybed:hasElement`. Units whose
    assembled text is empty after trimming contribute no document (an
    empty document has nothing to compare).
    """
    texts = _element_text(graph)
    element_bindings = _unit_element_bindings(graph)

    documents: list[_UnitDoc] = []
    for unit, unit_name in _organizing_units_for_framework(graph, slug):
        own_text = texts.get(unit, "")
        child_texts = [texts[element] for element in element_bindings.get(unit, []) if element in texts]
        child_text = " ".join(child_texts)

        full_text = f"{unit_name} {own_text} {child_text}".strip()
        if not full_text:
            continue

        documents.append(_UnitDoc(unit=unit, tokens=_tokenize(full_text)))

    return documents


def framework_similarity(graph: object, from_: str, to: str, n: int = 5) -> pd.DataFrame:
    """Cross-framework unit-text similarity, top-n matches per unit.

    Reproduces R's ``framework_similarity(rdf, from, to, n)`` (``from`` is
    a reserved word in Python, hence ``from_`` here). Each organizing
    unit's comparison text is its own name, its own ``cybed:elementText``
    when it carries one directly, and the concatenated
    ``cybed:elementText`` of every element reachable via
    ``cybed:hasElement``. Every (from-unit, to-unit) pair is scored with
    a Jaccard set-similarity over tokenized text, the top ``n`` matches
    per from-unit are kept (ties broken by ascending ``to_unit``), and
    each score's strength tier is attached.

    Parameters
    ----------
    graph : object
        A parsed rdflib ``Graph`` (or any object iterable as
        ``(subject, predicate, obj)`` triples), as returned by
        :func:`cybedtools.load_graph`.
    from_ : str
        The `framework_slug` whose organizing units are the rows being
        matched.
    to : str
        The `framework_slug` whose organizing units are the candidates.
        May equal `from_`, to find near-duplicate units within one
        framework.
    n : int
        Matches to keep per from-unit (default 5).

    Returns
    -------
    pandas.DataFrame
        One row per (from unit, match), with columns `from_unit`,
        `to_unit` (both full IRIs), `score` (float in `[0, 1]`, rounded to
        10 decimal places), `strength` (`"strong"`/`"moderate"`/
        `"weak"`/`"none"`), and `rank` (int, `1..k`, dense per
        `from_unit`). A from-side unit with zero candidates on the `to`
        side contributes no rows.
    """
    if not isinstance(from_, str):
        msg = "`from_` must be a string."
        raise CybedtoolsScalarInputError(msg)
    if not isinstance(to, str):
        msg = "`to` must be a string."
        raise CybedtoolsScalarInputError(msg)

    empty = pd.DataFrame(
        {
            "from_unit": pd.Series(dtype="object"),
            "to_unit": pd.Series(dtype="object"),
            "score": pd.Series(dtype="float64"),
            "strength": pd.Series(dtype="object"),
            "rank": pd.Series(dtype="int64"),
        }
    )

    from_units = _side_documents(graph, from_)
    to_units = _side_documents(graph, to)
    if not from_units or not to_units:
        return empty

    rows: list[dict[str, object]] = []
    for from_doc in from_units:
        scored = [
            (to_doc.unit, _jaccard(from_doc.tokens, to_doc.tokens)) for to_doc in to_units
        ]
        # Deterministic tie-break: descending score, then ascending candidate.
        scored.sort(key=lambda pair: (-pair[1], pair[0]))
        for rank, (candidate, score) in enumerate(scored[:n], start=1):
            rows.append(
                {
                    "from_unit": from_doc.unit,
                    "to_unit": candidate,
                    "score": round(score, 10),
                    "strength": _similarity_strength(score),
                    "rank": rank,
                }
            )

    return pd.DataFrame(rows, columns=["from_unit", "to_unit", "score", "strength", "rank"])
