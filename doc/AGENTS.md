# Development conventions

The supplied GUIDELINES.md specifies layout and review workflow. These additional
conventions describe the initial backend implementation and may be refined by
the team through review.

- Python 3.10+, project-local `.venv`; never install dependencies globally.
- Use snake_case for Python functions/modules and PascalCase for classes.
- Keep HTTP handling in routes, typed contracts in models, business logic in
  services, and AWS calls in database. Do not import legacy interactive modules.
- Configure AWS through the environment and credential provider chain; no secrets
  or account-specific credentials in source, tests, or the mobile app.
- Preserve existing DynamoDB records and API contracts. Future timestamp writes
  must be timezone-aware. Do not silently reinterpret legacy local times.
- Keep changes focused. Read relevant docs/tests first; do not weaken tests to
  make failures pass. Run `python -m pytest -q` and `npm test` and report results.
- Swift types use PascalCase; properties/functions use camelCase. Keep views,
  models, view models, and API services in their named ios folders.
- Preserve both sync prototypes until the team chooses an implementation.
- Use `feature/`, `integration/`, `docs/`, or `bugfixes/` branches as described in
  GUIDELINES.md. Update docs for every PR and get one teammate approval; review
  requests within 48 hours. Never commit or push without user authorization.
