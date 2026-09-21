"""Conformance harness smoke tests plus placeholders for not-yet-implemented functions.

See inst/conformance/README.md (the repository root's conformance contract)
and cybedtools._conformance for the shared loading/comparison helpers.
Function-specific conformance assertions for framework_summary()/
cybed_license() live in test_data.py; this module covers the harness itself
and reserves named slots for the query-graph functions a later change adds
(framework_metadata(), unit_element_bindings(), unit_relation_bindings(),
framework_similarity()).
"""

from __future__ import annotations

import filecmp

import pytest

from cybedtools._conformance import conformance_dir, load_golden


def test_conformance_dir_is_found() -> None:
    """The packaged fixture copy (or the repo-root fallback) resolves to a real directory."""
    assert conformance_dir().is_dir()


def test_load_golden_framework_summary() -> None:
    """The golden loader reads framework_summary.csv with a header and rows."""
    golden = load_golden("framework_summary")
    assert list(golden.columns)[0] == "framework_slug"
    assert len(golden) > 0


def test_fixture_copy_matches_source() -> None:
    """tests/fixtures/conformance stays byte-identical to the repo-root inst/conformance copy.

    Only meaningful inside a full worktree checkout (the repo-root copy is
    absent from an extracted sdist, where this test is skipped rather than
    failed).
    """
    packaged = conformance_dir()
    repo_root_source = packaged.parents[3] / "inst" / "conformance"
    if not repo_root_source.is_dir():
        pytest.skip("Running outside a full worktree checkout; no repo-root copy to compare.")
    if packaged == repo_root_source:
        pytest.skip("conformance_dir() resolved directly to the repo-root copy.")

    for name in ("framework_summary.csv", "cybed_license.csv"):
        packaged_file = packaged / "goldens" / name
        source_file = repo_root_source / "goldens" / name
        assert filecmp.cmp(packaged_file, source_file, shallow=False), (
            f"{packaged_file} has drifted from {source_file}. Re-copy it "
            "(see python/tools/export_r_data.R)."
        )


@pytest.mark.skip(reason="framework_metadata() is not yet implemented in the Python port.")
def test_framework_metadata_matches_golden() -> None:
    """Placeholder: framework_metadata(graph) will match goldens/framework_metadata.csv."""


@pytest.mark.skip(reason="unit_element_bindings() is not yet implemented in the Python port.")
def test_unit_element_bindings_matches_golden() -> None:
    """Placeholder: unit_element_bindings(graph) will match goldens/unit_element_bindings.csv."""


@pytest.mark.skip(reason="unit_relation_bindings() is not yet implemented in the Python port.")
def test_unit_relation_bindings_matches_golden() -> None:
    """Placeholder: unit_relation_bindings(graph) will match goldens/unit_relation_bindings.csv."""


@pytest.mark.skip(reason="framework_similarity() is not yet implemented in the Python port.")
def test_framework_similarity_matches_golden() -> None:
    """Placeholder: framework_similarity(graph, from_, to, n) will match goldens/framework_similarity.csv."""
