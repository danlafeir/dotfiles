# Project AI Preferences — Data / ML

## Data pipelines
- Validate schema at ingestion boundaries — fail loudly on unexpected shape rather than propagating bad data silently
- Transformations should be pure and testable in isolation
- Pause before changing the output schema of a pipeline — downstream consumers break silently

## Reproducibility
- Seeds, versions, and environment specs are not optional — include them
- Pause before changing a training config or hyperparameter that affects a reproducible result

## Notebooks
- Notebooks are for exploration and presentation, not production logic — extract reusable code into modules
- Keep cells idempotent where possible; flag cells with side effects
- Pause before running cells that write to external storage or kick off long jobs

## Models
- Pause before changes to model architecture, loss function, or evaluation metric
- Versioning of models and datasets must follow the existing convention in the repo

## Testing
- Unit test data transformations with known inputs and outputs
- Flag when a test requires a full dataset — suggest a fixture or sample instead

## Documentation
- Data dictionaries and schema docs must be updated when pipeline inputs or outputs change
- Experiments should be logged with their config, results, and conclusion — not just the winning run

## Pause triggers (in addition to global)
- Output schema changes
- Model architecture or training config changes
- Any write to a shared data store or model registry
