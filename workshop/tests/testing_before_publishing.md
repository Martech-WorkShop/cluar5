# Testing Before Publishing

This document describes the testing strategy for the cluar5 container images before they are merged to main, pushed to GitHub, or published to Docker Hub.

---

## Why We Test

The containers are the product. A broken image on Docker Hub is a broken product. These tests exist to catch:

- Packages that failed to install or were removed from Debian
- Source builds (H2O, LuaJIT, Gambit) that compiled but don't actually work
- Config changes that broke the compose setup
- Regressions from Dockerfile edits

**Rule:** All tests must pass before any of the following:
- Merging a feature branch into `main`
- Pushing `main` to GitHub
- Publishing images to Docker Hub

---

## Test Suites

Each suite is an independent script. They can be run individually or all at once via `run-all.sh`.

| Script | What it tests |
|---|---|
| `test-dev.sh` | Dev container image — all runtimes, tools, H2O HTTP serving |
| `test-builder.sh` | Builder-base image — musl static libs, Gambit compiler |
| `test-compose.sh` | docker-compose — Postgres sidecar, data persistence |

---

## Running Tests

**All suites at once (recommended before publishing):**
```bash
bash workshop/tests/run-all.sh
```

**Individual suites:**
```bash
bash workshop/tests/test-dev.sh
bash workshop/tests/test-builder.sh
bash workshop/tests/test-compose.sh
```

All scripts must be run from the **repository root**.

Images are built automatically before testing. To skip the build (if the image is already up to date):
```bash
SKIP_BUILD=1 bash workshop/tests/test-dev.sh
```

---

## Output Format

All scripts use consistent colour-coded output:

- **Blue** — section headers and informational output
- **Green** — test passed
- **Yellow** — warning (test passed with caveats, or skipped)
- **Red** — test failed

A summary at the end shows total passed/warned/failed counts and exits with code `0` (all passed) or `1` (any failures).

---

## What Each Suite Covers

### test-dev.sh

Tests the dev container image (`cluar5-dev`) by running commands inside it:

1. `lua` symlink resolves to Lua 5.4 (not LuaJIT)
2. Lua 5.4 native integer type works (`math.type(1)` → `integer`)
3. LuaJIT runs and reports version
4. Gambit Scheme interpreter evaluates an expression
5. C compilation: gcc compiles and runs a hello-world binary
6. SQLite: in-memory query returns a result
7. PostgreSQL client: `psql` is present and reports version
8. H2O: `h2o --version` succeeds
9. H2O: actually serves a static file via HTTP (curl to localhost)

### test-builder.sh

Tests the builder-base image (`cluar5-builder-base`) — the shared musl build environment:

1. LuaJIT static library exists at `/opt/musl/lib/libluajit-5.1.a`
2. LuaJIT headers exist at `/opt/musl/include/luajit-2.1/`
3. Gambit static library exists at `/opt/musl/lib/libgambit.a`
4. Gambit compiler (`gsc`) exists at `/opt/musl/bin/gsc`
5. `musl-gcc` compiles a static binary
6. Compiled binary is statically linked (confirmed via `file`)
7. Compiled binary executes correctly

### test-compose.sh

Tests the docker-compose setup:

1. `docker compose config` validates without errors
2. Postgres sidecar starts successfully
3. `pg_isready` confirms the server accepts connections
4. Data written to the database persists across container recreation (`docker compose down` + `up`)
5. Cleanup (volumes removed after test)

---

## What Is NOT Tested Here

These are out of scope for this test suite and require manual verification or a running application:

- **Full application compile** — `make dev-build` inside the dev container is not run here. The builder-base is tested structurally (libs present, musl compiles) but not against the actual project source.
- **HTTP/3** — confirmed absent, not tested for correctness (deferred by design).
- **VS Code Dev Containers integration** — requires VS Code; cannot be automated here.
- **Production/stage/debug containers** — separate test suite needed when those containers change.
- **Docker Hub publishing** — not automated; manual `docker push` after all tests pass.
