"""Python interface to the cybedtools cross-framework cybersecurity workforce and learning frameworks graph.

This release builds the foundation of the Python port: data loading
(:func:`cybed_fetch`, :func:`load_graph`), the shipped reference tables
(:func:`framework_summary`, :func:`framework_licenses`, :func:`cybed_license`),
cross-framework similarity (:func:`framework_similarity`), and the query
helpers over a loaded graph (:func:`framework_metadata`,
:func:`unit_element_bindings`, and so on).

Attributes
----------
__version__ : str
    The installed distribution version, read from package metadata.
"""

from importlib.metadata import PackageNotFoundError as _PackageNotFoundError
from importlib.metadata import version as _version

from cybedtools.data import cybed_license, framework_licenses, framework_summary
from cybedtools.fetch import cybed_fetch, load_graph, set_release_url
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
from cybedtools.similarity import framework_similarity

__all__ = [
    "__version__",
    "cybed_fetch",
    "cybed_license",
    "element_framework_bindings",
    "element_text",
    "example_framework_bindings",
    "framework_licenses",
    "framework_metadata",
    "framework_similarity",
    "framework_summary",
    "load_graph",
    "organizing_unit_framework_bindings",
    "role_element_bindings",
    "role_framework_bindings",
    "set_release_url",
    "subpoint_framework_bindings",
    "unit_element_bindings",
    "unit_relation_bindings",
]

try:
    __version__ = _version("cybedtools")
except _PackageNotFoundError:  # pragma: no cover - only when running from a source tree
    __version__ = "0.0.0"
