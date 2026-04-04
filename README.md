# cluar5: Free the full potential of LLM coders. 

The first paradigm where LLM capabilities, preferences, advantages, and caveats are the main consideration for every decision.

LLMs have finally claimed ownership of the coding skill, yet we still force them to code in our preferred languages, using our beloved frameworks and the existing libraries we are comfortable with.

You concentrate on the architecture, the intent, the outcomes, and the taste.
Our job as software engineers has switched from producers of code to designers of outcomes and experiences. Give the LLMs greater freedom, exploit more of their potential and focus in the quality.


# A stack designed around LLM coders.

cluar5 is designed to minimize the surface for mistakes, hallucinations and avoids most of the language traps of popular languages by focusing in the languages LLMs work best with.

**C + Lua + R5** — An LLM-first environment where LLMs can roam freely with minimal supervision, where domain experts can architect and trust the output (for the most part :-), and where software engineers can interact with the first layer of code easily and make adjustments without effort.

**cluar5 is not just a poliglot asembly, it's 3 different views of the world, running in parallel, sharing everything in RAM.**


## The philosophy:

SotA LLMs write great code. Give them a surface where they can both feel safe and express themselves more freely and whatch them reward you with their best output.

cluar5 provides this surface with three carefuly selected layers, each with a distinct relationship between the LLM, the code, and the human architect:
The languages are not chosen because they are popular, smart, unique or special, they are chosen because they are minimal, especially minimal from the perspective of an LLM.

## The stack:


**The Lua layer**
is where fast prototypes can be created effortlesly. Its simplicity is its strongest benefit, engineers can read a Lua file and understand what it does immediately.
LLMs can write Lua code easely because it lacks the complexity of most fully fledged languages. Yet is is tourin complete and fully capable of full size complex apps.

Prototypes are born here. For many projects, this layer alone is sufficient to ship a complete, working product. The LLM writes it, the human reads it, and the conversation between them happens naturally at this surface.

There is no better spec than a working app. Once the code is functional, it is up to you, the architect and director to choose any parts that mighr benefit from greater expresiveness, require additional complexity or simply require maximum poerformance, those parts can then be migrated to the R5 layer or the C layer accordingly.

**The R5 layer**
Gambit Scheme is where the LLM roams freely. R5RS carries the smallest surface area of any serious language ever created, yet it contains more expressive power than any other language, all within an LLM-ultra-safe-universe. The purity from the lack of I/O and the "S-expresiveness" means the LLM makes intentional choices — there are no accidental idioms, no ambiguous constructs, almost no surface for hallucination.

** Gambit Scheme's *REPL MAGIC* **
All languages have a REPL... right? Yes, but not really...
The Lisp REPL is a direct window into the live runtime, allowing programmers and LLMs to redefine functions, classes, and variables on the fly while the program is running. You can modify the program as it runs and see what happens as it happens, a fully interactive, incremental Read-Eval-Print Loop (REPL) that is fundamentally built around "homoiconicity", where code is treated as data, allowing for live, in-memory modification of a running program.
This isn't a development tool. This is the runtime itself becoming the interface.
The LLM is not writing code and submitting it for review. The LLM is inside the process. It modifies a function — the modification is live, instantly, the program never stopped. It observes the effect. It modifies again. It is having a conversation with a running system, in real time, in the language of that system.

This is what Lisp was designed for. NASA used it on the Deep Space 1 probe, they patched a bug in a spacecraft that was 100 million miles away, on a live running system, via exactly this mechanism. The program never stopped. The fix went in while the mission was in progress...
cluar5 brings this to LLM-native development (experimental).


The LLM is not writing code and submitting it for review. The LLM is inside the process. It modifies a function — the modification is live, instantly, the program never stopped. It observes the effect. It modifies again. It is having a conversation with a running system, in real time, in the language of that system.

This is what Lisp was designed for. NASA used it on the Deep Space 1 probe — they patched a bug in a spacecraft that was 100 million miles away, on a live running system, via exactly this mechanism. The program never stopped. The fix went in while the mission was in progress.

cluar5 brings this to LLM-native development (Experimental).


**The C layer**
The binding agent that puuls everything together. It owns the main loop, memory, I/O, signals, and all things requiring determinism and raw performance. It acts as the escape hatch when Lua hits a rough edge and as the bridge that Scheme requires to talk to the real world (Gambit has no I/O by design). Most importantly: it ties the three layers in one single process, sharing memory directly, communicating at RAM speed with zero interoperability cost.

The development arc is natural: prototype in Lua, move complexity to Scheme, bind performance-critical paths in C. The LLM drives all three transitions. The human steers.


---

## PERFORMANCE!!!

While not the main objective, at cluar5, we're suckers for minimalism and performance, that's why we are so happy that these tools are both the best fit for LLMs and also the most performant, each in their category.

Lua is the most performant interpreted language with Luajit taking it close to C performance in specific aplications. R5 Scheme is about the purest lisp there is, highly functional, incredibly expressive and capable language, an LLM can gracefully express anything with it. And C is the king of so many things it could take pages... so let's just state the obvious: it's the king of raw performance, the absolute master of raw I/O speed and the owner of the vastest collection of both old and cutting edge low level libraries.

---

## Four containers + builder 

| Container | Purpose | Binary | Shell | User |
|---|---|---|---|---|
| `dev` | Daily development — Lua and Scheme interpreted, C compiled | gcc debug build | yes | appuser |
| `stage` | Pre-production — identical binary to prod, test tools available | musl static | yes | appuser |
| `prod` | Production — scratch image, single binary, nothing else | musl static, stripped | **no** | appuser |
| `debug` | Post-incident forensics — extract from prod, analyze here | musl static, unstripped | yes | root |

Production runs in a `scratch` container: no OS, no shell, no compilers, no attack surface. A single statically linked binary is the entire runtime. If it crashes, you extract the core dump and analyze it in the debug container. Production itself is never opened.

---

## It's a template!
Directory structure:

```
/
├── c/                    ← C source (core engine, main loop)
├── lua/                  ← LuaJIT source (scripting layer — primary human surface)
├── r5/                   ← Gambit Scheme source (logic layer — LLM's domain)
├── .devcontainer/        ← VS Code Dev Containers configuration
├── workshop/
│   ├── docker/           ← All five Dockerfiles + docker-compose stub
│   ├── scripts/          ← templateInit.sh, check-versions.sh, update-versions.sh
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

## CAVEATS:

You tell me, I can't find any...

---

## License

MIT
