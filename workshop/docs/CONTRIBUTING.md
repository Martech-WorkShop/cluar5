# Contributing to cluar5

cluar5 is a project template. Contributions should improve the template itself — the container model, build pipeline, tooling, and documentation — not implement application logic (that belongs in projects derived from the template).

---

## What belongs here

- Improvements to the four Dockerfiles (security, size, correctness)
- Makefile targets and build flag improvements
- `workshop/scripts/` tooling (rename, version management)
- Health check contract and reference implementation
- Documentation fixes and improvements
- `.devcontainer/` configuration improvements

## What does not belong here

- Application-specific C, Scheme, or Lua code
- New source language layers beyond C + Gambit + LuaJIT
- Features that only make sense for one derived project

---

## Development process

1. Fork the template using the "Use this template" button (do not fork directly — that preserves history)
2. Make your changes in your fork
3. Test all four containers build cleanly:
   ```bash
   make build-base
   make dev
   make stage
   make prod
   make debug
   ```
4. Verify the rename script works on a clean clone
5. Open a pull request against `AI-Vectoring/cluar5`

---

## Conventions

- Dockerfiles: keep security rationale in comments. Removing a security measure without explanation will be rejected.
- Makefile: targets that run inside a container must be documented with a comment indicating where they run (inside builder, inside stage, etc.)
- Scripts: `set -e` at the top, quote all variables, validate inputs before acting
- Documentation: one topic per file, no mixing of template usage with project architecture

---

## Reporting issues

Open an issue on [github.com/AI-Vectoring/cluar5](https://github.com/AI-Vectoring/cluar5/issues) with:
- Which container is affected (dev / stage / prod / debug / builder-base)
- Debian 13 version or Docker version if relevant
- Steps to reproduce
