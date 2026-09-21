"""Golden-file loading and comparison helpers for conformance tests.

The conformance contract is ``inst/conformance/README.md`` in the repository
root. These helpers exist so ``tests/test_conformance.py`` states the
contract once (rounding, sort key, NA handling) rather than re-deriving it
per test.

Fixture location: this module looks for goldens under
``tests/fixtures/conformance/`` first (a copy checked into ``python/`` so
the sdist, which only packages ``python/``, can run its own test suite with
no dependency on the outer repository), then falls back to
``inst/conformance/`` at the repository root (useful when developing inside
a full worktree checkout, so the two locations cannot silently drift without
a test noticing -- see ``test_conformance.py::test_fixture_copy_matches_source``).
"""

from __future__ import annotations

import os
from pathlib import Path

import pandas as pd

_THIS_FILE = Path(__file__).resolve()


def _candidate_conformance_dirs() -> list[Path]:
    """Directories to search for the conformance fixtures, in priority order.

    An explicit ``CYBEDTOOLS_CONFORMANCE_DIR`` wins. Otherwise the search runs
    relative to this file (editable or source checkout) and then relative to
    the working directory, which covers a non-editable install tested from
    ``python/`` or from the repository root.
    """
    candidates: list[Path] = []
    override = os.environ.get("CYBEDTOOLS_CONFORMANCE_DIR")
    if override:
        candidates.append(Path(override))
    # python/src/cybedtools/_conformance.py -> python/tests/fixtures/conformance
    candidates.append(_THIS_FILE.parents[2] / "tests" / "fixtures" / "conformance")
    # python/src/cybedtools/_conformance.py -> <repo root>/inst/conformance
    if len(_THIS_FILE.parents) > 3:
        candidates.append(_THIS_FILE.parents[3] / "inst" / "conformance")
    cwd = Path.cwd()
    candidates.append(cwd / "tests" / "fixtures" / "conformance")
    candidates.append(cwd / "python" / "tests" / "fixtures" / "conformance")
    candidates.append(cwd.parent / "inst" / "conformance")
    return candidates


def conformance_dir() -> Path:
    """Locate the conformance fixtures directory.

    Returns
    -------
    Path
        The first existing candidate directory.

    Raises
    ------
    FileNotFoundError
        If neither the packaged copy nor the repository-root copy exists.
    """
    for candidate in _candidate_conformance_dirs():
        if candidate.is_dir():
            return candidate
    searched = "\n".join(str(candidate) for candidate in _candidate_conformance_dirs())
    msg = f"Could not locate the conformance fixtures directory. Searched:\n{searched}"
    raise FileNotFoundError(msg)


def load_golden(name: str) -> pd.DataFrame:
    """Load one golden CSV by its base name (without ``.csv``).

    Parameters
    ----------
    name : str
        E.g. ``"framework_summary"`` or ``"cybed_license"``.

    Returns
    -------
    pandas.DataFrame
        Read with pandas' default (numpy-backed) dtypes and empty fields as
        ``NaN``, exactly as the golden CSV encodes it -- comparison against
        an implementation's DataFrame should normalize both sides the same
        way rather than relying on this loader to guess a target dtype.
    """
    path = conformance_dir() / "goldens" / f"{name}.csv"
    return pd.read_csv(path, keep_default_na=True, na_values=[""])


def assert_matches_golden(
    actual: pd.DataFrame, golden_name: str, *, sort_by: list[str] | None = None
) -> None:
    """Assert a DataFrame matches a golden CSV per the conformance contract.

    Applies the README's rules before comparing: sorts both sides by
    ``sort_by`` (if given; otherwise assumes both are already in the
    contract's row order), resets the index, and compares column-by-column
    as strings so that dtype differences (pyarrow ``Int64`` vs. golden
    ``int64``, ``boolean[pyarrow]`` vs. ``True``/``False`` text, and so on)
    do not themselves cause a false mismatch -- the contract is about
    *values*, not pandas dtypes. ``NA`` on either side compares equal to
    ``NA`` on the other. Any ``score``-like float column is rounded to 10
    decimal places before the string comparison, per the README.

    Parameters
    ----------
    actual : pandas.DataFrame
        The implementation's output.
    golden_name : str
        Passed to :func:`load_golden`.
    sort_by : list[str] or None
        Columns to sort both frames by before comparing. ``None`` skips
        sorting (the caller has already sorted, or order does not matter
        for this golden).

    Raises
    ------
    AssertionError
        If shapes, columns, or values differ.
    """
    golden = load_golden(golden_name)

    actual = actual.copy()
    golden = golden.copy()

    if sort_by:
        actual = actual.sort_values(sort_by).reset_index(drop=True)
        golden = golden.sort_values(sort_by).reset_index(drop=True)
    else:
        actual = actual.reset_index(drop=True)
        golden = golden.reset_index(drop=True)

    assert list(actual.columns) == list(golden.columns), (
        f"Column mismatch.\nActual:  {list(actual.columns)}\nGolden:  {list(golden.columns)}"
    )
    assert len(actual) == len(golden), (
        f"Row count mismatch: actual={len(actual)}, golden={len(golden)}"
    )

    for column in golden.columns:
        actual_col = _normalize_column(actual[column])
        golden_col = _normalize_column(golden[column])
        mismatches = actual_col.compare(golden_col)
        assert mismatches.empty, f"Column '{column}' does not match golden:\n{mismatches}"


def _normalize_column(series: pd.Series) -> pd.Series:
    """Coerce a column to a comparable string form (numbers rounded, NA unified).

    Parameters
    ----------
    series : pandas.Series
        A single column from either the actual or golden DataFrame.

    Returns
    -------
    pandas.Series
        Strings, with ``pandas.NA``/``NaN`` normalized to a single sentinel
        and any float values rounded to 10 decimal places before
        stringification (the README's similarity-``score`` rounding rule;
        harmless to apply to non-score numeric columns since none carry
        more than one decimal in the current goldens).
    """
    if pd.api.types.is_float_dtype(series) or str(series.dtype).startswith("double"):
        series = series.round(10)
    if pd.api.types.is_datetime64_any_dtype(series):
        return series.dt.strftime("%Y-%m-%d").fillna("<NA>")
    return series.map(lambda value: "<NA>" if pd.isna(value) else str(value))
