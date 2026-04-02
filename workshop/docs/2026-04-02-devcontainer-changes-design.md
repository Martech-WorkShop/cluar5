# Dev Container Changes — Design Spec
**Date:** 2026-04-02
**Scope:** `Dockerfile.dev`, `docker-compose.yml`, `Dockerfile.builder-base`

---

## Context

This spec covers four additions/changes to the development environment. The other containers (stage, prod, debug) are out of scope except where noted.

---

## 1. SQLite

**What:** Add SQLite to the dev container as an in-process embedded database.

**Packages (Debian):**
- `libsqlite3-dev` — headers and static lib for linking from C
- `sqlite3` — CLI tool for inspecting databases during development

**Rationale:** SQLite is the appropriate choice for local/embedded data. No external process, no network, no configuration. Lives entirely inside the dev container.

---

## 2. PostgreSQL

**What:** Dev container gets client libraries and CLI only. PostgreSQL server is external — either a docker-compose sidecar or a remote service. Both options are provided.

**Packages added to `Dockerfile.dev` (Debian):**
- `libpq-dev` — headers for C code connecting to Postgres
- `postgresql-client` — `psql` CLI for inspecting/querying during development

**`docker-compose.yml` changes:**
- Uncomment and activate the existing `db` service (postgres:17-alpine)
- Add a named volume `db-data` mapped to `/var/lib/postgresql/data` so data survives container recreation
- Keep the `DB_URL` environment variable on the app service pointing to the sidecar
- Add a comment block documenting how to point `DB_URL` at an external service instead

**Rationale:** Embedding a Postgres server in the dev container would complicate the image and muddle concerns. Sidecar is the standard pattern and works well with plain Docker bridge networking (no Swarm overlay involved in dev). Named volume ensures data is not lost on container rebuild.

---

## 3. Lua 5.4 + LuaJIT 2.1

**What:** Both Lua interpreters available in the dev container. LuaJIT is already present (Debian package, upstream — not OpenResty). Lua 5.4 is added.

**Packages added to `Dockerfile.dev` (Debian):**
- `lua5.4` — Lua 5.4 interpreter
- `liblua5.4-dev` — headers and lib for embedding Lua 5.4 in C

**Existing packages kept:**
- `luajit` — upstream LuaJIT 2.1 interpreter (already present, correct version)
- `libluajit-5.1-dev` — headers for embedding LuaJIT in C (already present)

**The `lua` symlink:** On Debian, `lua5.4` registers with `update-alternatives` and sets `/usr/bin/lua` → `lua5.4`. The `luajit` package does not compete for this symlink. Result: `lua` = Lua 5.4, `luajit` = LuaJIT. This must be verified during implementation and made explicit in the Dockerfile with a comment so it is not accidentally changed.

**Key distinction to document for developers using this template:**

| Command | Runtime | Language version | Use when |
|---|---|---|---|
| `lua5.4` or `lua` | Standard Lua | Lua 5.4 | Modern language features, to-be-closed vars, native integers |
| `luajit` | LuaJIT | Lua 5.1 + extensions | Performance-critical code, production Lua applications |

These are **not interchangeable** — they implement different language versions. Code targeting LuaJIT must be Lua 5.1 compatible. Code using Lua 5.4 features will not run on LuaJIT.

**Lua's role in the platform (deferred decision):** Whether Lua serves as a primary application language (favour LuaJIT for performance) or a prototyping language (favour Lua 5.4 for modern syntax, migrate to C/Gambit later) is not decided at the platform level. The platform makes both available; the project using the template decides.

---

## 4. H2O HTTP Server

**What:** H2O built from source in `Dockerfile.dev`. HTTP/1.x and HTTP/2. HTTP/3 (QUIC) deferred.

**Why not a Debian package:** H2O was removed from Debian 13 (Trixie) in May 2025 due to unresolved CVEs in the Debian-maintained package and an inactive Debian maintainer. The upstream project on GitHub is actively maintained. Building from source gets the current, patched version.

**Why not nginx or OpenResty:**
- nginx HTTP/3 is beta with no clear timeline — this was the primary reason to prefer H2O
- OpenResty is not in Debian's official repositories (requires adding an external apt repo) and its main advantage (embedded LuaJIT) is irrelevant here since application logic lives outside the HTTP server
- H2O is the correct long-term choice; building from source is the right path to it

**Why not HTTP/3 now:** HTTP/3 (QUIC) requires quictls or BoringSSL instead of standard OpenSSL. That is a non-trivial dependency chain. Deferred until specifically needed.

**Build approach for `Dockerfile.dev`:**
- Build dependencies from Debian: `cmake`, `libssl-dev`, `zlib1g-dev`, `libyaml-dev`
- Clone H2O from `https://github.com/h2o/h2o.git` at a pinned commit hash. H2O stopped tagging releases in 2019; the project's official policy is that master is always production-ready. Pin to `77288edcfbed39faa2db47160d2c98915bdbd0c1` (master, 2026-04-02)
- Standard CMake build: `cmake -DCMAKE_INSTALL_PREFIX=/usr/local .` then `make && make install`
- Build runs as root during image build, H2O runs as `appuser` at runtime
- H2O commit hash pinned in `VERSIONS` file under a new `# --- Dev Tools ---` tier. No tags exist upstream — commit hash is the correct pinning mechanism

---

## 5. Dockerfile.builder-base — LuaJIT Fork Change

**What:** Replace the OpenResty LuaJIT fork (`https://github.com/openresty/luajit2.git`) with the upstream LuaJIT source (`https://github.com/LuaJIT/LuaJIT.git`, branch `v2.1`).

**Rationale:** The user's stated preference is upstream LuaJIT 2.1, not the OpenResty fork. The OpenResty fork was originally chosen because upstream was considered less active. This decision is reversed — upstream is now preferred for consistency with the dev container, which also uses upstream LuaJIT via the Debian package.

**Change:** In `Dockerfile.builder-base`, update the `git clone` URL and branch for the LuaJIT build. The build flags (`BUILDMODE=static`, `CC=musl-gcc`, etc.) remain the same. Update `VERSIONS` file to reflect the new version string.

**Note:** This affects `Dockerfile.stage`, `Dockerfile.prod`, and `Dockerfile.debug` indirectly — they all inherit from `builder-base`. The compiled output is a static `.a` library; the change is transparent to those containers.

---

## Files Changed

| File | Change |
|---|---|
| `workshop/docker/Dockerfile.dev` | Add SQLite, libpq, Lua 5.4, H2O source build; add comments on `lua` symlink |
| `workshop/docker/docker-compose.yml` | Activate Postgres sidecar, add named volume, add external service docs |
| `workshop/docker/Dockerfile.builder-base` | Switch LuaJIT clone from OpenResty fork to upstream |
| `VERSIONS` | Add H2O version entry under new `Dev Tools` tier; update LuaJIT version string |

---

## Out of Scope

- Stage, prod, debug containers — unchanged except they inherit the LuaJIT fork change via builder-base
- Traefik — discussed, confirmed to work standalone with Docker socket; no changes needed now
- Docker Swarm — dropped; no changes needed
- HTTP/3 / QUIC — deferred
