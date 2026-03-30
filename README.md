# Hybrid Core Architecture (C + Gambit + LuaJIT)

A high-performance, secure application architecture combining the raw speed of **C**, the safety and abstraction of **Gambit Scheme**, and the rapid prototyping capabilities of **LuaJIT**.

## 🏗 Architecture Overview

This project utilizes a **"Performance-Driven Refactoring"** pipeline:

1.  **Core Engine (C):** Handles the main loop, memory management, threading, signal handling, and low-level I/O drivers. Provides deterministic control and crash containment.
2.  **Logic Engine (Gambit Scheme):** Compiles to native C for complex algorithms, state machines, parsers, and data transformation. Offers GC safety, hygienic macros, and functional abstractions without VM overhead.
3.  **Orchestration (LuaJIT):** Handles configuration, UI binding, hot-reloadable business logic, and gluing components together. Provides instant iteration and a massive ecosystem of FFI bindings.

### The Deployment Model
*   **Development:** Hot-reloadable source files (`.scm`, `.lua`) interpreted at runtime for instant feedback. No recompilation needed for logic changes.
*   **Production:** A **single statically linked binary** containing all logic. No external dependencies, no source code exposed, no interpreters needed on the host. Zero attack surface.

## 📂 Project Structure

```text
/
├── src/
│   ├── main.c              # C Entry point & Main Loop
│   ├── drivers.c           # Low-level C I/O drivers
│   ├── core_logic.scm      # Gambit Scheme logic (Compiled to C)
│   └── game_rules.lua      # LuaJIT scripting (Hot-reloadable)
├── Dockerfile.stage        # Dev/Stage environment (Full toolchain)
├── Dockerfile.prod         # Hardened Production environment (Single binary)
├── Makefile                # Build automation
└── README.md               # This file
```

## 🚀 How to Use This

### Prerequisites
*   Docker & Docker Compose
*   (Optional) Local toolchain: `gcc`, `musl-tools`, `gambit`, `luajit` (if building outside Docker)

### 1. Development Workflow (Hot-Reload)
Run the development container which mounts your source code and includes compilers/interpreters. Changes to `.lua` and `.scm` files are picked up instantly.

```bash
# Build the dev image
docker build -f Dockerfile.stage -t my-app-dev .

# Run with source code mounted from your host
docker run --rm -it \
  -v $(pwd):/src \
  -p 8080:8080 \
  my-app-dev \
  /bin/bash

# Inside the container:
$ make dev-run
# Edit .lua or .scm files on your host -> Changes reflect instantly in the running app.
# Edit .c files -> Run 'make' to recompile the core engine.
```

### 2. Building for Production
Create a single, static, stripped binary. This step compiles Gambit to C, links LuaJIT statically, and produces one executable file.

```bash
# Build the production image (Multi-stage build)
docker build -f Dockerfile.prod -t my-app-prod .

# (Optional) Extract the binary to run bare-metal
docker create --name temp-container my-app-prod
docker cp temp-container:/app/my-app ./my-app
docker rm temp-container
```

### 3. Running in Production
Run the hardened container. It contains **only** the binary, CA certs, and timezone data. No shell, no compilers, no source code.

```bash
docker run -d \
  --name my-service \
  --read-only \
  --tmpfs /tmp \
  -p 8080:8080 \
  --cap-drop=ALL \
  --security-opt no-new-privileges:true \
  my-app-prod
```

## 🔒 Security Features

*   **Single Binary:** No external library dependencies (`libc` is statically linked via `musl`).
*   **No Source Code:** Production image contains zero `.c`, `.scm`, or `.lua` files. Logic is embedded as bytecode or machine code.
*   **Non-Root:** Runs as an unprivileged user (`appuser`).
*   **Hardened Container:** Designed to be run with `--cap-drop=ALL`, read-only filesystem, and no-new-privileges.
*   **Minimal Base:** Built on `debian:13-slim` with aggressive package stripping. No shells or package managers in the final runtime path.

## 🛠 Tech Stack

*   **Languages:** C (Core), Gambit Scheme (Logic), LuaJIT (Scripting)
*   **OS:** Debian 13 (Trixie)
*   **Linking:** Static (musl-libc) for portability and minimalism
*   **Containerization:** Docker (Multi-stage builds)
*   **Philosophy:** Performance-Driven Refactoring (Start in Lua, move to Gambit/C only when needed)

## 📝 License
MIT




Here is the final, definitive setup.

**Philosophy:**
1.  **Production (`Dockerfile.prod`):** A **locked box**. Contains **only** the binary and CA certs. **No shell**, no `bash`, no `curl`, no `ls`. If it crashes, you cannot touch it inside. You **must** extract artifacts to analyze them.
2.  **Staging (`Dockerfile.stage` or your local dev env):** The **workshop**. Contains **everything** (`gdb`, `vim`, `bash`, `gcc`, `strace`). This is where you bring the extracted artifacts to perform forensics.

---

### 1. Production Dockerfile (`Dockerfile.prod`)
*Target: Maximum Security. No interactive access.*

---

### 2. Staging / Forensics Environment
*Target: Full Visibility. Use your existing `Dockerfile.stage` or a specific debug build.*

You don't need a new file. Just ensure your Staging image has:
*   `gdb`, `valgrind`, `strace`
*   `vim`, `bash`, `curl`, `wget`
*   `gcc`, `make`
*   **Unstripped binary** (Compile with `-g` flag instead of `strip`).

**The Forensics Workflow (When Prod Crashes):**

1.  **Extract Artifacts from Prod:**
    ```bash
    # Create a local folder for the autopsy
    mkdir -p ./forensics

    # Pull the binary (exact match)
    docker cp my-app-prod:/app/my-app ./forensics/my-app

    # Pull the core dump (assuming ulimit was set)
    docker cp my-app-prod:/tmp/core ./forensics/core.dump

    # Pull logs
    docker cp my-app-prod:/var/log/app ./forensics/logs
    ```

2.  **Analyze in Staging (or Local):**
    Run your Staging container (which has all tools) and mount the forensics folder.
    ```bash
    docker run -it --rm \
      -v $(pwd)/forensics:/data \
      my-app-staging \
      /bin/bash
    ```
    *Inside Staging:*
    ```bash
    cd /data
    gdb ./my-app core.dump
    # Now you have full power to debug.
    ```

### Summary of Differences

| Feature | Production (`scratch`) | Staging (`debian:13-slim` + Tools) |
| :--- | :--- | :--- |
| **Base Image** | `scratch` (Empty) | `debian:13-slim` |
| **Shell** | **None** | `bash` |
| **Tools** | **None** | `gdb`, `vim`, `curl`, `strace`, etc. |
| **Binary** | Stripped (Small, Hard to reverse) | Unstripped (Debug symbols included) |
| **Access** | **Impossible** (`docker exec` fails) | Full Root Access |
| **Purpose** | Run securely, dump core on crash | Analyze the core dump, fix bugs |

