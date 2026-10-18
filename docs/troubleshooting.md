# Troubleshooting

## The plan fails with "The Cloud Run YAML configuration has N problem(s)"

That is the module's validation: each line starts with the YAML path of the problem. Nothing is planned until all of them are fixed. See [configuration.md](configuration.md#validation) for what is checked.

## `terraform destroy` fails because of deletion protection

The provider protects services and jobs by default. Set `deletion_protection: false` on the entry (or in `defaults.services` / `defaults.jobs`), apply, then destroy.

## A key turned into `true` or `false`

Terraform's YAML parser reads unquoted `yes`, `no`, `on`, `off`, `true` and `false` as booleans, also as mapping keys. Quote the key (`"on":`) or pick another name.

## Secret files have the wrong permissions

An unquoted `0444` in YAML is the decimal number 444. Write modes as quoted octal strings (`"0444"`) or decimal numbers (`292`). The module reports the common octal-looking decimals.

## `Invalid template interpolation value` or `vars map does not contain key`

`config_file` is rendered with `templatefile()`. Every `${name}` needs a value in `template_vars` (`project_id` and `region` are always provided, but they are null if the module variables are unset). For a literal `${`, write `$${`.

## `Error 403 ... iam.serviceaccounts.actAs`

The identity running Terraform needs `roles/iam.serviceAccountUser` on the runtime service account (`template.service_account`), and on the scheduler service accounts of `schedules`.

## The revision fails to start

- The container must listen on `$PORT` (default 8080, or `ports.container_port`).
- With sidecars, exactly one container sets `ports`; `depends_on` containers need a startup probe that passes.
- A failing startup probe shows in the revision's logs; increase `failure_threshold` or `period_seconds` for slow starts (e.g. model loading).

## A scheduled call or execution fails with 403

The schedule's `service_account_email` needs `roles/run.invoker` on the target: list it in `invokers`. Job schedules with `overrides` additionally need `roles/run.jobsExecutorWithOverrides`, granted through `iam`.

## A traffic target refers to a revision that doesn't exist

Revisions named in `traffic` must exist. Deploy the new revision first (with `template.revision` and a 0% target or the previous split), then shift traffic in a second apply.

## `allUsers` cannot be granted

The *Domain restricted sharing* organization policy (`iam.allowedPolicyMemberDomains`) blocks public members. Use `invoker_iam_disabled: true` for a public service instead, or put it behind a load balancer.
