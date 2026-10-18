# GPU inference example

- `llm-inference`: a vLLM server on one NVIDIA L4 GPU with 8 CPUs and 32 GiB, always-on CPU, startup CPU boost, a long TCP startup probe for model loading, scale to zero, a Hugging Face token from Secret Manager, and only one service account allowed to call it.
- `fine-tune`: a GPU job with a six hour task timeout.

A GPU needs `template.node_selector.accelerator` and a `nvidia.com/gpu` limit on a container; the module reports a node selector without a GPU limit. `gpu_zonal_redundancy_disabled: true` uses the cheaper GPU capacity without zonal redundancy.

Cloud Run GPUs are available in selected regions and need GPU quota in the project.
