# Sidecars and volumes example

| Service | Shows |
|---|---|
| `web` | three containers: nginx (ingress, the only one with `ports`), the app and an OpenTelemetry collector; `depends_on` start ordering; a TCP startup probe; an in-memory `empty_dir` shared by nginx and the app; secret files with `items` and `default_mode` |
| `reports` | Cloud SQL Auth Proxy sockets for two instances, a Cloud Storage FUSE mount with mount options, an NFS (Filestore) share with `sub_path`, a secret file with version and mode, Direct VPC egress to reach the share |

File modes are quoted octal strings (`"0444"`): YAML reads an unquoted `0444` as the decimal number 444, which the module reports as a likely mistake.

Cloud Storage and NFS volumes need the second generation execution environment, set in `defaults.services`. The runtime service account needs `roles/cloudsql.client`, access to the bucket and `roles/secretmanager.secretAccessor` on the secrets.
