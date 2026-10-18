# Basic example

One public Cloud Run service running Google's sample image.

- `invokers: [allUsers]` grants `roles/run.invoker` to everyone, which makes the URL public.
- `deletion_protection: false` lets `terraform destroy` remove the service (the provider protects services by default).

```bash
terraform init
terraform apply -var project_id=my-project
curl "$(terraform output -json uris | jq -r .hello)"
```
