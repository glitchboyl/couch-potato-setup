# Tech Stack Detection Heuristics

Reference for the Couch Potato setup init phase. Read this file when scanning a new project to determine its tech stack, package manager, framework, and default commands.

---

## 1. Manifest File Detection (Priority Order)

Scan the project root for these files. First match wins for language identification. If multiple are present, see Section 6 (Ambiguous Cases).

| File | Language / Platform |
|------|---------------------|
| `package.json` | Node.js |
| `pyproject.toml` | Python |
| `setup.py` | Python |
| `requirements.txt` | Python |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `pom.xml` | Java (Maven) |
| `build.gradle` / `build.gradle.kts` | Java or Kotlin (Gradle) |
| `*.csproj` / `*.sln` | .NET (C#/F#/VB) |

---

## 2. Lock File to Package Manager

The lock file is the authoritative source for the active package manager. Never infer the package manager from the manifest alone.

| Lock File | Package Manager |
|-----------|----------------|
| `pnpm-lock.yaml` | pnpm |
| `yarn.lock` | yarn |
| `package-lock.json` | npm |
| `bun.lockb` | bun |
| `poetry.lock` | poetry |
| `Pipfile.lock` | pipenv |
| `uv.lock` | uv |
| `Cargo.lock` | cargo |
| `go.sum` | go modules |

If no lock file is present, fall back to whichever binary is available (`pnpm` > `bun` > `yarn` > `npm` for Node; `uv` > `poetry` > `pip` for Python).

---

## 3. Framework Detection

Determine the framework by reading the `dependencies` and `devDependencies` fields of the manifest file (or equivalent). Match the first entry found.

### Node.js (package.json)

| Dependency key | Framework |
|----------------|-----------|
| `next` | Next.js |
| `nuxt` | Nuxt |
| `@angular/core` | Angular |
| `vue` | Vue |
| `svelte` | Svelte |
| `@remix-run/react` | Remix |
| `astro` | Astro |
| `express` | Express |
| `fastify` | Fastify |
| `hono` | Hono |
| `@nestjs/core` | NestJS |

### Python (pyproject.toml / requirements.txt / setup.py)

| Package | Framework |
|---------|-----------|
| `django` | Django |
| `flask` | Flask |
| `fastapi` | FastAPI |
| `starlette` | Starlette |

### Go (go.mod require block)

| Module path fragment | Framework |
|----------------------|-----------|
| `gin-gonic/gin` | Gin |
| `labstack/echo` | Echo |
| `gofiber/fiber` | Fiber |
| `go-chi/chi` | Chi |

### Rust (Cargo.toml [dependencies])

| Crate | Framework |
|-------|-----------|
| `actix-web` | Actix Web |
| `axum` | Axum |
| `rocket` | Rocket |
| `warp` | Warp |

### Java / Kotlin (pom.xml or build.gradle)

| Artifact / Plugin | Framework |
|-------------------|-----------|
| `spring-boot-starter` | Spring Boot |
| `io.quarkus` | Quarkus |
| `io.micronaut` | Micronaut |

---

## 4. Monorepo Detection

Check for these files/fields. Any match indicates a monorepo. Read the file to determine workspace layout.

| Indicator | Tool |
|-----------|------|
| `turbo.json` | Turborepo |
| `nx.json` | Nx |
| `lerna.json` | Lerna |
| `pnpm-workspace.yaml` | pnpm workspaces |
| `"workspaces"` key in `package.json` | npm/yarn workspaces |

For monorepos: detect each sub-package independently using the same manifest detection rules. Record the paths to frontend and backend sub-packages separately.

---

## 5. Default Command Mappings

Use these defaults only when the actual commands cannot be determined from the project's scripts/config. Always prefer reading the actual scripts first.

**Reading actual commands (Node.js):** Check `package.json` `"scripts"` field. Common patterns:
- Check command: `test`, `test:ci`, `vitest`, `jest`
- Lint command: `lint`, `lint:fix`, `eslint`
- Dev server: `dev`, `start:dev`, `serve`
- Type check: `type-check`, `typecheck`, `tsc`

| Ecosystem | Check Command | Lint Command | Dev Port | Notes |
|-----------|--------------|--------------|----------|-------|
| Next.js | `pnpm type-check` | `pnpm lint:fix` | 3000 | Port may be overridden in `next.config.*` |
| Nuxt | `nuxi typecheck` | `pnpm lint` | 3000 | |
| Angular | `ng test` | `ng lint` | 4200 | |
| Vue (Vite) | `vue-tsc` | `eslint .` | 5173 | |
| Svelte | `svelte-check` | `eslint .` | 5173 | |
| Remix | `tsc` | `eslint .` | 3000 | |
| Astro | `astro check` | `eslint .` | 4321 | |
| Express / Fastify / Hono / NestJS | `tsc --noEmit` | `eslint .` | 3000 | |
| Django | `python manage.py test` | `flake8` / `ruff` | 8000 | |
| Flask / FastAPI / Starlette | `pytest` | `ruff` / `flake8` | 8000 | |
| Go | `go test ./...` | `golangci-lint run` | 8080 | |
| Rust | `cargo test` | `cargo clippy` | 8080 | |
| Spring Boot | `./mvnw test` | — | 8080 | Gradle: `./gradlew test` |
| .NET | `dotnet test` | — | 5000 | |

**Frontend path defaults for monorepos:**

| Monorepo Tool | Common Frontend Path |
|---------------|---------------------|
| Turborepo | `apps/web` or `apps/frontend` |
| Nx | `apps/<appname>` |
| pnpm workspaces | Defined in `pnpm-workspace.yaml` `packages` field |
| npm/yarn workspaces | Defined in `package.json` `workspaces` field |

Always verify by reading the actual workspace config rather than assuming the default path.

---

## 6. Ambiguous Cases

When multiple manifest files are detected at the project root, do not guess — report ALL detected stacks in the output. Do not ask the user during the scan. Ambiguity is resolved during the user confirmation flow.

**Example structured output when ambiguous:**
| Field | Value |
|-------|-------|
| `language` | `["Node.js", "Python"]` |
| `framework` | `["Next.js", null]` |
| ... | ... |

Note: The user will resolve which stack is primary during the confirmation flow (init-flow.md Section 4, Item 1).

**Other ambiguous scenarios:**

- Multiple `build.gradle` files with no root `settings.gradle` — report all subprojects in the output.
- `package.json` with both `next` and `express` — may be a custom server setup; report both in the output.
- Python project with both `pyproject.toml` and `requirements.txt` — report both in the output.
- No manifest files found — report `language: null` in the output.
