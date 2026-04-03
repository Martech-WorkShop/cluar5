# Making Your Repository Private

By default cluar5 works with public repositories — no credentials, no configuration.
This guide covers the additional steps required to use a private repository.

---

## Why extra steps are needed

The dev container (your daily workspace) uses VS Code's GitHub authentication — no extra work there.

The stage, prod, and debug containers are different: Docker builds them by cloning your repository from scratch, without any VS Code session. For a private repo, Docker needs a token to authenticate that clone.

---

## Step 1 — Create a GitHub Personal Access Token

1. Go to **github.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens**
2. Click **"Generate new token"**
3. Set a token name (e.g. `cluar5-docker-build`)
4. Set expiration — tokens expire 1 year from creation, regardless of use. Note the date. When it expires, `make stage`, `make prod`, and `make debug` will fail with an auth error — rotate the token before that happens by repeating this step and updating your shell profile.
5. Under **Repository access**, select your repository
6. Under **Permissions → Contents**, select **Read-only**
7. Click **"Generate token"** and copy the token immediately — GitHub will not show it again

---

## Step 2 — Add the token to your shell profile

On your **host machine** (not inside the container):

```bash
# ~/.bashrc or ~/.zshrc
export GITHUB_TOKEN=ghp_xxxx
```

Then reload your shell:

```bash
source ~/.bashrc   # or ~/.zshrc
```

This is a one-time step. The token is picked up automatically from here on.

---

## Step 3 — Sign into GitHub in VS Code

1. Open VS Code
2. Click the **Accounts** icon in the bottom-left corner
3. Click **Sign in with GitHub**
4. Complete the login flow in your browser

---

## Step 4 — Make your repo private

**Starting from the cluar5 template:** follow [GETTING-STARTED.md](GETTING-STARTED.md) normally — in Step 1.3 select **Private** instead of Public.

**Converting an existing cluar5 repo:** on GitHub go to your repository → **Settings** → scroll to **Danger Zone** → **"Change repository visibility"** → **"Change to private"** → confirm.

---

## Token expiration

When your token expires:

1. Go back to **github.com → Settings → Developer settings → Personal access tokens**
2. Generate a new token (same settings as Step 1 above)
3. Update your shell profile with the new value
4. Reload your shell: `source ~/.bashrc`

`make stage / prod / debug` will work again immediately.
