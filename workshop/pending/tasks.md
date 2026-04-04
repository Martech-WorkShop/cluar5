# Pending Tasks

## templateInit.sh — read project details from git remote instead of prompting

`PROJECT_NAME` and `GITHUB_USER` are already known from the git remote URL at the time
`templateInit.sh` runs. Instead of prompting the user for values they already gave GitHub,
parse them directly:

```bash
git remote get-url origin
# https://github.com/theiruser/theirproject.git  (HTTPS)
# git@github.com:theiruser/theirproject.git       (SSH)
```

Both formats need to be handled. Result: zero prompts, fully automatic initialization.

---

## templateInit.sh — DOCKERHUB_USER never set for new projects

`PROJECT.conf` contains `DOCKERHUB_USER=aivcx` (the template owner's Docker Hub account).
`templateInit.sh` never asks for or updates this value. New projects cloned from the template
will have `aivcx` as their Docker Hub user.

- Users who try to push images will get an auth error (they don't have credentials for `aivcx`)
- Their account is safe — no accidental publishing to the template owner's account

Options:
1. Ask for `DOCKERHUB_USER` during init (only field that can't be derived from the git remote)
2. Leave it blank in `PROJECT.conf` and let the user fill it in manually
3. Default it to `GITHUB_USER` (often the same) and let the user correct it if needed
