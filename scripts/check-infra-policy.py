#!/usr/bin/env python3
# @req SCI-HELM-001
# @req SCI-HELM-005
# @req SCI-HELM-006
# @req SCI-SEC-001
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RENDERED_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "ansible" / ".generated" / "rendered-manifests.yaml"

violations: list[str] = []


def add_violation(message: str) -> None:
    violations.append(message)


template_files = sorted((ROOT / "charts" / "sdd-navigator").glob("**/templates/*.yaml"))
hardcoded_port_pattern = re.compile(r"^\s*(containerPort|port|targetPort):\s*\d+\s*(?:#.*)?$")

for file_path in template_files:
    for index, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), start=1):
        if hardcoded_port_pattern.match(line):
            add_violation(
                f"{file_path.relative_to(ROOT)}:{index} uses a hardcoded port instead of a values reference."
            )


values_files = sorted((ROOT / "charts" / "sdd-navigator").glob("**/values.yaml"))
password_pattern = re.compile(r"^\s*password:\s*(?P<value>.+?)\s*(?:#.*)?$")
latest_tag_pattern = re.compile(r'^\s*tag:\s*["\']?latest["\']?\s*$')

for file_path in values_files:
    for index, line in enumerate(file_path.read_text(encoding="utf-8").splitlines(), start=1):
        password_match = password_pattern.match(line)
        if password_match:
            raw_value = password_match.group("value").strip().strip('"').strip("'")
            if raw_value and not raw_value.startswith("__") and "REPLACE" not in raw_value and "CHANGE" not in raw_value:
                add_violation(
                    f"{file_path.relative_to(ROOT)}:{index} defines a plaintext password default."
                )

        if latest_tag_pattern.match(line):
            add_violation(f"{file_path.relative_to(ROOT)}:{index} uses the forbidden latest image tag.")


if not RENDERED_PATH.exists():
    add_violation(f"{RENDERED_PATH} does not exist. Render the chart before running this policy check.")
else:
    rendered_text = RENDERED_PATH.read_text(encoding="utf-8")
    docs = [doc for doc in re.split(r"\n---\s*\n", rendered_text) if doc.strip()]

    def find_deployment(component: str) -> str | None:
        component_pattern = re.compile(rf"app\.kubernetes\.io/component:\s*{re.escape(component)}")
        for doc in docs:
            if re.search(r"^kind:\s*Deployment\s*$", doc, re.MULTILINE) and component_pattern.search(doc):
                return doc
        return None

    api_deployment = find_deployment("api")
    frontend_deployment = find_deployment("frontend")

    if api_deployment is None:
        add_violation("Rendered manifests are missing the API deployment.")
    else:
        if not re.search(
            r"livenessProbe:\s+httpGet:\s+path:\s+/healthcheck\s+port:\s+http\s+initialDelaySeconds:\s+10\s+periodSeconds:\s+15",
            api_deployment,
            re.MULTILINE | re.DOTALL,
        ):
            add_violation("Rendered API deployment is missing the required liveness probe configuration.")

        if not re.search(
            r"readinessProbe:\s+httpGet:\s+path:\s+/healthcheck\s+port:\s+http\s+initialDelaySeconds:\s+5\s+periodSeconds:\s+5",
            api_deployment,
            re.MULTILINE | re.DOTALL,
        ):
            add_violation("Rendered API deployment is missing the required readiness probe configuration.")

        if "runAsNonRoot: true" not in api_deployment:
            add_violation("Rendered API deployment is not configured to run as non-root.")

    if frontend_deployment is None:
        add_violation("Rendered manifests are missing the frontend deployment.")
    elif "runAsNonRoot: true" not in frontend_deployment:
        add_violation("Rendered frontend deployment is not configured to run as non-root.")


if violations:
    print("Infrastructure policy check failed:")
    for violation in violations:
        print(f"  - {violation}")
    sys.exit(1)

print("Infrastructure policy check passed.")
