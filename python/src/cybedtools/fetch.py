"""User-facing data loader for the public per-framework data release.

Mirrors ``R/cybed-fetch.R``: ``cybed_fetch()`` downloads and hash-verifies
release files into a per-platform user cache directory and never writes
anywhere else. ``load_graph()`` turns cached files into a graph object.

Release URL resolution order (mirroring the R package's
``getOption("cybedtools.release_url")`` then ``Sys.getenv("CYBEDTOOLS_RELEASE_URL")``
then a built-in default):

1. :func:`set_release_url` (a module-level override, the closest Python
   equivalent to an R option -- R has no per-session option store outside
   its global options list, and a module attribute is the idiomatic
   stand-in).
2. The ``CYBEDTOOLS_RELEASE_URL`` environment variable.
3. The built-in default, this repository's GitHub release assets.

Downloading is done with the standard library (``urllib.request``) rather
than a dependency such as ``pooch``: the only features needed are a GET of a
small file over ``http(s)://`` or ``file://`` and a SHA-256 check against a
value already carried in the manifest, and stdlib covers both with no
transitive dependency risk. If resumable/chunked downloads of much larger
files become necessary later, revisit this call.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import tempfile
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse

import pandas as pd
import platformdirs

from cybedtools._graph import GraphBackend, parse_graph

__all__ = [
    "CybedtoolsDownloadFailedError",
    "CybedtoolsFrameworkNotFoundError",
    "CybedtoolsHashMismatchError",
    "cybed_fetch",
    "load_graph",
    "set_release_url",
]

_DEFAULT_BASE_URL = "https://github.com/ryanstraight/cybedtools/releases/download/data-v{version}"

_release_url_override: str | None = None


class CybedtoolsDownloadFailedError(RuntimeError):
    """A release file (manifest or framework archive) could not be downloaded."""


class CybedtoolsFrameworkNotFoundError(ValueError):
    """A requested framework slug is not present in the release manifest."""


class CybedtoolsHashMismatchError(RuntimeError):
    """A downloaded file's SHA-256 did not match the manifest's declared hash."""


def set_release_url(url: str | None) -> None:
    """Set (or clear) a process-wide override for the release base URL.

    The closest Python equivalent to the R package's
    ``options(cybedtools.release_url = ...)``. Pass ``None`` to clear the
    override and fall back to the ``CYBEDTOOLS_RELEASE_URL`` environment
    variable or the built-in default.

    Parameters
    ----------
    url : str or None
        A base URL, optionally carrying a literal ``{version}`` placeholder
        (see :func:`_release_url_for`). ``None`` clears the override.
    """
    global _release_url_override
    _release_url_override = url


def _release_base_url() -> str:
    """Resolve the configured release base URL.

    Returns
    -------
    str
        A URL with no trailing slash.
    """
    if _release_url_override:
        return _release_url_override.rstrip("/")
    env = os.environ.get("CYBEDTOOLS_RELEASE_URL")
    if env:
        return env.rstrip("/")
    return _DEFAULT_BASE_URL


DATA_RELEASE = "2026.09.2"
"""Data release this package version was built and tested against."""


def _release_url_for(base_url: str, version: str, filename: str) -> str:
    """Build the URL of one release file (the manifest or a framework's ``.nt.gz``).

    A GitHub release's assets are tagged ``data-v<version>`` and sit
    directly under that tag with no further version segment, so a base URL
    carrying the ``{version}`` placeholder has the version substituted in
    place rather than appended. Every other base URL (a mirror, or a mock
    release directory used in tests) nests each version below the fixed
    base.

    Parameters
    ----------
    base_url : str
        From :func:`_release_base_url`.
    version : str
        Release version (or ``"latest"``).
    filename : str
        E.g. ``"manifest.json"`` or ``"<slug>.nt.gz"``.

    Returns
    -------
    str
        The resolved URL.
    """
    if "{version}" in base_url:
        return base_url.replace("{version}", version) + "/" + filename
    return f"{base_url}/{version}/{filename}"


def _cache_dir() -> Path:
    """The package's cache directory, created if it does not yet exist.

    Uses :mod:`platformdirs` rather than hand-rolled XDG logic: it is the
    de facto standard for per-platform user cache/config/data directories in
    Python (analogous to R's ``tools::R_user_dir()``) and is a small,
    dependency-free, widely vendored package.

    Returns
    -------
    Path
        The cache directory root (not version-scoped).
    """
    directory = Path(platformdirs.user_cache_dir("cybedtools"))
    directory.mkdir(parents=True, exist_ok=True)
    return directory


def _download(url: str, destfile: Path) -> None:
    """Download one URL to one destination path, for ``http(s)://`` and ``file://``.

    Parameters
    ----------
    url : str
        Source URL.
    destfile : Path
        Destination path. Written atomically (via a temp file in the same
        directory, then renamed) so a failed download never leaves a partial
        file at the final path.

    Raises
    ------
    CybedtoolsDownloadFailedError
        If the URL cannot be read, or the result is empty.
    """
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https", "file"):
        msg = f"Unsupported URL scheme: {parsed.scheme!r} (url: {url})"
        raise CybedtoolsDownloadFailedError(msg)

    destfile.parent.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_name = tempfile.mkstemp(dir=str(destfile.parent))
    tmp_path = Path(tmp_name)
    try:
        with os.fdopen(tmp_fd, "wb") as tmp_handle:
            try:
                with urllib.request.urlopen(url) as response:  # noqa: S310 - scheme checked above
                    shutil.copyfileobj(response, tmp_handle)
            except (OSError, ValueError) as exc:
                raise CybedtoolsDownloadFailedError(
                    f"Could not download a release file.\n"
                    f"URL: {url}.\n"
                    "Call `set_release_url(...)` or set the CYBEDTOOLS_RELEASE_URL "
                    "environment variable to point at a reachable release "
                    "(a file:// URL works for local testing)."
                ) from exc
        if tmp_path.stat().st_size == 0:
            msg = f"Could not download a release file (empty response).\nURL: {url}."
            raise CybedtoolsDownloadFailedError(msg)
        os.replace(tmp_path, destfile)
    finally:
        tmp_path.unlink(missing_ok=True)


def _sha256_of(path: Path) -> str:
    """Compute the SHA-256 hex digest of a file's bytes.

    Parameters
    ----------
    path : Path
        File to hash.

    Returns
    -------
    str
        Lowercase hex digest.
    """
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _read_manifest(base_url: str, version: str) -> dict:
    """Download and parse a release's ``manifest.json``.

    Parameters
    ----------
    base_url : str
        From :func:`_release_base_url`.
    version : str
        Release version segment (or ``"latest"``).

    Returns
    -------
    dict
        The parsed manifest.
    """
    url = _release_url_for(base_url, version, "manifest.json")
    with tempfile.TemporaryDirectory() as tmp_dir:
        tmp = Path(tmp_dir) / "manifest.json"
        _download(url, tmp)
        return json.loads(tmp.read_text(encoding="utf-8"))


@dataclass(frozen=True)
class FetchedFramework:
    """One row of a :func:`cybed_fetch` result."""

    framework_slug: str
    path: str
    sha256_verified: bool


def cybed_fetch(
    frameworks: list[str] | None = None, version: str | None = None
) -> pd.DataFrame:
    """Download and hash-verify per-framework release files into the user cache.

    Mirrors ``R/cybed-fetch.R``'s ``cybed_fetch()``. Already-cached files
    whose hash still matches the manifest are not re-downloaded.

    Parameters
    ----------
    frameworks : list[str] or None
        Framework slugs to fetch (as carried by
        ``framework_summary()["framework_slug"]``, e.g. ``"nice-v2"``), or
        ``None`` (the default) for every framework the release manifest
        ships.
    version : str or None
        Release version (e.g. ``"1.0.0"``), or ``None`` (the default) for
        the data release this package version was built against, ``DATA_RELEASE``.

    Returns
    -------
    pandas.DataFrame
        One row per fetched framework: columns ``framework_slug``, ``path``
        (the cached file's local path, as a string), ``sha256_verified``
        (bool, always ``True`` on return -- a mismatch raises instead of
        returning ``False``).

    Raises
    ------
    CybedtoolsDownloadFailedError
        If the manifest or a framework file cannot be downloaded.
    CybedtoolsFrameworkNotFoundError
        If a requested slug is not in the release manifest.
    CybedtoolsHashMismatchError
        If a downloaded file's SHA-256 does not match the manifest.
    """
    base_url = _release_base_url()
    resolved_version = version if version is not None else DATA_RELEASE
    manifest = _read_manifest(base_url, resolved_version)

    files = manifest["files"]
    manifest_slugs = [entry["slug"] for entry in files]

    requested = frameworks if frameworks is not None else manifest_slugs
    unknown = sorted(set(requested) - set(manifest_slugs))
    if unknown:
        raise CybedtoolsFrameworkNotFoundError(
            f"Unknown framework slug(s) for this release: {', '.join(unknown)}. "
            f"Known slugs: {', '.join(manifest_slugs)}."
        )

    cache_dir = _cache_dir() / resolved_version
    cache_dir.mkdir(parents=True, exist_ok=True)

    by_slug = {entry["slug"]: entry for entry in files}
    rows: list[FetchedFramework] = []
    for slug in requested:
        entry = by_slug[slug]
        dest = cache_dir / entry["file"]

        needs_download = not dest.exists() or _sha256_of(dest) != entry["sha256"]

        if needs_download:
            url = _release_url_for(base_url, resolved_version, entry["file"])
            _download(url, dest)
            actual = _sha256_of(dest)
            if actual != entry["sha256"]:
                dest.unlink(missing_ok=True)
                raise CybedtoolsHashMismatchError(
                    f"Downloaded file does not match the release manifest's hash.\n"
                    f"Framework: {slug}.\n"
                    f"Expected sha256: {entry['sha256']}.\n"
                    f"Got sha256: {actual}.\n"
                    "The file was deleted rather than cached in an unverified state."
                )

        rows.append(
            FetchedFramework(framework_slug=slug, path=str(dest), sha256_verified=True)
        )

    return pd.DataFrame(
        {
            "framework_slug": [row.framework_slug for row in rows],
            "path": [row.path for row in rows],
            "sha256_verified": pd.array(
                [row.sha256_verified for row in rows], dtype="boolean"
            ),
        }
    )


def load_graph(
    frameworks: list[str] | None = None,
    version: str | None = None,
    *,
    backend: GraphBackend = "rdflib",
) -> object:
    """Load a graph from the cached release files, fetching first if needed.

    Ensures the requested frameworks are cached (calling :func:`cybed_fetch`
    internally, a no-op for files already cached with a verified hash) and
    parses them into one shared graph object.

    Parameters
    ----------
    frameworks : list[str] or None
        See :func:`cybed_fetch`.
    version : str or None
        See :func:`cybed_fetch`.
    backend : {"rdflib", "pyoxigraph"}
        Graph backend to build. See :mod:`cybedtools._graph`.

    Returns
    -------
    object
        An ``rdflib.Graph`` (default) or ``pyoxigraph.Store``, with every
        requested framework's triples loaded.
    """
    fetched = cybed_fetch(frameworks=frameworks, version=version)

    import gzip

    with tempfile.TemporaryDirectory() as tmp_dir:
        nt_paths: list[Path] = []
        for path_str in fetched["path"]:
            gz_path = Path(path_str)
            nt_path = Path(tmp_dir) / (gz_path.stem + ".nt")
            with gzip.open(gz_path, "rb") as src, nt_path.open("wb") as dst:
                shutil.copyfileobj(src, dst)
            nt_paths.append(nt_path)
        return parse_graph(nt_paths, backend=backend)
