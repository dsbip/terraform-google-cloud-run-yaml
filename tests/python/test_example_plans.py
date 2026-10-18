"""Plans every example with the real Google provider, without Google Cloud
access: a dummy OAuth token satisfies provider configuration and
-refresh=false avoids API reads. This exercises the provider's own validation
and plan logic, which the mocked unit tests (terraform test) do not.

Requires network access for `terraform init` (provider download).

Set GOOGLE_PROVIDER_VERSION (e.g. 7.42.0) to pin the provider version, which
is how CI checks the module's minimum supported versions.
"""
import json
import os
import shutil
import subprocess

import pytest

from conftest import EXAMPLES

# Variables each example needs, and the resources its plan must create.
# None: the example has no project_id variable.
EXAMPLE_CASES = {
    "basic": ({"project_id": "example-project"}, 3),
    "services": ({"project_id": "example-project"}, 11),
    "sidecars-and-volumes": ({"project_id": "example-project"}, 5),
    "jobs": ({"project_id": "example-project"}, 10),
    "traffic-management": ({"project_id": "example-project"}, 7),
    "scheduled-workloads": ({"project_id": "example-project"}, 11),
    "gpu-inference": ({"project_id": "example-project"}, 4),
    "multi-environment": ({}, 18),
    "complete": ({"project_id": "example-project"}, 22),
    "standalone-modules": ({"project_id": "example-project"}, 6),
}


def run(cmd, cwd, env):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True, encoding="utf-8", timeout=900)


@pytest.fixture(scope="module")
def plan_env(tmp_path_factory):
    env = dict(os.environ)
    env.update(
        GOOGLE_OAUTH_ACCESS_TOKEN="offline-plan-dummy-token",
        CHECKPOINT_DISABLE="1",
        TF_IN_AUTOMATION="1",
    )
    cache = None
    if not env.get("TF_PLUGIN_CACHE_DIR"):
        cache = tmp_path_factory.mktemp("plugin-cache")
        env["TF_PLUGIN_CACHE_DIR"] = str(cache)
    yield env
    if cache:
        shutil.rmtree(cache, ignore_errors=True)


@pytest.fixture
def repo_copy(tmp_path):
    """make(root_module) copies the repository, so .terraform/, archives and
    plan files never land in it, and returns root_module's directory in the
    copy. The provider is pinned there if GOOGLE_PROVIDER_VERSION is set."""
    work = tmp_path / "repo"

    def make(root_module):
        shutil.copytree(
            EXAMPLES.parent,
            work,
            ignore=shutil.ignore_patterns(".git", ".terraform*", "*.tfstate*", "__pycache__", ".pytest_cache"),
        )
        cwd = work / root_module
        version = os.environ.get("GOOGLE_PROVIDER_VERSION")
        if version:
            (cwd / "versions_override.tf").write_text(
                'terraform {\n  required_providers {\n    google = {\n'
                f'      source  = "hashicorp/google"\n      version = "{version}"\n'
                "    }\n  }\n}\n",
                encoding="utf-8",
            )
        return cwd

    yield make
    shutil.rmtree(work, ignore_errors=True)


def plan(terraform_bin, cwd, env, variables):
    init = run([terraform_bin, "init", "-input=false", "-no-color", "-backend=false"], cwd, env)
    assert init.returncode == 0, init.stdout + init.stderr

    args = [terraform_bin, "plan", "-refresh=false", "-input=false", "-no-color", "-lock=false", "-out=plan.bin"]
    args += [x for k, v in variables.items() for x in ("-var", f"{k}={v}")]
    result = run(args, cwd, env)
    assert result.returncode == 0, result.stdout + result.stderr

    show = run([terraform_bin, "show", "-json", "plan.bin"], cwd, env)
    assert show.returncode == 0, show.stderr
    return json.loads(show.stdout)


def test_every_example_has_a_case():
    examples = sorted(p.name for p in EXAMPLES.iterdir() if p.is_dir())
    assert examples == sorted(EXAMPLE_CASES), "add new examples to EXAMPLE_CASES"


@pytest.mark.parametrize("example", sorted(EXAMPLE_CASES))
def test_example_plans_with_real_provider(terraform_bin, plan_env, repo_copy, example):
    variables, expected = EXAMPLE_CASES[example]
    changes = plan(terraform_bin, repo_copy(f"examples/{example}"), plan_env, variables)["resource_changes"]
    creates = [c["address"] for c in changes if c["change"]["actions"] == ["create"]]
    assert len(creates) == expected, f"{len(creates)} resources planned:\n" + "\n".join(creates)
    assert len(creates) == len(changes), "only creations are expected in a fresh plan"


def test_live_fixture_plans_with_all_options(terraform_bin, plan_env, repo_copy):
    """The live-test fixture (tests/integration) must stay deployable even when
    nobody has credentials to run the live test."""
    changes = plan(
        terraform_bin,
        repo_copy("tests/integration"),
        plan_env,
        {
            "project_id": "example-project",
            "suffix": "ci",
            "test_member": "user:ci@example.com",
            "scheduler_service_account": "ci@example-project.iam.gserviceaccount.com",
        },
    )["resource_changes"]
    types = sorted(c["type"] for c in changes)
    assert types == sorted([
        "terraform_data",
        "google_cloud_run_v2_service", "google_cloud_run_v2_service_iam_member",
        "google_cloud_run_v2_job", "google_cloud_run_v2_job_iam_member",
        "google_cloud_scheduler_job",
    ]), types
