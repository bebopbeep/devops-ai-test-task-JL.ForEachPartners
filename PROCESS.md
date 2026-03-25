# PROCESS

## Tools Used

- Codex desktop agent in this workspace for repository scaffolding, Helm authoring, Ansible authoring, CI design, and static verification.
- Local Python 3.13 for YAML parsing and ad hoc repository checks during development.
- No external IDE plugins or secondary AI tools were used inside this workspace snapshot.

## Conversation Log

### Session 1

- Date: March 25, 2026.
- Start timestamp: exact chat metadata timestamp was not exposed in the local workspace context.
- End timestamp: exact chat metadata timestamp was not exposed in the local workspace context.
- Topic: build the full DevOps test-task repository for the SDD Navigator stack.
- Developer request: inspect the provided task files, extract the requirements, and implement the submission end to end.
- Accepted output: a self-contained Helm/Ansible/CI repository with traceability and policy enforcement.
- Rejected or corrected output:
  - Bitnami-as-remote-dependency was not used because it would make the repo less self-contained for offline review.
  - Plain lint-only CI was rejected because it would not catch the required `demo/violation` cases.
  - Validation logic was tightened so failed HTTP checks report `FAIL` cleanly instead of crashing on missing fields.

## Timeline

1. March 25, 2026: extracted the test-task structure from the supplied HTML and YAML files.
2. March 25, 2026: created the Helm umbrella chart and local API, frontend, and PostgreSQL subcharts.
3. March 25, 2026: added the Ansible playbook, deploy role, and validate role.
4. March 25, 2026: added the workflow, traceability script, and policy-enforcement script.
5. March 25, 2026: ran local static checks available in the workspace, then wrote `README.md` and `PROCESS.md`.

## Key Decisions

- Chose a local PostgreSQL subchart over a remote Bitnami dependency to keep the repository self-contained and easier to verify without network assumptions.
- Added `scripts/check-infra-policy.py` because `helm lint`, `kubeconform`, `ansible-lint`, and `yamllint` alone would not catch the intentional missing-probe, hardcoded-port, or plaintext-password violations required by the task.
- Used a diff-before-upgrade flow in the deploy role so the second Ansible run can legitimately skip the Helm upgrade when nothing changed.
- Kept shared Helm labels and naming logic in the umbrella `_helpers.tpl` to satisfy the DRY requirement.

## What the Developer Controlled

- Reviewed the extracted task text against `requirements.yaml` before creating files.
- Controlled the chart structure and helper layout in:
  - `charts/sdd-navigator/`
  - `charts/sdd-navigator/charts/api/`
  - `charts/sdd-navigator/charts/frontend/`
  - `charts/sdd-navigator/charts/postgresql/`
- Controlled deployment orchestration and validation logic in:
  - `ansible/playbook.yml`
  - `ansible/group_vars/all.yml`
  - `ansible/roles/deploy/tasks/main.yml`
  - `ansible/roles/validate/tasks/main.yml`
- Controlled deterministic enforcement in:
  - `.github/workflows/infra-ci.yml`
  - `scripts/check-traceability.sh`
  - `scripts/check-infra-policy.py`
- Verification steps performed before accepting the output:
  - parsed non-template YAML files with Python and PyYAML;
  - ran a Python equivalent of the traceability scan to confirm no missing or orphan `@req` references;
  - ran source-only policy checks for hardcoded ports, plaintext password defaults, and `latest` tags;
  - manually inspected the most risk-prone files after each major patch.

## Course Corrections

- The first CI design was not sufficient for the required failing branch because standard lint jobs would not detect all requested violations. A dedicated policy script was added.
- The initial validation fact expressions assumed `uri` responses always had `status` and `json`. Those checks were revised to use safe defaults so failures are reported deterministically.
- The deployment approach was adjusted from unconditional `helm upgrade --install` to render-plus-diff first, because unconditional upgrade would undermine the idempotency requirement.

## Self-Assessment

- Traceability: strong. All Helm, Ansible, and workflow YAML/TPL files were annotated and a dedicated traceability script checks for missing and orphan references.
- DRY: good. Shared Helm labels and names live in one helper file, and Ansible variables are centralized in `group_vars`.
- Deterministic Enforcement: good but not fully proven locally. The repository contains the required workflow and deterministic checks, but Helm/Ansible/GitHub Actions were not executable in this Windows workspace.
- Parsimony: good. The repo stays close to the requested skeleton, but the extra policy script is intentional overhead needed to enforce the explicit failing-branch requirements.
