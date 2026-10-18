# Design

## Flow of a configuration

```text
config_file ──templatefile()──┐
config_yaml ──────────────────┴─▶ yamldecode ─▶ local.config_decoded
                                                   │
                     ┌─────────────────────────────┤
                     ▼                             ▼
            validation.tf part 1          main.tf: drop nulls, merge
            walk YAML + JSON Schema       defaults.services / defaults.jobs (3 levels),
            (raw values, exact paths)     then defaults.*_container into every
                     │                    container (3 levels); octal modes;
                     │                    project, region, labels
                     │                             │
                     │                    validation.tf part 2: rules on the
                     │                    merged entries and containers
                     ▼                             │
            local.validation_errors ◀──────────────┘
                     │
        config_valid ├──▶ terraform_data.validation (precondition lists all errors)
                     ▼
            services.tf / jobs.tf: module "service" / "job" { for_each = valid ? entries : {} }
                     ▼
            modules/service, modules/job ──▶ modules/schedule (one per schedule)
```

## Decisions

**YAML keys follow the provider.** Names match `google_cloud_run_v2_service` and `google_cloud_run_v2_job`, so the provider documentation applies. The module changes the shape only where the provider is awkward in YAML: single-element blocks are mappings; environment variables are `env` and `secret_env` mappings instead of a list of blocks with nested `value_source.secret_key_ref`; a job's execution and task templates are one `template`; traffic types have short forms; file modes accept quoted octal strings; and `region` replaces `location`, as in the other modules of this family.

**Container defaults.** Containers are a list, and lists replace rather than merge, so entry defaults can never set container settings. `defaults.service_container` and `defaults.job_container` are merged into every container instead, which covers the common cases: shared resources, environment variables, secrets, and for jobs a shared image.

**Schedules belong to their target.** A Cloud Scheduler job that calls a service or executes a job is declared on that service or job, so it is created, renamed and deleted with it, and its URI and authentication (OIDC for services, OAuth for the Admin API) follow from the target. `modules/schedule` is separate and works for any HTTP target.

**The schema is the single source of truth.** `validation.tf` reads allowed keys, types, enumerations, ranges and patterns from `schemas/cloud-run-config.schema.json` at plan time, and editors use the same file. Tests keep the schema in a shape the Terraform walker understands (closed object definitions, no inline objects, bounded depth).

**Report everything, plan nothing.** Every lookup in the loading code is wrapped in `try()`, all problems are collected with their YAML paths, and every module's `for_each` is empty until the list is empty. The precondition on `terraform_data.validation` then fails the plan with the complete list, instead of a Terraform type error that stops at the first problem.

**Typed submodules.** `modules/service`, `modules/job` and `modules/schedule` have strict, typed variables and their own validation, so they are useful on their own. The root module only loads, merges, validates and calls them.

**Provider defaults stay.** Unset keys are passed as `null`, so the provider and the API decide. In particular `deletion_protection` keeps the provider default (`true`): deleting a production service should be a decision.

**Stable addresses.** Entries are keyed by their YAML key (`module.service["api"]`), IAM grants by role and member, schedules by their key. Adding or removing entries never touches the others.

## Compatibility rules for the code

- Terraform 1.5: no functions newer than 1.5; `&&` and `||` do not short-circuit before 1.12, so every operand must be safe on its own.
- Conditionals must not mix object types that hold YAML values; the validation walker and the job run-request body use `for ... if` filters instead.
- Never pass a possibly-null value to `contains()`; never let a null reach `${...}` interpolation.
