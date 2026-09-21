"""Tests for cybed_fetch() / load_graph() against the committed mock release.

No test in this module reaches the network: cybedtools.fetch.set_release_url
points at inst/conformance/mock-release (a copy of which is checked into
tests/fixtures/conformance/) via a file:// URL, matching the R test suite's
`options(cybedtools.release_url = ...)` pattern documented in
inst/conformance/README.md.
"""

from __future__ import annotations

from pathlib import Path

import pytest

import cybedtools
from cybedtools._conformance import conformance_dir
from cybedtools.fetch import (
    CybedtoolsFrameworkNotFoundError,
    CybedtoolsHashMismatchError,
    cybed_fetch,
    set_release_url,
)


@pytest.fixture
def mock_release_url(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> str:
    """Point cybedtools at the committed mock release via a file:// URL.

    Also redirects the user cache directory into a temp path (via
    platformdirs' env var override) so a run never touches the real machine
    cache and each test starts from a clean cache.
    """
    monkeypatch.setenv("XDG_CACHE_HOME", str(tmp_path / "cache"))
    monkeypatch.setattr(
        "cybedtools.fetch.platformdirs.user_cache_dir",
        lambda name: str(tmp_path / "cache" / name),
    )
    mock_release_dir = conformance_dir() / "mock-release"
    url = mock_release_dir.resolve().as_uri()
    set_release_url(url)
    yield url
    set_release_url(None)


def test_cybed_fetch_all_frameworks(mock_release_url: str) -> None:
    """With frameworks=None, every framework in the mock manifest is fetched."""
    result = cybed_fetch(version="1.0.0")
    assert set(result["framework_slug"]) == {"fixture-wf1", "fixture-wf2", "fixture-ped1"}
    assert result["sha256_verified"].all()
    for path_str in result["path"]:
        assert Path(path_str).is_file()


def test_cybed_fetch_one_framework(mock_release_url: str) -> None:
    """A single requested slug fetches only that framework."""
    result = cybed_fetch(frameworks=["fixture-wf1"], version="1.0.0")
    assert list(result["framework_slug"]) == ["fixture-wf1"]


def test_cybed_fetch_unknown_slug_raises(mock_release_url: str) -> None:
    """An unrecognized slug raises rather than silently skipping."""
    with pytest.raises(CybedtoolsFrameworkNotFoundError):
        cybed_fetch(frameworks=["not-a-real-framework"], version="1.0.0")


def test_cybed_fetch_is_cached_on_second_call(mock_release_url: str) -> None:
    """A second fetch of the same framework reuses the cached, hash-verified file."""
    first = cybed_fetch(frameworks=["fixture-wf2"], version="1.0.0")
    second = cybed_fetch(frameworks=["fixture-wf2"], version="1.0.0")
    assert first["path"].iloc[0] == second["path"].iloc[0]


def test_cybed_fetch_hash_mismatch_deletes_file(
    mock_release_url: str, tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A corrupted manifest hash raises and does not leave a cached file behind."""
    import json
    import shutil

    corrupt_release = tmp_path / "corrupt-release" / "1.0.0"
    shutil.copytree(conformance_dir() / "mock-release" / "1.0.0", corrupt_release)
    manifest_path = corrupt_release / "manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["files"][0]["sha256"] = "0" * 64
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    set_release_url(corrupt_release.parent.resolve().as_uri())
    bad_slug = manifest["files"][0]["slug"]
    with pytest.raises(CybedtoolsHashMismatchError):
        cybed_fetch(frameworks=[bad_slug], version="1.0.0")

    cache_root = Path(cybedtools.fetch._cache_dir()) / "1.0.0"  # noqa: SLF001
    assert not any(cache_root.glob(f"{bad_slug}*"))


def test_cybed_fetch_bare_string_is_one_slug_not_iterable_of_characters(mock_release_url: str) -> None:
    """A bare str `frameworks` argument is one slug, not an iterable of characters."""
    result = cybed_fetch(frameworks="fixture-wf1", version="1.0.0")
    assert list(result["framework_slug"]) == ["fixture-wf1"]


def test_cybed_fetch_result_carries_both_slug_columns(mock_release_url: str) -> None:
    """The result names both the versioned and short release slug explicitly."""
    result = cybed_fetch(frameworks=["fixture-wf1"], version="1.0.0")
    assert "framework_slug" in result.columns
    assert "release_slug" in result.columns
    # The mock manifest carries no license_slug, so both fall back to the
    # same (release) slug -- still two explicit columns.
    assert result["framework_slug"].iloc[0] == "fixture-wf1"
    assert result["release_slug"].iloc[0] == "fixture-wf1"


def test_cybed_fetch_accepts_data_v_prefixed_version(mock_release_url: str) -> None:
    """A `data-v`-prefixed version (matching a GitHub release tag) is accepted."""
    plain = cybed_fetch(frameworks=["fixture-wf1"], version="1.0.0")
    prefixed = cybed_fetch(frameworks=["fixture-wf1"], version="data-v1.0.0")
    assert plain["path"].iloc[0] == prefixed["path"].iloc[0]


def test_load_graph_returns_populated_rdflib_graph(mock_release_url: str) -> None:
    """load_graph() parses the fetched framework files into one rdflib.Graph."""
    import rdflib

    graph = cybedtools.load_graph(frameworks=["fixture-wf1"], version="1.0.0")
    assert isinstance(graph, rdflib.Graph)
    assert len(graph) > 0
