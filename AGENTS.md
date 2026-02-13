# Repository Guidelines

## Project Structure & Module Organization
- Root contains the runtime stack and local overrides: `Dockerfile`, `docker-compose.yml`, `n8n-task-runners.json`, `.env`, and `requirements.txt`.
- `sources/n8n/` is a vendored upstream n8n source tree used as Docker build context. Prefer minimal, intentional edits there to reduce merge pain when updating upstream.
- `.idea/` is local IDE metadata and should not contain project logic.

## Build, Test, and Development Commands
- `docker compose build task-runners` builds the custom Selenium-enabled runner image from `Dockerfile`.
- `docker compose up -d` starts `traefik`, `n8n`, and `task-runners` in background.
- `docker compose logs -f task-runners` tails runner logs to debug Python/Selenium execution.
- `docker compose down` stops the stack.
- `docker compose config` validates merged Compose + env configuration before deploy.

## Coding Style & Naming Conventions
- Use 2-space indentation in YAML/JSON and 4 spaces in Python.
- Keep Dockerfile layers grouped by purpose (builder/runtime) and prefer explicit ARG/ENV names (for example `PYTHON_VERSION`, `LAUNCHER_VERSION`).
- Follow existing key style in JSON (`kebab-case` for runner config keys) and uppercase snake case for environment variables.
- Keep `requirements.txt` additions minimal and pinned when possible for reproducible builds.

## Testing Guidelines
- There is no dedicated unit test suite in this wrapper repo; rely on integration checks.
- Before opening a PR, run: `docker compose config`, `docker compose build task-runners`, and a smoke start with `docker compose up -d`.
- Verify runner health by checking logs for startup/registration errors and executing at least one Python code-node workflow using Selenium.

## Commit & Pull Request Guidelines
- Current history is minimal (`Initial commit`), so use concise imperative commit messages (for example `Add Selenium dependency pin for runner`).
- Keep commits focused to one concern (build config, dependency update, or runtime config).
- PRs should include: summary, why the change is needed, validation steps run, and any `.env`/infra impact.

## Security & Configuration Tips
- Never commit secrets from `.env`; use local values or secret management in deployment.
- Review `N8N_RUNNERS_STDLIB_ALLOW` and `N8N_RUNNERS_EXTERNAL_ALLOW` changes carefully, as they expand executable surface area.