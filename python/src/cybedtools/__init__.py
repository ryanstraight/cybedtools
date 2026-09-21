"""Python interface to the cybedtools cross-framework cybersecurity workforce and learning frameworks graph.

This release builds the foundation of the Python port: data loading
(:func:`cybed_fetch`, :func:`load_graph`) and the shipped reference tables
(:func:`framework_summary`, :func:`framework_licenses`, :func:`cybed_license`).
Query helpers over a loaded graph (``framework_metadata()``,
``unit_element_bindings()``, ``framework_similarity()``, and so on) are not
yet implemented; see the R package at
https://github.com/ryanstraight/cybedtools for the working interface today.

Attributes
----------
__version__ : str
    The installed distribution version, read from package metadata.
"""

from importlib.metadata import PackageNotFoundError as _PackageNotFoundError
from importlib.metadata import version as _version

from cybedtools.data import cybed_license, framework_licenses, framework_summary
from cybedtools.fetch import cybed_fetch, load_graph, set_release_url

__all__ = [
    "__version__",
    "cybed_fetch",
    "cybed_license",
    "framework_licenses",
    "framework_summary",
    "load_graph",
    "set_release_url",
]

try:
    __version__ = _version("cybedtools")
except _PackageNotFoundError:  # pragma: no cover - only when running from a source tree
    __version__ = "0.0.0"
