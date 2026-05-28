# Project AI Preferences — Backend / API

## Architecture
- Validate only at system boundaries (HTTP handlers, queue consumers, CLI entrypoints); trust internal code
- Keep business logic out of HTTP handlers — handlers parse/respond, services decide
- Prefer explicit error returns over exceptions for expected failure cases

## Database
- Never write a migration without considering the rollback path
- Pause before any migration that locks tables or drops columns — confirm it's intentional
- Additive migrations (new columns, new tables) can proceed; destructive ones require review

## API contracts
- Pause before changing a response shape or removing a field — downstream callers break silently
- New endpoints can proceed; changes to existing ones require review

## Testing
- Integration tests should hit real infrastructure (DB, queue) — not mocks
- Unit test pure logic; integration test boundaries

## Pause triggers (in addition to global)
- Any change to auth, session, or token handling
- Schema changes to existing tables
- Changes to retry/timeout/backoff behavior
