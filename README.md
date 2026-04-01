# cluar5

**cluar5 is the first stack designed around LLM coders — the first paradigm where LLM capabilities, preferences, advantages, and caveats are the main consideration for every decision.

LLMs have finally claimed ownership of the coding skill, yet we still force them to code in our preferred languages, using our beloved frameworks and the existing libraries we are comfortable with.

Free the full potential of LLM coders with cluar5.**

---

**C + Lua + R5** — An LLM-native development platform where LLMs can roam freely with minimal supervision, where domain experts can architect and trust the output, and where software engineers can interact with the first layer of code easily and make adjustments without effort.

---

## The philosophy

Modern LLMs write excellent code. The question is not whether to trust them — it is how to *structure* that trust.

cluar5 answers this with three layers, each with a distinct relationship between the human and the machine:

**The Lua layer** is where humans live. Its simplicity is intentional — not a limitation but a feature. An engineer who has never seen the codebase can read a Lua file and understand what it does. Adjustments are made here. Prototypes are born here. For many projects, this layer alone is sufficient to ship a complete, working product. The LLM writes it, the human reads it, and the conversation between them happens naturally at this surface.

**The Scheme layer** is where the LLM roams freely. Gambit Scheme carries the smallest surface area of any serious language ever created, yet it contains more expressive power than most engineers will ever need. This purity means the LLM makes intentional choices — there are no accidental idioms, no ambiguous constructs, almost no surface for hallucination. It is also a stealth C compiler and a stealth JavaScript compiler. Humans do not need to read it. But those who venture in will find something extraordinary.

**The C layer** binds everything together. It owns the main loop, memory, I/O, and signals — the things that require determinism and performance. It is the escape hatch when Lua hits a rough edge and the bridge that Scheme requires (Gambit has no I/O by design). It is also the foundation of the platform's most important property: all three layers run in the same process, sharing memory directly, communicating at RAM speed with zero interoperability cost.

The development arc is natural: prototype in Lua, move complexity to Scheme, bind performance-critical paths in C. The LLM drives all three transitions. The human steers.

---

## The stack

| Layer | Language | Who reads it | LLM's role | Human's role |
|---|---|---|---|---|
| Scripts | LuaJIT | Engineers, domain experts | Writes, iterates, prototypes | Reads, adjusts, directs |
| Logic | Gambit Scheme (R5) | Optional — brave engineers | Roams freely, expresses deeply | Architects, trusts |
| Core | C | Engineers when needed | Binds, performs, solves | Reviews critical paths |

### Why these three specifically

**LuaJIT** — not Lua 5.4, not Python, not JavaScript. LuaJIT's FFI allows Lua to call C functions directly, making the Lua↔C boundary essentially free. Its syntax is minimal enough that an LLM produces it cleanly and a human reads it without friction. It is complete on its own — many projects never need to leave this layer.

**Gambit Scheme** — not Racket, not Clojure, not Common Lisp. Gambit compiles directly to C, which means the Scheme layer and the C layer are not two things talking to each other — they become one binary. The R5RS standard (the smallest Scheme standard) is the constraint that makes the LLM's freedom safe: fewer constructs means fewer ways to go wrong.

**C** — not Rust, not C++, not Zig. C is the language in which everything else is ultimately written. When you hit a problem in any other language, C can solve it. It has no opinion about how you use it, which means the LLM can use it exactly as the architecture requires.


While not the main objective, at Cluar5, we're suckers for minimalism and performance, that's why we are so happy that these tools are both the best fit for LLMs and also the most performant, each in their category.

Lua is the most performant interpreted language with Luajit taking it close to C performance in specific aplications. R5 Scheme is about the purest lisp there is, making it the most expressive and capable language an LLM can gracefully use. And C is the king of so many things it could take pages... so let's say it's the king of raw performance, the absolute master of raw I/O speed and the owner of the vastest low level collection of both old and cutting edge libraries.


---

## The four containers

| Container | Purpose | Binary | Shell | User |
|---|---|---|---|---|
| `dev` | Daily development — Lua and Scheme interpreted, C compiled | gcc debug build | yes | appuser |
| `stage` | Pre-production — identical binary to prod, test tools available | musl static | yes | appuser |
| `prod` | Production — scratch image, single binary, nothing else | musl static, stripped | **no** | appuser |
| `debug` | Post-incident forensics — extract from prod, analyze here | musl static, unstripped | yes | root |

Production runs in a `scratch` container: no OS, no shell, no compilers, no attack surface. A single statically linked binary is the entire runtime. If it crashes, you extract the core dump and analyze it in the debug container. Production itself is never opened.

---

## Directory structure

```
/
├── c/                    ← C source (core engine, main loop)
├── lua/                  ← LuaJIT source (scripting layer — primary human surface)
├── r5/                   ← Gambit Scheme source (logic layer — LLM's domain)
├── .devcontainer/        ← VS Code Dev Containers configuration
├── workshop/
│   ├── docker/           ← All five Dockerfiles + docker-compose stub
│   ├── scripts/          ← rename.sh, check-versions.sh, update-versions.sh
│   ├── health/           ← Health check contract and reference implementation
│   └── docs/             ← DEV-WORKFLOW.md, TEMPLATE-USAGE.md, CONTRIBUTING.md
├── PROJECT.conf          ← Project name and repository URL
├── VERSIONS              ← Pinned dependency versions
├── Makefile              ← Build automation
└── .gitignore
```

---

## Health check

The production container calls `/app/cluar5 --health`. This flag is implemented in `c/main.c` — C is the only layer with visibility into all runtime subsystems. The stub always returns healthy. Extend `run_health_check()` as you build your application.

See [workshop/health/README.md](workshop/health/README.md) for the full contract.

---

## Dependencies

| Dependency | Version | Role |
|---|---|---|
| LuaJIT (OpenResty fork) | see `VERSIONS` | Scripting runtime, built with musl |
| Gambit Scheme | see `VERSIONS` | Logic compiler + runtime, built with musl |
| musl-libc | Debian 13 (musl-tools) | Static libc for the production binary |
| Debian 13 (Trixie) | — | Base for all containers |

To check for updates: `workshop/scripts/check-versions.sh`
To update: `workshop/scripts/update-versions.sh`

---

## Further reading

- [workshop/docs/TEMPLATE-USAGE.md](workshop/docs/TEMPLATE-USAGE.md) — How to start a new project from this template
- [workshop/docs/DEV-WORKFLOW.md](workshop/docs/DEV-WORKFLOW.md) — Development, staging, and forensics procedures
- [workshop/docs/CONTRIBUTING.md](workshop/docs/CONTRIBUTING.md) — How to contribute to the template itself
- [workshop/health/README.md](workshop/health/README.md) — Health check contract

---

## License

MIT
