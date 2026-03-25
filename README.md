# SDD Navigator Infrastructure

This repository implements the DevOps test task for the SDD Navigator stack.

## What It Deploys

- `charts/sdd-navigator/`: umbrella Helm chart for the full stack.
- `charts/sdd-navigator/charts/api/`: Rust API Deployment, Service, ConfigMap, and optional Secret template.
- `charts/sdd-navigator/charts/frontend/`: nginx-based frontend Deployment and Service.
- `charts/sdd-navigator/charts/postgresql/`: PostgreSQL StatefulSet with persistent storage and restrictive volume permissions.
- `charts/sdd-navigator/templates/ingress.yaml`: `/api` to the API service and `/` to the frontend service.
- `ansible/`: local-cluster deployment and post-deploy validation.
- `scripts/check-traceability.sh`: scans Helm, Ansible, and workflow files for `@req` coverage and orphan references.
- `scripts/check-infra-policy.py`: deterministic policy checks used by CI to catch non-template violations such as missing probes or plaintext passwords.

## Architecture Decision

This submission uses a custom local PostgreSQL subchart instead of the Bitnami dependency approach. The choice keeps the repo self-contained, avoids external chart fetches during validation, and makes the `demo/violation` branch easier to control deterministically.

## Local Helm Commands

Render the default manifests:

```bash
helm template sdd-navigator charts/sdd-navigator --namespace sdd-navigator
```

Lint the chart:

```bash
helm lint charts/sdd-navigator --with-subcharts --strict
```

Render with the Ansible-generated override file after a deployment run:

```bash
helm template sdd-navigator charts/sdd-navigator \
  --namespace sdd-navigator \
  -f ansible/.generated/values.override.yaml
```

## Local Ansible Commands

Set the database password in the environment and run the playbook against the local kubeconfig:

```bash
export SDD_DB_PASSWORD='replace-me'
ansible-playbook -i ansible/inventory/local.yml ansible/playbook.yml
```

The playbook:

- creates the namespace when missing;
- applies the database Secret;
- renders the chart and diffs it against the cluster before deciding whether a Helm upgrade is needed;
- waits for PostgreSQL, API, frontend, and ingress in order;
- validates `/healthcheck`, `/stats`, pod status, and `pg_isready`.

## CI

`.github/workflows/infra-ci.yml` runs:

- `helm lint`
- `helm template` + `kubeconform --strict --summary`
- `python3 scripts/check-infra-policy.py`
- `ansible-lint`
- `yamllint -d relaxed .`
- `bash scripts/check-traceability.sh`

The `summary` job consolidates the required results into the GitHub Actions step summary.

## Required Submission Links

- Main branch passing CI run: replace with the GitHub Actions URL after pushing this repo.
- `demo/violation` failing CI run: replace with the GitHub Actions URL after pushing the intentionally broken branch.

## Branches

- `main`: intended passing implementation.
- `demo/violation`: intended failing implementation with deliberate SDD violations called out by CI.
