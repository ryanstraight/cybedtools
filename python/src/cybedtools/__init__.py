"""Python interface to the cybedtools cross-framework cybersecurity workforce and learning frameworks graph.

This release is a placeholder that reserves the project name on PyPI. It exposes
no query functions yet. The R package at https://github.com/ryanstraight/cybedtools
is the working interface today.

Attributes
----------
__version__ : str
    The installed distribution version, read from package metadata.
"""

from importlib.metadata import PackageNotFoundError, version as _version

__all__ = ["__version__"]

try:
    __version__ = _version("cybedtools")
except PackageNotFoundError:  # pragma: no cover - only when running from a source tree
    __version__ = "0.0.0"
