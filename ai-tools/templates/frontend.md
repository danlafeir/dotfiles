# Project AI Preferences — Frontend

## Components
- Keep components small and single-purpose; if a component needs a comment to explain what it renders, split it
- Co-locate styles, tests, and types with the component file
- Avoid prop drilling past two levels — reach for context or state management instead

## State
- Local state for UI-only concerns; shared state for anything two+ components need
- Pause before introducing a new state management pattern — prefer extending what's already in use

## Data fetching
- Pause before adding a new fetch pattern or cache strategy — consistency matters more than local optimality

## UX
- Pause before changing a user-visible flow, navigation structure, or form behavior
- Loading and error states are not optional — implement them alongside the happy path

## Testing
- Test behavior from the user's perspective, not implementation details
- Avoid testing internal component state directly

## Pause triggers (in addition to global)
- New user-facing flows or pages
- Changes to routing structure
- Modifications to shared design system components
