"""Shared helpers for the Python test suite (schema checks, documentation
checks and real-provider plans). Run from the repository root:

    python -m pytest tests/python
"""
import json
import os
import pathlib
import re
import shutil

import pytest
import yaml

REPO = pathlib.Path(__file__).resolve().parents[2]
SCHEMA_PATH = REPO / "schemas" / "cloud-run-config.schema.json"
EXAMPLES = REPO / "examples"

# templatefile() directives on a line of their own, e.g. `%{ if env == "prod" ~}`.
DIRECTIVE_LINE = re.compile(r"^[ \t]*%\{[^}]*\}[ \t]*$", re.M)


def example_configs():
    """Every YAML configuration under examples/."""
    return sorted(EXAMPLES.rglob("*.yaml"))


def fixture_configs():
    """YAML configurations used by the unit and live tests."""
    return sorted((REPO / "tests" / "fixtures").glob("*.yaml")) + sorted((REPO / "tests" / "integration").glob("*.yaml"))


def load_yaml(path):
    """Parse a configuration the way an editor sees it: before template
    rendering. ${...} placeholders stay strings (the schema accepts them);
    directive lines are dropped, which keeps every branch of an if/else."""
    with open(path, encoding="utf-8") as fh:
        text = DIRECTIVE_LINE.sub("", fh.read())
    return yaml.safe_load(text) or {}


@pytest.fixture(scope="session")
def schema():
    with open(SCHEMA_PATH, encoding="utf-8") as fh:
        return json.load(fh)


@pytest.fixture(scope="session")
def terraform_bin():
    """Terraform binary for the plan tests: $TERRAFORM_BIN or terraform on PATH."""
    path = os.environ.get("TERRAFORM_BIN") or shutil.which("terraform")
    if not path:
        pytest.skip("terraform not found (set TERRAFORM_BIN)")
    return path


def resolve(schema, node):
    """Follow a $ref (one level)."""
    ref = node.get("$ref") if isinstance(node, dict) else None
    return schema["definitions"][ref.split("/")[-1]] if ref else node


def ref_names(node):
    """Definition names a property points to through $ref, anyOf or allOf."""
    names = []
    for option in [node] + node.get("anyOf", []) + node.get("allOf", []):
        if "$ref" in option:
            names.append(option["$ref"].split("/")[-1])
    return names


def object_definitions(schema):
    """Definitions that describe mappings with fixed keys."""
    return {name: d for name, d in schema["definitions"].items() if "properties" in d}


def walk(schema, value, definition, path=""):
    """Yield (definition, key, path) for every key in `value`, following the
    schema the way validation.tf does."""
    defs = schema["definitions"]
    node = schema if definition == "root" else defs[definition]
    if not isinstance(value, dict):
        return
    for key, child in value.items():
        child_path = f"{path}.{key}" if path else key
        yield definition, key, child_path
        prop = node.get("properties", {}).get(key)
        if prop is None or child is None:
            continue
        objects = [n for n in ref_names(prop) if "properties" in defs[n]]
        if objects:
            yield from walk(schema, child, objects[0], child_path)
        items = prop.get("items")
        if items is not None and isinstance(child, list):
            for n in [n for n in ref_names(items) if "properties" in defs[n]][:1]:
                for i, item in enumerate(child):
                    yield from walk(schema, item, n, f"{child_path}[{i}]")
        values = prop.get("additionalProperties")
        if isinstance(values, dict) and isinstance(child, dict):
            for n in [n for n in ref_names(values) if "properties" in defs[n]][:1]:
                for k, item in child.items():
                    yield from walk(schema, item, n, f"{child_path}.{k}")
