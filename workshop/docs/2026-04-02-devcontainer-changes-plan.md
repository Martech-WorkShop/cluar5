# Dev Container Changes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add SQLite, PostgreSQL client libs, Lua 5.4, and H2O (source build) to the dev container; switch builder-base from OpenResty LuaJIT fork to upstream.

**Architecture:** All changes are confined to Dockerfiles and supporting config. The dev container gets new Debian packages plus a source build of H2O. The builder-base gets a URL/branch swap for LuaJIT — same build flags, different upstream. docker-compose.yml activates the existing Postgres sidecar stub with a named volume.

**Tech Stack:** Debian 13 (Trixie), Docker, CMake, OpenSSL, H2O (GitHub master), LuaJIT (GitHub v2.1 branch), Lua 5.4, SQLite, PostgreSQL 17

---

## Files

| File | Action | What changes |
|---|---|---|
| `VERSIONS` | Modify | Add `H2O_COMMIT`; replace OpenResty `LUAJIT_VERSION` with upstream value |
| `workshop/docker/Dockerfile.builder-base` | Modify | Clone URL + branch: OpenResty fork → upstream LuaJIT |
| `workshop/docker/Dockerfile.dev` | Modify | Add SQLite, libpq, Lua 5.4 packages; add H2O source build |
| `workshop/docker/docker-compose.yml` | Modify | Uncomment and activate Postgres sidecar; add named volume |

---

## Task 1: Update VERSIONS

**Files:**
- Modify: `VERSIONS`

- [ ] **Step 1: Open VERSIONS and make the following exact changes**

Current content to replace:
```
# LuaJIT (OpenResty fork — more active than upstream, includes important patches)
LUAJIT_VERSION=v2.1-20240314
```

Replace with:
```
# LuaJIT (upstream — branch v2.1, the active development line)
LUAJIT_VERSION=v2.1
```

Then add a new section at the bottom of the file:
```
# --- Dev Tools ---
# H2O HTTP server — built from source (no Debian 13 package; upstream is actively maintained).
# No release tags since 2019; project policy is that master is always production-ready.
# To update: pick a recent master commit from https://github.com/h2o/h2o/commits/master
H2O_COMMIT=77288edcfbed39faa2db47160d2c98915bdbd0c1
```

- [ ] **Step 2: Verify the file reads correctly**

```bash
cat VERSIONS
```

Expected output — confirm these two lines appear with correct values:
```
LUAJIT_VERSION=v2.1
H2O_COMMIT=77288edcfbed39faa2db47160d2c98915bdbd0c1
```

- [ ] **Step 3: Commit**

```bash
git add VERSIONS
git commit -m "versions: switch LuaJIT to upstream v2.1 branch, add H2O commit pin"
```

---

## Task 2: Update Dockerfile.builder-base — LuaJIT upstream

**Files:**
- Modify: `workshop/docker/Dockerfile.builder-base`

- [ ] **Step 1: Replace the LuaJIT clone block**

Find:
```dockerfile
# --- Build LuaJIT (OpenResty fork) as a static library with musl ---
# BUILDMODE=static produces libluajit-5.1.a instead of a shared lib.
# The OpenResty fork is used over upstream because upstream is effectively unmaintained.
RUN git clone --depth=1 --branch ${LUAJIT_VERSION} \
        https://github.com/openresty/luajit2.git /tmp/luajit && \
```

Replace with:
```dockerfile
# --- Build LuaJIT (upstream) as a static library with musl ---
# BUILDMODE=static produces libluajit-5.1.a instead of a shared lib.
# Using upstream LuaJIT v2.1 branch (github.com/LuaJIT/LuaJIT).
RUN git clone --depth=1 --branch ${LUAJIT_VERSION} \
        https://github.com/LuaJIT/LuaJIT.git /tmp/luajit && \
```

All other lines in the RUN block are unchanged.

- [ ] **Step 2: Verify the file looks correct**

```bash
grep -A5 "Build LuaJIT" workshop/docker/Dockerfile.builder-base
```

Expected:
```
# --- Build LuaJIT (upstream) as a static library with musl ---
# BUILDMODE=static produces libluajit-5.1.a instead of a shared lib.
# Using upstream LuaJIT v2.1 branch (github.com/LuaJIT/LuaJIT).
RUN git clone --depth=1 --branch ${LUAJIT_VERSION} \
        https://github.com/LuaJIT/LuaJIT.git /tmp/luajit && \
```

- [ ] **Step 3: Build the builder-base image to confirm the change works**

```bash
docker build -f workshop/docker/Dockerfile.builder-base -t cluar5-builder-base workshop/docker/
```

Expected: build completes successfully. The LuaJIT clone step should print:
```
Cloning into '/tmp/luajit'...
```
without errors. If it fails on the LuaJIT build step with a compile error, the upstream source has an incompatibility with the current flags — check the H2O issue tracker for known musl issues with the v2.1 branch.

- [ ] **Step 4: Commit**

```bash
git add workshop/docker/Dockerfile.builder-base
git commit -m "builder-base: switch LuaJIT from OpenResty fork to upstream v2.1"
```

---

## Task 3: Add Debian packages to Dockerfile.dev

Adds SQLite, PostgreSQL client libs, and Lua 5.4. No source builds in this task.

**Files:**
- Modify: `workshop/docker/Dockerfile.dev`

- [ ] **Step 1: Add packages to the existing apt-get install block**

The current apt-get block ends with:
```dockerfile
    # Editors (lightweight, for quick edits inside the container)
    vim \
    nano \
    && rm -rf /var/lib/apt/lists/*
```

Replace with:
```dockerfile
    # Editors (lightweight, for quick edits inside the container)
    vim \
    nano \
    # SQLite — embedded database (in-process, no server)
    libsqlite3-dev \
    sqlite3 \
    # PostgreSQL client — connect to external Postgres (sidecar or remote)
    libpq-dev \
    postgresql-client \
    # Lua 5.4 — standard Lua (modern language: native integers, <close> vars, etc.)
    # LuaJIT is already above — these are TWO DIFFERENT RUNTIMES, not interchangeable:
    #   lua / lua5.4  → Lua 5.4 (this), Lua 5.1-incompatible features available
    #   luajit        → LuaJIT 2.1, Lua 5.1 compatible only
    lua5.4 \
    liblua5.4-dev \
    # OpenSSL headers — required for H2O source build (next section)
    libssl-dev \
    zlib1g-dev \
    libyaml-dev \
    && rm -rf /var/lib/apt/lists/*
```

- [ ] **Step 2: Verify the `lua` symlink behaviour after install**

Build a temporary image and check:
```bash
docker build -f workshop/docker/Dockerfile.dev -t cluar5-dev-test . && \
docker run --rm cluar5-dev-test -c "ls -la /usr/bin/lua*; lua --version; lua5.4 --version; luajit --version"
```

Expected output (versions may vary slightly):
```
/usr/bin/lua -> lua5.4          ← symlink must point to lua5.4, not luajit
/usr/bin/lua5.4
/usr/bin/luajit
Lua 5.4.x  ...
Lua 5.4.x  ...
LuaJIT 2.1.x ...
```

If `/usr/bin/lua` does not exist or points elsewhere, add this line to the Dockerfile after the apt-get block:
```dockerfile
RUN update-alternatives --install /usr/bin/lua lua /usr/bin/lua5.4 100
```

- [ ] **Step 3: Verify SQLite and libpq are present**

```bash
docker run --rm cluar5-dev-test -c "sqlite3 --version && pg_isready --version"
```

Expected:
```
3.x.x ...      ← SQLite version
pg_isready (PostgreSQL) 17.x
```

- [ ] **Step 4: Commit**

```bash
git add workshop/docker/Dockerfile.dev
git commit -m "dev: add SQLite, libpq/pg-client, Lua 5.4, OpenSSL headers"
```

---

## Task 4: Add H2O source build to Dockerfile.dev

**Files:**
- Modify: `workshop/docker/Dockerfile.dev`

- [ ] **Step 1: Add the H2O build ARG and RUN block**

Add the following immediately before the `RUN groupadd` line (i.e. after the apt-get block, before user creation):

```dockerfile
# --- Build H2O HTTP server from source ---
# H2O has no release tags since 2019; master is the recommended source.
# HTTP/3 (QUIC) requires quictls/BoringSSL — deferred. This build: HTTP/1.x + HTTP/2 only.
# -DWITH_MRUBY=OFF: skip mruby scripting engine (requires ruby+bison, not needed here).
ARG H2O_COMMIT=77288edcfbed39faa2db47160d2c98915bdbd0c1

RUN git clone https://github.com/h2o/h2o.git /tmp/h2o && \
    cd /tmp/h2o && \
    git checkout ${H2O_COMMIT} && \
    mkdir build && cd build && \
    cmake -DCMAKE_INSTALL_PREFIX=/usr/local \
          -DWITH_MRUBY=OFF \
          .. && \
    make -j$(nproc) && \
    make install && \
    rm -rf /tmp/h2o
```

- [ ] **Step 2: Build the dev image**

```bash
docker build -f workshop/docker/Dockerfile.dev -t cluar5-dev .
```

Expected: build completes. The cmake + make steps for H2O will take a few minutes. Watch for any missing dependency errors — if cmake reports a missing library, add the corresponding `-dev` package to the apt-get block in Task 3.

- [ ] **Step 3: Verify H2O is installed and functional**

```bash
docker run --rm cluar5-dev -c "h2o --version"
```

Expected:
```
h2o version 2.x.x (with OpenSSL/x.x.x, ...)
```

- [ ] **Step 4: Confirm HTTP/2 is present, HTTP/3 is not**

```bash
docker run --rm cluar5-dev -c "h2o --version 2>&1 | grep -i quic || echo 'QUIC: not present (expected)'"
```

Expected:
```
QUIC: not present (expected)
```

- [ ] **Step 5: Commit**

```bash
git add workshop/docker/Dockerfile.dev
git commit -m "dev: build H2O from source (HTTP/1.x + HTTP/2, no QUIC)"
```

---

## Task 5: Activate Postgres sidecar in docker-compose.yml

**Files:**
- Modify: `workshop/docker/docker-compose.yml`

- [ ] **Step 1: Replace the entire docker-compose.yml with the activated version**

```yaml
# docker-compose.yml — Development services for cluar5-based projects.
#
# Usage:
#   docker compose up           # start all enabled services
#   docker compose up db        # start only the database
#   docker compose down         # stop and remove containers
#   docker compose down -v      # also remove named volumes (wipes DB data)
#
# PostgreSQL: runs as a sidecar. The app connects via DB_URL.
# To use an external Postgres instead, remove the db service and set DB_URL to
# point at your external host, e.g.:
#   DB_URL=postgres://user:password@db.example.com:5432/appdb
#
# Note: for VS Code Dev Containers workflows, you typically don't use
# docker-compose for the app itself — VS Code manages that container.
# This file is useful for spinning up backing services (DB, cache, etc.)
# that your app connects to during development.

services:

  # ── Application (dev build) ─────────────────────────────────────────────────
  # Uncomment if running outside VS Code Dev Containers.
  #
  # app:
  #   image: ${PROJECT_NAME:-cluar5}-dev
  #   build:
  #     context: ../..
  #     dockerfile: workshop/docker/Dockerfile.dev
  #   volumes:
  #     - ../..:/app          # mount source code for hot-reload
  #   ports:
  #     - "8080:8080"         # adjust to your application's port
  #   depends_on:
  #     - db
  #   environment:
  #     - DB_URL=postgres://appuser:password@db:5432/appdb

  # ── PostgreSQL ───────────────────────────────────────────────────────────────
  db:
    image: postgres:17-alpine
    restart: unless-stopped
    environment:
      POSTGRES_USER: appuser
      POSTGRES_PASSWORD: password
      POSTGRES_DB: appdb
    volumes:
      - db-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"           # remove this line to keep the DB private

  # ── Redis ────────────────────────────────────────────────────────────────────
  # redis:
  #   image: redis:7-alpine
  #   restart: unless-stopped
  #   volumes:
  #     - redis-data:/data
  #   ports:
  #     - "6379:6379"

  # ── Message queue (RabbitMQ) ─────────────────────────────────────────────────
  # mq:
  #   image: rabbitmq:3-management-alpine
  #   restart: unless-stopped
  #   ports:
  #     - "5672:5672"         # AMQP
  #     - "15672:15672"       # management UI → http://localhost:15672

# ── Named volumes ─────────────────────────────────────────────────────────────
volumes:
  db-data:
  # redis-data:
```

- [ ] **Step 2: Verify the compose file is valid**

```bash
docker compose -f workshop/docker/docker-compose.yml config
```

Expected: outputs the resolved config with no errors. Confirm `db` service appears with `db-data` volume.

- [ ] **Step 3: Start the db service and verify it accepts connections**

```bash
docker compose -f workshop/docker/docker-compose.yml up -d db && \
sleep 3 && \
docker compose -f workshop/docker/docker-compose.yml exec db pg_isready -U appuser
```

Expected:
```
/var/run/postgresql:5432 - accepting connections
```

- [ ] **Step 4: Confirm data persists across container recreation**

```bash
# Write something
docker compose -f workshop/docker/docker-compose.yml exec db \
  psql -U appuser -d appdb -c "CREATE TABLE ping (id serial); INSERT INTO ping DEFAULT VALUES;"

# Recreate the container (not the volume)
docker compose -f workshop/docker/docker-compose.yml down
docker compose -f workshop/docker/docker-compose.yml up -d db
sleep 3

# Read it back
docker compose -f workshop/docker/docker-compose.yml exec db \
  psql -U appuser -d appdb -c "SELECT count(*) FROM ping;"
```

Expected: `count` returns `1` — data survived the container recreation.

- [ ] **Step 5: Tear down**

```bash
docker compose -f workshop/docker/docker-compose.yml down
```

- [ ] **Step 6: Commit**

```bash
git add workshop/docker/docker-compose.yml
git commit -m "compose: activate Postgres sidecar with named volume for data persistence"
```

---

## Self-Review Checklist

- [x] SQLite in dev container → Task 3
- [x] libpq + postgresql-client in dev container → Task 3
- [x] Lua 5.4 in dev container → Task 3
- [x] `lua` symlink verified and documented → Task 3 Step 2
- [x] H2O built from source in dev container → Task 4
- [x] H2O commit hash pinned in VERSIONS → Task 1
- [x] HTTP/3 explicitly absent and verified → Task 4 Step 4
- [x] LuaJIT upstream in builder-base → Task 2
- [x] LUAJIT_VERSION updated in VERSIONS → Task 1
- [x] Postgres sidecar activated with named volume → Task 5
- [x] Data persistence verified → Task 5 Step 4
- [x] No TBDs or placeholders
