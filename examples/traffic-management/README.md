# Traffic management example

| Service | Pattern |
|---|---|
| `checkout` | canary: 90% on the previous revision, 10% on the new one, both tagged |
| `search` | blue/green: the new revision gets 0% and a `green` tag URL for smoke tests |
| `docs` | latest revision plus a pinned, tagged revision |

`type` accepts `LATEST` and `REVISION` (or the provider's long forms). The module checks that the percentages add up to 100, that `REVISION` targets name a revision and that `LATEST` targets don't.

Revision names must start with the service name and a hyphen. The revisions named in `traffic` must exist: roll out by deploying the new revision with 0% first, then shifting traffic.
