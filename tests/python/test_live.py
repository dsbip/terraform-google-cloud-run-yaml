"""Live test against a real Google Cloud project (tests/integration).

Skipped unless CR_YAML_TEST_PROJECT is set. Uses Application Default
Credentials. Everything is created under crun-<random suffix> and destroyed
at the end, also when a step fails.

  apply  ->  plan shows no changes  ->  apply revision 2 (in-place updates)
         ->  plan shows no changes  ->  destroy

Optional environment variables:
  CR_YAML_TEST_REGION     region (default europe-west1)
  CR_YAML_TEST_MEMBER     IAM member granted roles/run.invoker on the service,
                          e.g. serviceAccount:ci@p.iam.gserviceaccount.com
  CR_YAML_TEST_SCHEDULER  service account email for a paused job schedule
"""
import json
import os
import secrets
import shutil
import subprocess

import pytest

from conftest import REPO

PROJECT = os.environ.get("CR_YAML_TEST_PROJECT")

pytestmark = pytest.mark.skipif(not PROJECT, reason="set CR_YAML_TEST_PROJECT to run the live test")


def terraform(binary, args, cwd, env):
    return subprocess.run(
        [binary, *args], cwd=cwd, env=env, capture_output=True, text=True, encoding="utf-8", timeout=3600
    )


def check(result, what):
    assert result.returncode == 0, f"{what} failed:\n{result.stdout}\n{result.stderr}"


def test_live_lifecycle(terraform_bin, tmp_path):
    suffix = "t" + secrets.token_hex(3)
    work = tmp_path / "repo"
    shutil.copytree(REPO, work, ignore=shutil.ignore_patterns(".git", ".terraform*", "*.tfstate*", "__pycache__", ".pytest_cache"))
    cwd = work / "tests" / "integration"
    env = dict(os.environ, TF_IN_AUTOMATION="1", CHECKPOINT_DISABLE="1")

    def variables(revision):
        return [
            "-var", f"project_id={PROJECT}",
            "-var", f"suffix={suffix}",
            "-var", f"region={os.environ.get('CR_YAML_TEST_REGION', 'europe-west1')}",
            "-var", f"revision={revision}",
            "-var", f"test_member={os.environ.get('CR_YAML_TEST_MEMBER', '')}",
            "-var", f"scheduler_service_account={os.environ.get('CR_YAML_TEST_SCHEDULER', '')}",
        ]

    def assert_no_changes(revision):
        result = terraform(terraform_bin, ["plan", "-input=false", "-no-color", "-detailed-exitcode", *variables(revision)], cwd, env)
        assert result.returncode == 0, f"expected an empty plan after apply (exit code {result.returncode}):\n{result.stdout}\n{result.stderr}"

    check(terraform(terraform_bin, ["init", "-input=false", "-no-color"], cwd, env), "init")
    try:
        check(terraform(terraform_bin, ["apply", "-input=false", "-no-color", "-auto-approve", *variables(1)], cwd, env), "apply")
        assert_no_changes(1)

        outputs = json.loads(terraform(terraform_bin, ["output", "-json"], cwd, env).stdout)
        services, jobs = outputs["services"]["value"], outputs["jobs"]["value"]
        assert sorted(services) == ["hello"] and sorted(jobs) == ["task"]
        assert services["hello"]["uri"].startswith("https://")
        assert services["hello"]["latest_ready_revision"]
        assert jobs["task"]["run_uri"].endswith(f"/jobs/crun-{suffix}-task:run")

        check(terraform(terraform_bin, ["apply", "-input=false", "-no-color", "-auto-approve", *variables(2)], cwd, env), "apply revision 2")
        assert_no_changes(2)
    finally:
        check(terraform(terraform_bin, ["destroy", "-input=false", "-no-color", "-auto-approve", *variables(2)], cwd, env), "destroy")
