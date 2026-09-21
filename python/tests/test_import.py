"""Import and version smoke tests."""

import sys
from pathlib import Path

if sys.version_info >= (3, 11):
    import tomllib
else:
    import tomli as tomllib

import cybedtools


def _pyproject_version() -> str:
    """Read the declared version from pyproject.toml.

    Returns
    -------
    str
        The version string declared in the ``[project]`` table.
    """
    pyproject = Path(__file__).resolve().parent.parent / "pyproject.toml"
    with pyproject.open("rb") as handle:
        return tomllib.load(handle)["project"]["version"]


def test_version_is_non_empty_string() -> None:
    """The package exposes a non-empty version string."""
    assert isinstance(cybedtools.__version__, str)
    assert cybedtools.__version__ != ""


def test_version_matches_pyproject() -> None:
    """The installed version matches the version declared in pyproject.toml."""
    assert cybedtools.__version__ == _pyproject_version()
