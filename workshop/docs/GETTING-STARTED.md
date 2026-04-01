# Getting Started with cluar5

This guide takes you from zero to a running cluar5 project in four steps.

---

## What you need

- [Docker](https://docs.docker.com/get-docker/) installed and running
- [VS Code](https://code.visualstudio.com/) with the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- A GitHub account

That's it. No compilers. No language runtimes. No local toolchain. Everything runs inside the container.

---

## Step 1 — Create your project from the template

1. Go to **[github.com/AI-Vectoring/cluar5](https://github.com/AI-Vectoring/cluar5)**
2. Click **"Use this template"** → **"Create a new repository"**
3. Give it a name, choose public or private, click **"Create repository"**

You now have your own copy of cluar5 on GitHub, ready to become your project.

---

## Step 2 — Open it in VS Code

1. Open **VS Code**
2. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
3. Type and select: **Dev Containers: Clone Repository in Container Volume**
4. Paste your new repository URL and press Enter
5. VS Code builds the dev container and opens your workspace inside it

First build takes a few minutes — Docker is pulling Debian and installing the development toolchain. Every subsequent open is instant.

---

## Step 3 — Initialize your project

The moment the container is ready, a setup wizard runs automatically in the terminal:

```
╔══════════════════════════════════════════════╗
║       cluar5 — First Run Setup               ║
╚══════════════════════════════════════════════╝

This is a fresh clone of the cluar5 template.
Enter your project details to initialize the repo.

Project name (e.g. my-app):         your-project
GitHub username or org (e.g. acme): your-github-user
```

Type your project name and GitHub username. The wizard:
- Renames all `cluar5` references throughout the repo to your project name
- Updates `PROJECT.conf` with your repository URL
- Commits and pushes the initialization to GitHub

Your repo is now yours. The template is gone. What remains is your project.

---

## Step 4 — Build the base image

In the VS Code integrated terminal (which is running *inside* the container):

```bash
make build-base
```

This compiles musl-libc, LuaJIT, and Gambit Scheme from source into a shared builder image. It runs once — or again when you update `VERSIONS`. Everything else builds on top of it.

```bash
# When it finishes, verify everything works:
make dev-build
./build/your-project-dev --health
# → OK
```

---

## You're ready. Here's what you have.

```
your-project/
├── c/main.c          ← The binding agent. Owns main(), I/O, and the runtime.
├── lua/main.lua      ← Start here. This is your workspace.
├── r5/main.scm       ← The LLM's domain. Complex logic lives here.
└── workshop/         ← Tooling, docs, Dockerfiles. Touch when needed.
```

---

## Where to go next

### Build something

Open `lua/main.lua`. Describe to your LLM what you want to build. The Lua layer is your primary surface — readable, adjustable, immediately legible. Most projects live here for a long time, many stay here forever.

When logic grows complex, move it to `r5/main.scm`. When you need raw I/O performance or a C library, extend `c/main.c`.

### Run the Gambit REPL

cluar5 includes one of the most powerful development tools in existence: a live REPL connected to your running process. While your application runs, you can evaluate Scheme expressions, redefine functions, and observe the effects — without restarting, without recompiling, without interruption.

```bash
# In one terminal: run your app
make dev-run

# In another terminal: connect to the live process
rlwrap nc localhost 7000
```

You are now inside the running application. Type any Scheme expression. See the result. Redefine a function. Watch it take effect immediately. This is the runtime talking back.

See [REPL.md](REPL.md) for the full guide.

### Test in staging

When you're ready to validate against the production binary:

```bash
make stage
docker run --rm -it your-project-stage
```

The stage container builds the same static binary as production — same musl environment, same flags — with test tools available.

### Ship to production

```bash
make prod
docker run -d \
    --name your-project \
    --read-only \
    --tmpfs /tmp \
    -p 8080:8080 \
    --cap-drop=ALL \
    --security-opt no-new-privileges:true \
    your-project-prod
```

A single static binary in a scratch container. No OS. No shell. No attack surface.

---

## Something went wrong?

| Problem | Fix |
|---|---|
| `make build-base` fails at Gambit | Check internet connectivity inside the container — it clones from GitHub |
| `--health` returns `UNHEALTHY` | The stub always returns OK — something else is wrong, check `docker logs` |
| Port 7000 not reachable | Ensure `forwardPorts` is set in `.devcontainer/devcontainer.json` |
| Push failed during initialization | Run `git push` manually from the terminal |
| Container won't start | Run `docker system prune` and rebuild |

---

## Further reading

- [TEMPLATE-USAGE.md](TEMPLATE-USAGE.md) — What to keep, what to replace, the full development arc
- [DEV-WORKFLOW.md](DEV-WORKFLOW.md) — Day-to-day development, staging, and forensics
- [REPL.md](REPL.md) — The live Gambit REPL — what it is and how to use it
- [EXTENSIONS.md](EXTENSIONS.md) — HTTP, databases, message queues, and other additions
- [Philosophy-and-amazingness.md](Philosophy-and-amazingness.md) — Why cluar5 exists
