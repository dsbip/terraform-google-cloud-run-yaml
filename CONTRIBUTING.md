# Contributing

Issues and pull requests are welcome.

## Before you start

- Read [docs/design.md](docs/design.md): it explains how configuration flows through the module and why it is built the way it is.
- For a larger change, open an issue first to agree on the YAML shape; the configuration format is the module's public interface.

## Making a change

1. Add or change the key in `schemas/cloud-run-config.schema.json`, with a description. Types, enumerations, ranges and patterns declared there are enforced by `validation.tf` automatically. Nested objects must be named definitions with `additionalProperties: false`.
2. Add it to the typed variables of `modules/service` or `modules/job` and pass it to the resource.
3. Add a rule to part 2 of `validation.tf` for invalid combinations, with a message that starts with the YAML path. Keep the patterns of the surrounding code:
   - wrap lookups in `try()` so bad input reaches validation instead of failing the plan;
   - treat `null` as "not set" (`try(x, null) != null`, not `can(x)`);
   - don't mix object types in conditionals; never pass a possibly-null value to `contains()`.
4. Add tests in `tests/`: a unit test that asserts the planned attribute, and a validation test that compares the full set of messages if you added a rule.
5. Use the key in `examples/complete` and document it in `docs/services.md` or `docs/jobs.md`; tests fail otherwise.
6. Add an entry under "Unreleased" in [CHANGELOG.md](CHANGELOG.md).

## Checks

```bash
scripts/test.sh
```

This runs `terraform fmt -check`, `terraform validate` for the root module and the three submodules, `terraform test` and the Python tests (schema and documentation checks, and real-provider plans of every example). CI runs the same checks across the supported Terraform and provider versions. See [docs/testing.md](docs/testing.md).

## Compatibility

- Keep Terraform 1.5 working in the module code: logical operators do not short-circuit before Terraform 1.12, and functions newer than 1.5 are unavailable. CI plans every example with Terraform 1.5.7.
- Keep google provider 7.42 working, or raise the minimum in every `versions.tf` and the CI matrix together, and note it in the changelog.
- Changing a `for_each` key or a resource address is a breaking change: users' services and jobs would be destroyed and recreated. Avoid it, or ship `moved` blocks.

## Releases

Versions follow semantic versioning. A release is a `vX.Y.Z` tag on `main` with the changelog section as release notes.
