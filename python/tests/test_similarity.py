"""Conformance and unit tests for cybedtools.similarity."""

from __future__ import annotations

import rdflib

from cybedtools._conformance import assert_matches_golden, conformance_dir
from cybedtools.similarity import _jaccard, _tokenize, framework_similarity


def _load_fixture_graph() -> rdflib.Graph:
    graph = rdflib.Graph()
    graph.parse(str(conformance_dir() / "fixture.nt"), format="nt")
    return graph


def test_framework_similarity_matches_golden() -> None:
    """framework_similarity(graph, "fixture-wf1", "fixture-wf2", 5) matches goldens/framework_similarity.csv."""
    graph = _load_fixture_graph()
    actual = framework_similarity(graph, from_="fixture-wf1", to="fixture-wf2", n=5)
    assert_matches_golden(actual, "framework_similarity", sort_by=["from_unit", "rank"])


def test_framework_similarity_no_units_on_either_side_is_empty() -> None:
    """A slug with no organizing units returns the zero-row frame with the contract's columns."""
    graph = _load_fixture_graph()
    result = framework_similarity(graph, from_="no-such-framework", to="fixture-wf2", n=5)
    assert list(result.columns) == ["from_unit", "to_unit", "score", "strength", "rank"]
    assert len(result) == 0


def test_framework_similarity_same_slug_on_both_sides_finds_self_matches() -> None:
    """from == to is allowed, e.g. to find near-duplicate units within one framework."""
    graph = _load_fixture_graph()
    result = framework_similarity(graph, from_="fixture-wf1", to="fixture-wf1", n=5)
    # Every unit is its own perfect match (score 1.0, rank 1).
    self_matches = result[result["from_unit"] == result["to_unit"]]
    assert (self_matches["score"] == 1.0).all()


# --- tokenize() edge cases -------------------------------------------------


def test_tokenize_empty_text_returns_empty_list() -> None:
    assert _tokenize("") == []
    assert _tokenize(None) == []


def test_tokenize_all_stopwords_returns_empty_list() -> None:
    assert _tokenize("the and or is are") == []


def test_tokenize_drops_short_tokens() -> None:
    # "AI", "OS", "IT", "5G" are all below the length-3 floor and dropped.
    assert _tokenize("AI OS IT 5G") == []


def test_tokenize_lowercases_and_dedupes() -> None:
    assert _tokenize("Network network NETWORK traffic") == ["network", "traffic"]


def test_tokenize_non_ascii_splits_on_accented_characters() -> None:
    # "café" -> "caf" once the trailing accented letter is treated as a
    # split boundary (matches R's `[^a-z0-9]+` under the byte-literal
    # character class, not a Unicode letter class).
    assert _tokenize("café") == ["caf"]


def test_tokenize_non_ascii_french_text() -> None:
    tokens = _tokenize("Protéger les données personnelles et respecter la vie privée")
    assert "prot" in tokens  # "protéger" splits on the accented "é" boundary
    assert "les" in tokens  # 3 chars, not a stopword (the workforce list is English-only)
    assert "personnelles" in tokens


# --- jaccard() edge cases ---------------------------------------------------


def test_jaccard_both_empty_is_zero() -> None:
    assert _jaccard([], []) == 0.0


def test_jaccard_one_side_empty_is_zero() -> None:
    assert _jaccard(["network"], []) == 0.0
    assert _jaccard([], ["network"]) == 0.0


def test_jaccard_identical_sets_is_one() -> None:
    assert _jaccard(["network", "traffic"], ["network", "traffic"]) == 1.0


def test_jaccard_partial_overlap() -> None:
    # intersection={network}, union={network,traffic,firewall} -> 1/3
    assert _jaccard(["network", "traffic"], ["network", "firewall"]) == 1 / 3


# --- ranking tie-break -------------------------------------------------


def test_top_n_ties_break_by_ascending_candidate() -> None:
    """Two to-units with an identical score rank by ascending IRI, not insertion order."""
    graph = rdflib.Graph()
    cybed = "https://w3id.org/cybed/ontology#"
    triples = f"""
    <{cybed}framework/tie-a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <{cybed}Framework> .
    <{cybed}framework/tie-b> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <{cybed}Framework> .
    <{cybed}role/tie-from> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <{cybed}OrganizingUnit> .
    <{cybed}role/tie-from> <{cybed}partOf> <{cybed}framework/tie-a> .
    <{cybed}role/tie-from> <http://schema.org/name> "network security incident" .
    <{cybed}role/tie-z> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <{cybed}OrganizingUnit> .
    <{cybed}role/tie-z> <{cybed}partOf> <{cybed}framework/tie-b> .
    <{cybed}role/tie-z> <http://schema.org/name> "network security incident" .
    <{cybed}role/tie-a> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <{cybed}OrganizingUnit> .
    <{cybed}role/tie-a> <{cybed}partOf> <{cybed}framework/tie-b> .
    <{cybed}role/tie-a> <http://schema.org/name> "network security incident" .
    """
    graph.parse(data=triples, format="nt")

    result = framework_similarity(graph, from_="tie-a", to="tie-b", n=5)
    ranked = result.sort_values("rank")
    # Both candidates tie at score 1.0; ascending IRI puts tie-a before tie-z.
    assert list(ranked["to_unit"]) == [
        f"{cybed}role/tie-a",
        f"{cybed}role/tie-z",
    ]
