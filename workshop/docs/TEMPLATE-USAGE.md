# Using cluar5 as a Project Template

cluar5 is a starting point for LLM-native projects. Fork it, initialize it with your project name, and start building. The architecture is already in place — your job is to direct.

---

## Step 1 — Fork the template on GitHub

1. Go to [github.com/AI-Vectoring/cluar5](https://github.com/AI-Vectoring/cluar5)
2. Click **"Use this template"** → **"Create a new repository"**
3. Name it, set visibility, click **"Create repository"**

---

## Step 2 — Open in VS Code Dev Containers

1. Open VS Code
2. `Ctrl+Shift+P` → **Dev Containers: Clone Repository in Container Volume**
3. Paste your new repository URL
4. Wait for the container to build (first time takes a few minutes)

On first launch the container runs `workshop/scripts/rename.sh` automatically. It will prompt:

```
Project name (e.g. my-app):         your-project
GitHub username or org (e.g. acme): your-github-user
```

It renames all references throughout the repo, commits, and pushes. Your project is initialized.

---

## Step 3 — Build the base image

Inside the dev container terminal:

```bash
make build-base
```

This builds the shared builder image — musl-gcc, Gambit, and LuaJIT compiled from source. Takes a few minutes the first time. All subsequent container builds reuse it.

---

## Where to build your project

### Start in Lua — always

`lua/main.lua` is where everything begins. Describe what you need to the LLM, let it write Lua, read the result, refine. The Lua layer is designed to be readable and adjustable without deep expertise. Most of the iteration in a project happens here.

For many projects, this layer alone is sufficient to ship a complete, working product.

### Move complexity to Scheme — when Lua grows opaque

When logic becomes dense enough that reading it requires effort, move it to `r5/main.scm`. Scheme's expressiveness handles complexity gracefully — state machines, parsers, rule engines, data transformations. The LLM operates freely here. You don't need to read it, but you can trust it.

### Use C for the rest — when it must be C

`c/main.c` owns the main loop and the runtime bindings. Add C when you need maximum I/O performance, direct hardware access, or when a Lua rough edge requires a native solution. C is also where you add capabilities that neither Lua nor Scheme can provide on their own.

---

## What to keep vs. what to replace

### Keep as-is

| File | Why |
|---|---|
| `workshop/docker/Dockerfile.*` | The container model is the point of the template |
| `workshop/scripts/` | Version management and rename tooling |
| `workshop/health/` | Health check contract |
| `Makefile` | Build automation — extend, don't replace |
| `.devcontainer/devcontainer.json` | VS Code integration |
| `PROJECT.conf`, `VERSIONS` | Already updated by rename.sh |

### Replace with your application

| File | What to do |
|---|---|
| `lua/main.lua` | Start here. Replace the stub with your Lua logic. |
| `r5/main.scm` | Move complex logic here as the project grows. |
| `c/main.c` | Extend the main loop and add C bindings as needed. |
| `README.md` | Replace with your project's documentation. |

---

## Directory structure

```
/
├── c/                    ← C source (core engine, main loop, I/O)
├── lua/                  ← LuaJIT (primary human surface — start here)
├── r5/                   ← Gambit Scheme (LLM's domain — complex logic)
├── .devcontainer/        ← VS Code Dev Containers configuration
├── workshop/
│   ├── docker/           ← All Dockerfiles + docker-compose stub
│   ├── scripts/          ← rename.sh, check-versions.sh, update-versions.sh
│   ├── health/           ← Health check contract and reference implementation
│   └── docs/             ← This documentation
├── build/                ← Generated output (gitignored)
├── PROJECT.conf          ← Project name and repository URL
├── VERSIONS              ← Pinned dependency versions
├── Makefile              ← Build automation
└── README.md             ← Your project's documentation
```

---

## LuaJIT vs. standard Lua 5.4

The template defaults to **LuaJIT (OpenResty fork)**. LuaJIT's FFI library allows Lua to call C functions directly at near-zero overhead — a significant architectural advantage in this stack.

To switch to standard Lua 5.4 (if your project has no need for FFI):

```makefile
# In Makefile:
LUA_IMPL ?= lua54
```

If you use `ffi` in your Lua code, you cannot switch without rewriting those calls.

---

## Updating dependencies

```bash
# See what has changed upstream
workshop/scripts/check-versions.sh

# Update VERSIONS to latest upstream releases
workshop/scripts/update-versions.sh

# Rebuild the base image after updating
make build-base
```

Commit `VERSIONS` after updating so all future container builds use the same versions.
