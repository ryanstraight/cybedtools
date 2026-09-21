"""Conformance tests for the query-graph helpers in cybedtools.queries.

Each function is run against ``tests/fixtures/conformance/fixture.nt`` and
checked byte-for-value against its golden in
``tests/fixtures/conformance/goldens/`` per the contract in
``inst/conformance/README.md``. See ``cybedtools._conformance`` for the
shared loading/comparison helpers.
"""

from __future__ import annotations

import warnings

import pytest
import rdflib

from cybedtools._conformance import assert_matches_golden, conformance_dir
from cybedtools.queries import (
    element_framework_bindings,
    element_text,
    example_framework_bindings,
    framework_metadata,
    organizing_unit_framework_bindings,
    role_element_bindings,
    role_framework_bindings,
    subpoint_framework_bindings,
    unit_element_bindings,
    unit_relation_bindings,
)


@pytest.fixture(scope="module")
def fixture_graph() -> rdflib.Graph:
    """Parse the shared conformance fixture graph once per test module."""
    graph = rdflib.Graph()
    graph.parse(str(conformance_dir() / "fixture.nt"), format="nt")
    return graph


def test_framework_metadata_matches_golden(fixture_graph: rdflib.Graph) -> None:
    """framework_metadata() matches goldens/framework_metadata.csv."""
    assert_matches_golden(framework_metadata(fixture_graph), "framework_metadata", sort_by=["framework"])


def test_unit_element_bindings_matches_golden(fixture_graph: rdflib.Graph) -> None:
    """unit_element_bindings() matches goldens/unit_element_bindings.csv."""
    assert_matches_golden(
        unit_element_bindings(fixture_graph), "unit_element_bindings", sort_by=["role", "element"]
    )


def test_unit_relation_bindings_matches_golden(fixture_graph: rdflib.Graph) -> None:
    """unit_relation_bindings() matches goldens/unit_relation_bindings.csv."""
    assert_matches_golden(
        unit_relation_bindings(fixture_graph),
        "unit_relation_bindings",
        sort_by=["from_unit", "to_unit", "relation"],
    )


def test_role_framework_bindings_columns_and_rows(fixture_graph: rdflib.Graph) -> None:
    """role_framework_bindings() returns the documented columns and only cybed:Role subjects.

    No golden CSV ships for this helper (only framework_metadata,
    unit_element_bindings, and unit_relation_bindings are in the
    conformance contract), so this checks shape and semantics directly
    against the fixture instead of a golden file.
    """
    result = role_framework_bindings(fixture_graph)
    assert list(result.columns) == ["role", "role_name", "framework", "framework_name", "framework_slug"]
    # Fixture has four cybed:Role subjects, all with a valid partOf to a framework.
    assert len(result) == 4
    assert set(result["framework_slug"]) == {"fixture-wf1", "fixture-wf2"}


def test_organizing_unit_framework_bindings_includes_non_role_units(fixture_graph: rdflib.Graph) -> None:
    """organizing_unit_framework_bindings() includes the pedagogy unit, unlike role_framework_bindings()."""
    result = organizing_unit_framework_bindings(fixture_graph)
    assert list(result.columns) == ["unit", "unit_name", "framework", "framework_name", "framework_slug"]
    assert "fixture-ped1" in set(result["framework_slug"])


def test_element_framework_bindings_columns(fixture_graph: rdflib.Graph) -> None:
    """element_framework_bindings() has no name column and covers the broad element cut."""
    result = element_framework_bindings(fixture_graph)
    assert list(result.columns) == ["element", "framework", "framework_name", "framework_slug"]
    assert len(result) > 0


def test_example_framework_bindings_is_subset_of_elements(fixture_graph: rdflib.Graph) -> None:
    """example_framework_bindings() returns only cybed:Example subjects."""
    examples = example_framework_bindings(fixture_graph)
    elements = element_framework_bindings(fixture_graph)
    assert list(examples.columns) == ["example", "framework", "framework_name", "framework_slug"]
    assert set(examples["example"]).issubset(set(elements["element"]))
    assert len(examples) == 1


def test_subpoint_framework_bindings_is_subset_of_elements(fixture_graph: rdflib.Graph) -> None:
    """subpoint_framework_bindings() returns only cybed:Subpoint subjects."""
    subpoints = subpoint_framework_bindings(fixture_graph)
    elements = element_framework_bindings(fixture_graph)
    assert list(subpoints.columns) == ["subpoint", "framework", "framework_name", "framework_slug"]
    assert set(subpoints["subpoint"]).issubset(set(elements["element"]))
    assert len(subpoints) == 1


def test_element_text_columns_and_shared_text(fixture_graph: rdflib.Graph) -> None:
    """element_text() returns element/text pairs, including the element shared across units."""
    result = element_text(fixture_graph)
    assert list(result.columns) == ["element", "text"]
    shared = "https://w3id.org/cybed/ontology#element/fixture-el-role1"
    assert shared in set(result["element"])


def test_role_element_bindings_is_deprecated_alias(fixture_graph: rdflib.Graph) -> None:
    """role_element_bindings() warns DeprecationWarning and returns unit_element_bindings()'s result."""
    with pytest.warns(DeprecationWarning, match="unit_element_bindings"):
        deprecated_result = role_element_bindings(fixture_graph)
    direct_result = unit_element_bindings(fixture_graph)
    assert deprecated_result.equals(direct_result)


def test_role_element_bindings_warning_is_exactly_one() -> None:
    """Calling the deprecated alias raises exactly one warning, not a cascade."""
    graph = rdflib.Graph()
    graph.parse(str(conformance_dir() / "fixture.nt"), format="nt")
    with warnings.catch_warnings(record=True) as caught:
        warnings.simplefilter("always")
        role_element_bindings(graph)
    deprecation_warnings = [w for w in caught if issubclass(w.category, DeprecationWarning)]
    assert len(deprecation_warnings) == 1
