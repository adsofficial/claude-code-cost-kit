# Python

## Conventions
- Python version and tooling as defined in `pyproject.toml` (uv, poetry or pip-tools); never install globally.
- Type hints on public functions; `ruff` for lint + format; `mypy`/`pyright` where configured.
- FastAPI/Flask/Django: follow the existing app structure. Pydantic models for request/response validation.
- Config via environment variables / settings classes; secrets from Key Vault or env, never in code or notebooks.
- `logging` module with structured fields, not `print`.

## Testing
- `pytest` with fixtures; `pytest-mock`/`unittest.mock` for external calls; `respx`/`responses` for HTTP.
- No real cloud, database or paid API calls in unit tests.
- Commands: `pytest -q`, `ruff check .`, `mypy .` (if configured).

## Security
- Parameterized DB queries (SQLAlchemy bound params, never f-strings in SQL).
- No `eval`/`exec`/`pickle.loads` on untrusted data; `yaml.safe_load` only.
- `subprocess` with argument lists, never `shell=True` with user input.
- Validate file paths (no path traversal) and upload sizes/types.
- `pip-audit` before release.

## Cost & performance
- Vectorize with pandas/numpy instead of Python loops on large data; stream large files.
- Async I/O for many concurrent network calls; connection pooling for DBs.
