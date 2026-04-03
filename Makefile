# cluar5 Makefile
#
# Container targets (run on host):
#   make build-base   Build the shared musl builder image — run this first
#   make dev          Build the dev container image
#   make stage        Build the stage container image
#   make prod         Build the production container image
#   make debug        Build the debug container image
#
# Binary targets (run inside a container):
#   make dev-build    Compile debug binary with gcc/glibc (inside dev container)
#   make dev-run      C>ompile and run (inside dev container)
#   make prod-static  Compile stripped static binary (inside builder)
#   make stage-static Compile unstripped static binary (inside builder or stage)
#   make debug-static Compile debug-symbol static binary (inside builder)
#
# Utility:
#   make clean        Remove build/ output
#
# Private repository support:
#   Set GITHUB_TOKEN in your environment to clone from a private repo.
#   GITHUB_TOKEN=ghp_xxxx make stage
#   See workshop/docs/MAKING-YOUR-REPO-PRIVATE.md for setup instructions.

include PROJECT.conf
include VERSIONS

# Required for --mount=type=secret support in Dockerfiles.
export DOCKER_BUILDKIT := 1

# GNU Make does not allow literal commas inside function calls.
comma := ,

# Pass --secret only when GITHUB_TOKEN is set. Public repos: leave unset.
GITHUB_TOKEN  ?=
_SECRET_FLAG   = $(if $(GITHUB_TOKEN),--secret id=github_token$(comma)env=GITHUB_TOKEN,)

MUSL_PREFIX   ?= /opt/musl
LUA_IMPL      ?= luajit  # alternatives: lua54 (see workshop/docs/TEMPLATE-USAGE.md)
BUILD_DIR     := build

# Source files
C_SRCS        := c/main.c
R5_SRC    := r5/main.scm
R5_BUNDLE := r5/main_bundle.c
LUA_SRC       := lua/main.lua

# Common include/library paths for musl builds
MUSL_CFLAGS   := -I$(MUSL_PREFIX)/include
MUSL_LDFLAGS  := -L$(MUSL_PREFIX)/lib -lluajit-5.1 -lgambit -lm -ldl -lpthread

.PHONY: all build-base dev stage prod debug \
        dev-build dev-run prod-static stage-static debug-static clean

# ── Container image targets (host) ────────────────────────────────────────────

build-base:
	docker build \
		--build-arg LUAJIT_VERSION=$(LUAJIT_VERSION) \
		--build-arg GAMBIT_VERSION=$(GAMBIT_VERSION) \
		-f workshop/docker/Dockerfile.builder-base \
		-t $(PROJECT_NAME)-builder-base \
		.

dev:
	docker build \
		-f workshop/docker/Dockerfile.dev \
		-t $(PROJECT_NAME)-dev \
		.

stage: build-base
	docker build \
		$(_SECRET_FLAG) \
		--build-arg BASE_IMAGE=$(PROJECT_NAME)-builder-base \
		--build-arg REPO_URL=$(REPO_URL) \
		--build-arg REPO_BRANCH=$(REPO_BRANCH) \
		-f workshop/docker/Dockerfile.stage \
		-t $(PROJECT_NAME)-stage \
		.

prod: build-base
	docker build \
		$(_SECRET_FLAG) \
		--build-arg BASE_IMAGE=$(PROJECT_NAME)-builder-base \
		--build-arg REPO_URL=$(REPO_URL) \
		--build-arg REPO_BRANCH=$(REPO_BRANCH) \
		-f workshop/docker/Dockerfile.prod \
		-t $(PROJECT_NAME)-prod \
		.

debug: build-base
	docker build \
		$(_SECRET_FLAG) \
		--build-arg BASE_IMAGE=$(PROJECT_NAME)-builder-base \
		--build-arg REPO_URL=$(REPO_URL) \
		--build-arg REPO_BRANCH=$(REPO_BRANCH) \
		--build-arg GDB_VERSION=$(GDB_VERSION) \
		--build-arg VALGRIND_VERSION=$(VALGRIND_VERSION) \
		--build-arg STRACE_VERSION=$(STRACE_VERSION) \
		-f workshop/docker/Dockerfile.debug \
		-t $(PROJECT_NAME)-debug \
		.

# ── Binary targets (inside containers) ───────────────────────────────────────

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile Scheme to C (shared step for all static builds)
$(R5_BUNDLE): $(R5_SRC)
	gsc -link -o $(R5_BUNDLE) $(R5_SRC)

# Dev binary: gcc, glibc, debug flags, not stripped.
# Run inside the dev container.
dev-build: $(BUILD_DIR) $(R5_BUNDLE)
	gcc -g -O0 \
		-o $(BUILD_DIR)/$(PROJECT_NAME)-dev \
		$(C_SRCS) $(R5_BUNDLE) \
		-lluajit-5.1 -lgambit -lm -ldl -lpthread

dev-run: dev-build
	$(BUILD_DIR)/$(PROJECT_NAME)-dev

# Production binary: musl-gcc, fully static, optimized, stripped.
# Run inside the builder container (called by Dockerfile.prod).
prod-static: $(BUILD_DIR) $(R5_BUNDLE)
	musl-gcc -static -O2 -s \
		$(MUSL_CFLAGS) \
		-o $(BUILD_DIR)/$(PROJECT_NAME) \
		$(C_SRCS) $(R5_BUNDLE) \
		$(MUSL_LDFLAGS)

# Stage binary: musl-gcc, fully static, not stripped (readable stack traces).
# Run inside the builder container (called by Dockerfile.stage).
stage-static: $(BUILD_DIR) $(R5_BUNDLE)
	musl-gcc -static -O1 \
		$(MUSL_CFLAGS) \
		-o $(BUILD_DIR)/$(PROJECT_NAME) \
		$(C_SRCS) $(R5_BUNDLE) \
		$(MUSL_LDFLAGS)

# Debug binary: musl-gcc, fully static, debug symbols, no optimization.
# Run inside the builder container (called by Dockerfile.debug).
debug-static: $(BUILD_DIR) $(R5_BUNDLE)
	musl-gcc -static -g -O0 \
		$(MUSL_CFLAGS) \
		-o $(BUILD_DIR)/$(PROJECT_NAME) \
		$(C_SRCS) $(R5_BUNDLE) \
		$(MUSL_LDFLAGS)

# ── Utility ───────────────────────────────────────────────────────────────────

clean:
	rm -rf $(BUILD_DIR)
	rm -f $(R5_BUNDLE)
