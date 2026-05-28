# Project AI Preferences — CLI / Library

## Public interface
- Pause before any change to exported function signatures, CLI flag names, or command structure — callers break silently
- Additive changes (new flags, new optional args) can proceed; breaking changes require review
- Deprecation before removal — flag if a removal skips this

## CLI behavior
- Flags should have sensible defaults; never require input that can be inferred
- stdout is for output; stderr is for errors and progress — keep them separate
- Exit codes must be meaningful: 0 = success, non-zero = failure; never swallow errors silently

## Library design
- Keep the public surface small — if it's not needed by callers, don't export it
- Avoid global state; make dependencies injectable
- Pause before adding a new required dependency — consider the impact on consumers

## Versioning
- Follow semver: breaking changes = major, new features = minor, fixes = patch
- Pause before any change that would bump the major version

## Testing
- Test the public interface, not internals
- CLI tests should invoke the binary/entry point, not internal functions

## Pause triggers (in addition to global)
- Any breaking change to the public API or CLI interface
- New required dependencies
- Changes to output format that consumers may be parsing
