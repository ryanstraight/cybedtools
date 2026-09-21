"""Framework-slug alias resolution, shared by :mod:`cybedtools.data` and
:mod:`cybedtools.similarity`.

Mirrors ``R/slug-alias.R``. Two framework-slug vocabularies exist in this
package: **versioned** slugs (``"nice-v2"``, ``"otccf-v1.1"``), carried by
``framework_summary()["framework_slug"]`` and ``framework_licenses()["slug"]``
and minted into every framework node's IRI; and **short** release-file slugs
(``"nice"``, ``"otccf"``), assigned by ``docs/data-release.yml`` and recorded
in the release manifest's ``slug`` field (with the versioned form alongside
it as ``license_slug``). :func:`cybedtools.fetch.cybed_fetch` already
resolves either form because it reads the release manifest at call time.
Every other public function that takes a framework slug
(:func:`cybedtools.data.cybed_license`,
:func:`cybedtools.similarity.framework_similarity`) has no manifest to
consult, so this module derives the same short-slug rule
``scripts/030-export-release.R``'s ``release_license_row()`` applies (strip a
trailing version suffix; a framework that is its own edition, not a version
of a shorter-named sibling, keeps its full slug) from the shipped
``framework_summary``/``framework_licenses`` tables alone, with no network or
build-time input.
"""

from __future__ import annotations

import re

__all__ = ["framework_slug_alias_map", "resolve_framework_slug"]

_VERSION_SUFFIX_RE = re.compile(r"-v?[0-9][0-9.]*$")


def framework_slug_alias_map(versioned_slugs: list[str]) -> dict[str, str]:
    """Alias map from release (short) slug to canonical versioned slug.

    Parameters
    ----------
    versioned_slugs : list[str]
        Every versioned framework slug (e.g. ``framework_summary()
        ["framework_slug"]``).

    Returns
    -------
    dict[str, str]
        Keys are release/short slugs, values are the canonical versioned
        slugs.
    """
    alias: dict[str, str] = {}
    for slug in versioned_slugs:
        # csta-2026 is a framework in its own right, not an edition of csta
        # -- csta-2017 already claims the "csta" short slug (mirrors the
        # `reserved` handling in scripts/030-export-release.R's
        # release_license_row()).
        short = slug if slug == "csta-2026" else _VERSION_SUFFIX_RE.sub("", slug)
        alias[short] = slug
    return alias


class CybedtoolsFrameworkNotFoundError(ValueError):
    """No known slug (either vocabulary) matched."""


def resolve_framework_slug(slug: str, known: list[str], arg: str = "slug") -> str:
    """Resolve a framework slug (either vocabulary) against known versioned slugs.

    Parameters
    ----------
    slug : str
        The slug to resolve, in either vocabulary.
    known : list[str]
        Valid, already-versioned slugs to resolve against.
    arg : str
        The argument name to use in the error message.

    Returns
    -------
    str
        The canonical versioned slug.

    Raises
    ------
    CybedtoolsFrameworkNotFoundError
        If `slug` cannot be resolved to a member of `known`.
    """
    if slug in known:
        return slug

    alias_map = framework_slug_alias_map(known)
    if slug in alias_map and alias_map[slug] in known:
        return alias_map[slug]

    known_sorted = ", ".join(sorted(known))
    raise CybedtoolsFrameworkNotFoundError(
        f"Unknown framework slug.\n"
        f"`{arg}`: '{slug}'.\n"
        f"Known slugs: {known_sorted}."
    )
