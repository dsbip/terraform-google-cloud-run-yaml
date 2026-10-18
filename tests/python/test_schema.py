"""The JSON Schema: is it valid, do the examples conform to it, and does it
stay in a shape that validation.tf can read?"""
import re

import pytest
from jsonschema import Draft7Validator

from conftest import REPO, example_configs, fixture_configs, load_yaml, object_definitions, ref_names, walk

# validation.tf walks the YAML this many levels deep (walk_0 ... walk_7).
WALK_LEVELS = 8


def test_schema_is_valid_draft7(schema):
    Draft7Validator.check_schema(schema)


@pytest.mark.parametrize("path", example_configs() + fixture_configs(), ids=lambda p: str(p.relative_to(REPO)))
def test_configuration_conforms_to_schema(schema, path):
    errors = sorted(Draft7Validator(schema).iter_errors(load_yaml(path)), key=lambda e: list(e.path))
    assert not errors, "\n".join(f"{'/'.join(map(str, e.path))}: {e.message}" for e in errors)


def test_object_definitions_are_closed(schema):
    """Unknown-key checks rely on every object definition listing its keys."""
    for name, d in object_definitions(schema).items():
        assert d.get("type") == "object", f"{name} needs type: object"
        assert d.get("additionalProperties") is False, f"{name} needs additionalProperties: false"


def test_nested_objects_are_named_definitions(schema):
    """validation.tf only follows $refs, so an inline object with properties
    would never be checked."""
    def inline_objects(node, where):
        if isinstance(node, dict):
            if "properties" in node and where.count("/") > 1:
                yield where
            for k, v in node.items():
                yield from inline_objects(v, f"{where}/{k}")
        elif isinstance(node, list):
            for i, v in enumerate(node):
                yield from inline_objects(v, f"{where}/{i}")

    offenders = []
    for name, d in schema["definitions"].items():
        for prop, p in d.get("properties", {}).items():
            offenders += list(inline_objects(p, f"definitions/{name}/{prop}"))
    for prop, p in schema["properties"].items():
        offenders += list(inline_objects(p, f"properties/{prop}"))
    assert not offenders, offenders


def test_schema_depth_fits_the_validation_walk(schema):
    defs = schema["definitions"]

    def depth(name, seen=()):
        node = schema if name == "root" else defs[name]
        best = 0
        for prop in node.get("properties", {}).values():
            children = [n for n in ref_names(prop) if "properties" in defs[n]]
            for key in ("items", "additionalProperties"):
                if isinstance(prop.get(key), dict):
                    children += [n for n in ref_names(prop[key]) if "properties" in defs[n]]
            for child in children:
                if child not in seen:
                    best = max(best, 1 + depth(child, seen + (child,)))
        return best

    assert depth("root") < WALK_LEVELS, f"schema is {depth('root')} levels deep; add walk levels to validation.tf"


def test_patterns_are_re2_compatible(schema):
    """Terraform evaluates the patterns with RE2: no lookaround or backreferences."""
    patterns = re.findall(r'"pattern":\s*"((?:[^"\\]|\\.)*)"', (REPO / "schemas" / "cloud-run-config.schema.json").read_text(encoding="utf-8"))
    assert patterns
    for p in patterns:
        assert not re.search(r"\(\?[=!<]|\\[1-9]", p), p


def test_defaults_forbid_identity_keys(schema):
    """Each defaults.<type> names its forbidden keys where main.tf reads them
    (allOf[1].propertyNames.not.enum), and they exist on the definition."""
    props = schema["definitions"]["defaults"]["properties"]
    for type_name in ["services", "jobs", "service_container", "job_container"]:
        all_of = props[type_name]["allOf"]
        definition = all_of[0]["$ref"].split("/")[-1]
        forbidden = all_of[1]["propertyNames"]["not"]["enum"]
        assert forbidden == ["name"], type_name
        assert set(forbidden) <= set(schema["definitions"][definition]["properties"])


def test_complete_example_uses_every_key(schema):
    """examples/complete is documented as using every configuration key."""
    used = {(d, k) for d, k, _ in walk(schema, load_yaml(REPO / "examples" / "complete" / "config.yaml"), "root")}
    expected = {(name, key) for name, d in object_definitions(schema).items() for key in d["properties"]}
    expected |= {("root", key) for key in schema["properties"]}
    missing = sorted(f"{d}.{k}" for d, k in expected - used)
    assert not missing, f"examples/complete/config.yaml does not use: {missing}"


INVALID = [
    ("unknown top-level key", {"service": {}}),
    ("unknown service key", {"services": {"a": {"descripton": "x"}}}),
    ("services as a list", {"services": [{"name": "a"}]}),
    ("service name too long", {"services": {"a": {"name": "a" * 50}}}),
    ("bad ingress", {"services": {"a": {"ingress": "PUBLIC"}}}),
    ("job-only key on a service container", {"services": {"a": {"template": {"containers": [{"image": "x", "unknown": 1}]}}}}),
    ("liveness probe on a job container", {"jobs": {"a": {"template": {"containers": [{"image": "x", "liveness_probe": {}}]}}}}),
    ("timeout without unit", {"services": {"a": {"template": {"timeout": "30"}}}}),
    ("concurrency too high", {"services": {"a": {"template": {"max_instance_request_concurrency": 1001}}}}),
    ("empty containers", {"services": {"a": {"template": {"containers": []}}}}),
    ("bad port protocol", {"services": {"a": {"template": {"containers": [{"image": "x", "ports": {"name": "http2"}}]}}}}),
    ("octal mode out of range", {"services": {"a": {"template": {"volumes": [{"name": "v", "secret": {"secret": "s", "default_mode": "0999"}}]}}}}),
    ("volume without name", {"jobs": {"a": {"template": {"volumes": [{"empty_dir": {}}]}}}}),
    ("bad member", {"services": {"a": {"invokers": ["someone@example.com"]}}}),
    ("schedule without cron", {"jobs": {"a": {"schedules": {"s": {"service_account_email": "x@y"}}}}}),
    ("schedule path without slash", {"services": {"a": {"schedules": {"s": {"schedule": "* * * * *", "path": "x"}}}}}),
    ("bad traffic type", {"services": {"a": {"traffic": [{"type": "NEWEST"}]}}}),
    ("name as a default", {"defaults": {"jobs": {"name": "x"}}}),
    ("boolean that is not a placeholder", {"services": {"a": {"deletion_protection": "yes please"}}}),
]


@pytest.mark.parametrize("name,config", INVALID, ids=[n for n, _ in INVALID])
def test_invalid_configuration_is_rejected(schema, name, config):
    assert list(Draft7Validator(schema).iter_errors(config)), f"schema accepted: {name}"


def test_modes_accept_numbers_and_octal_strings(schema):
    config = {"services": {"a": {"template": {"volumes": [
        {"name": "n", "secret": {"secret": "s", "default_mode": 292, "items": [{"path": "p", "mode": "0400"}]}},
    ]}}}}
    assert not list(Draft7Validator(schema).iter_errors(config))


def test_placeholders_are_accepted_in_typed_fields(schema):
    config = {
        "services": {
            "a": {
                "enabled": "${env == \"dev\"}",
                "name": "api-${env}",
                "deletion_protection": "${protect}",
                "ingress": "${ingress}",
                "template": {
                    "timeout": "${timeout}",
                    "scaling": {"max_instance_count": "${max}"},
                    "containers": [{"image": "x", "ports": {"container_port": "${port}"}}],
                },
                "invokers": ["${member}"],
            }
        },
        "jobs": {"b": {"template": {"task_count": "${tasks}"}}},
    }
    errors = list(Draft7Validator(schema).iter_errors(config))
    assert not errors, [e.message for e in errors]
