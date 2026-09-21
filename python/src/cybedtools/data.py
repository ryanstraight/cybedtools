"""Accessors for the package's shipped reference data.

Mirrors ``R/licenses.R`` and the shipped ``framework_summary`` /
``framework_licenses`` tibbles documented in ``R/data.R``. The CSV files
under ``cybedtools/_resources/`` are generated from the R package's own data
by ``python/tools/export_r_data.R`` (see that script's docstring for how and
when to re-run it) and are never hand-edited. That directory is named
``_resources`` rather than ``data`` to avoid colliding with this module's
own name (``cybedtools.data``).

Column dtypes use pandas' pyarrow-backed extension types
(``dtype_backend="pyarrow"``) rather than legacy NumPy dtypes, so integer
columns with missing values (``role_count`` is ``NA`` for frameworks with no
role construct) stay integer instead of silently upcasting to float, and
string columns stay nullable ``string[pyarrow]`` rather than ``object``.
"""

from __future__ import annotations

from functools import lru_cache
from importlib.resources import files

import pandas as pd

from cybedtools._slug_alias import framework_slug_alias_map

__all__ = ["cybed_license", "framework_licenses", "framework_summary"]


class CybedtoolsFrameworkNotFoundError(ValueError):
    """No licence row exists for the requested slug."""


class CybedtoolsScalarInputError(TypeError):
    """``slug`` was not a single string or ``None``."""


def _read_package_csv(name: str, *, bool_columns: tuple[str, ...] = (), date_columns: tuple[str, ...] = ()) -> pd.DataFrame:
    """Read one shipped CSV from ``cybedtools/_resources/`` into a DataFrame.

    Parameters
    ----------
    name : str
        Filename under the package's ``_resources/`` directory.
    bool_columns : tuple[str, ...]
        Columns to read as nullable boolean, given as literal ``TRUE``/
        ``FALSE`` (R's serialization, not Python's ``True``/``False``).
    date_columns : tuple[str, ...]
        Columns to parse as dates.

    Returns
    -------
    pandas.DataFrame
        Parsed with the pyarrow dtype backend; empty CSV fields become
        ``pandas.NA``.
    """
    resource = files("cybedtools").joinpath("_resources", name)
    with resource.open("rb") as handle:
        frame = pd.read_csv(
            handle,
            dtype_backend="pyarrow",
            true_values=["TRUE"],
            false_values=["FALSE"],
            parse_dates=list(date_columns) or None,
        )
    for column in bool_columns:
        frame[column] = frame[column].astype("boolean[pyarrow]")
    return frame


@lru_cache(maxsize=1)
def framework_summary() -> pd.DataFrame:
    """One row per framework in the cybedtools corpus.

    Mirrors the R package's ``framework_summary`` data tibble exactly
    (column names, order, and values); see its roxygen documentation in
    ``R/data.R`` for what each column means.

    Returns
    -------
    pandas.DataFrame
        Sorted by ``framework_slug``, matching
        ``inst/conformance/goldens/framework_summary.csv``.
    """
    return _read_package_csv("framework_summary.csv")


@lru_cache(maxsize=1)
def framework_licenses() -> pd.DataFrame:
    """Licence facts for the package code and every framework.

    Mirrors the R package's ``framework_licenses`` data tibble exactly. One
    row for the package's own code (``slug == "cybedtools"``) and one row
    per framework. See ``R/data.R`` for the full column documentation.

    Returns
    -------
    pandas.DataFrame
        Sorted by ``slug``, matching
        ``inst/conformance/goldens/cybed_license.csv``.
    """
    return _read_package_csv(
        "cybed_license.csv",
        bool_columns=("granted",),
        date_columns=("verified",),
    )


def cybed_license(slug: str | None = None) -> pd.DataFrame:
    """Look up the licence terms for the package or one framework.

    Mirrors ``R/licenses.R``'s ``cybed_license()``. Called with no argument
    it returns the whole :func:`framework_licenses` table. Called with a
    slug it returns that one row.

    Parameters
    ----------
    slug : str or None
        Either ``"cybedtools"`` for the package's own code, a framework slug
        as carried by ``framework_summary()["framework_slug"]`` (for example
        ``"nice-v2"``, ``"otccf-v1.1"``), or the short release-file slug
        (e.g. ``"nice"``, ``"otccf"``) documented on :func:`cybed_fetch`.
        Either form resolves to the same row. ``None``, the default, returns
        every row.

    Returns
    -------
    pandas.DataFrame
        Every row when ``slug`` is ``None``, otherwise a single-row
        DataFrame.

    Raises
    ------
    CybedtoolsScalarInputError
        If ``slug`` is not a string or ``None``.
    CybedtoolsFrameworkNotFoundError
        If ``slug`` does not match any row.
    """
    licenses = framework_licenses()

    if slug is None:
        return licenses

    if not isinstance(slug, str):
        raise CybedtoolsScalarInputError(
            f"`slug` must be a single non-missing string, or None. "
            f"Received: {type(slug).__name__}."
        )

    known = licenses["slug"].tolist()
    if slug in known:
        resolved = slug
    else:
        alias_map = framework_slug_alias_map([s for s in known if s != "cybedtools"])
        resolved = alias_map.get(slug, slug)

    row = licenses[licenses["slug"] == resolved]

    if row.empty:
        known = ", ".join(licenses["slug"].tolist())
        raise CybedtoolsFrameworkNotFoundError(
            f"No licence row for that slug.\n"
            f"Slug: '{slug}'.\n"
            f"Known slugs: {known}.\n"
            "Call `cybed_license()` with no argument for every row."
        )

    return row.reset_index(drop=True)
