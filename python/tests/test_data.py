"""Conformance tests for framework_summary(), framework_licenses(), cybed_license()."""

from __future__ import annotations

import pytest

from cybedtools._conformance import assert_matches_golden
from cybedtools.data import (
    CybedtoolsFrameworkNotFoundError,
    CybedtoolsScalarInputError,
    cybed_license,
    framework_licenses,
    framework_summary,
)


def test_framework_summary_matches_golden() -> None:
    """framework_summary() matches inst/conformance/goldens/framework_summary.csv."""
    assert_matches_golden(framework_summary(), "framework_summary", sort_by=["framework_slug"])


def test_cybed_license_no_arg_matches_golden() -> None:
    """cybed_license() with no argument matches inst/conformance/goldens/cybed_license.csv."""
    assert_matches_golden(cybed_license(), "cybed_license", sort_by=["slug"])


def test_framework_licenses_is_the_same_table_as_cybed_license() -> None:
    """framework_licenses() is exactly cybed_license()'s no-argument result."""
    assert_matches_golden(framework_licenses(), "cybed_license", sort_by=["slug"])


def test_cybed_license_single_slug_returns_one_row() -> None:
    """cybed_license(slug) returns exactly the matching row."""
    row = cybed_license("nice-v2")
    assert len(row) == 1
    assert row["slug"].iloc[0] == "nice-v2"


def test_cybed_license_unknown_slug_raises() -> None:
    """An unknown slug raises CybedtoolsFrameworkNotFoundError, not a silent empty frame."""
    with pytest.raises(CybedtoolsFrameworkNotFoundError):
        cybed_license("not-a-real-framework")


def test_cybed_license_non_string_slug_raises() -> None:
    """A non-string, non-None slug raises CybedtoolsScalarInputError."""
    with pytest.raises(CybedtoolsScalarInputError):
        cybed_license(123)  # type: ignore[arg-type]


def test_cybed_license_accepts_the_short_release_slug_as_an_alias() -> None:
    """cybed_license() accepts either the versioned or short release slug."""
    assert cybed_license("nice").equals(cybed_license("nice-v2"))
    assert cybed_license("otccf").equals(cybed_license("otccf-v1.1"))
    assert cybed_license("cybok").equals(cybed_license("cybok-v1.1.0"))
    # csta-2026 is its own framework, not an edition of csta: the short
    # slug "csta" resolves to csta-2017, never csta-2026.
    assert cybed_license("csta").equals(cybed_license("csta-2017"))
    assert not cybed_license("csta").equals(cybed_license("csta-2026"))
