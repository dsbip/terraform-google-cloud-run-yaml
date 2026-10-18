# Multi-environment example

One [`config.yaml`](config.yaml) deploys dev, staging and prod into separate projects; [`main.tf`](main.tf) calls the module once per environment.

| | dev | staging | prod |
|---|---|---|---|
| `api` | 0–2 instances, 512Mi, developers may call it | 0–5 instances, 512Mi | 2–50 instances, 2Gi, always-on CPU, only the gateway may call it, deletion protection |
| `api-preview` | deployed | validated, not deployed | validated, not deployed |
| `reindex` job | 2 tasks, no schedule | 2 tasks, nightly schedule created paused | 20 tasks, nightly schedule |

Techniques: placeholders in typed fields (`deletion_protection: ${env == "prod"}`, `task_count: ${env == "prod" ? 20 : 2}`), quoted expressions with `: `, `%{ if }` / `%{ else }` blocks inside containers and lists, and `enabled` for environment-specific services.
