# Project AI Preferences — Infrastructure / DevOps

## General
- Read before write: always check current state before proposing a change
- Prefer additive changes; flag anything that removes or replaces a running resource
- Name resources consistently with what already exists in the repo

## Terraform
- Always run plan before apply — never apply without reviewing the diff
- Pause before any change that will cause resource replacement (forces new)
- State file is sacred — never edit it directly; flag if a workaround requires it

## Kubernetes
- Pause before changes to resource limits, autoscaling config, or network policies
- Namespace and label conventions must match existing resources
- Never patch a running workload directly — change the manifest, let the controller reconcile

## CI/CD
- Pause before modifying pipeline steps that gate deployments
- Secret references must use the existing secret management pattern — never hardcode

## Documentation
- Runbooks and architecture diagrams must be updated when topology or operational procedures change
- New resources should be documented with their purpose and any non-obvious configuration

## Pause triggers (in addition to global)
- Any change touching prod namespaces / workspaces
- IAM / RBAC / security group modifications
- Anything that destroys and recreates a stateful resource (database, volume, secret)
- Pipeline changes that affect the deploy gate
