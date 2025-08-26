#!/usr/bin/env bash
set -e
USER=$(gh api user -q .login)
NAME="$1"
[ -z "$NAME" ] && { echo "kullanım: scripts/new-repo.sh <ad>"; exit 1; }
# 1) template'ten oluştur
gh repo create "$NAME" --public --template "$USER/repo-template"
# 2) yerel klon ve iskelet
git clone "git@github.com:$USER/$NAME.git" "$HOME/repos/$NAME"
cd "$HOME/repos/$NAME"
mkdir -p src scripts docs tests .github/workflows
[ -f README.md ] || echo "# $NAME" > README.md
# 3) CI
[ -f .github/workflows/ci.yml ] || cat > .github/workflows/ci.yml <<'YML'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
      - run: python -V
YML
# 4) .env.example
[ -f .env.example ] || cat > .env.example <<'ENV'
OPENAI_API_KEY=
SENTRY_DSN=
PYPI_API_TOKEN=
NPM_TOKEN=
DOCKERHUB_USERNAME=
DOCKERHUB_PASSWORD=
ANDROID_KEYSTORE_BASE64=
ANDROID_KEY_ALIAS=
ANDROID_KEY_PASSWORD=
ANDROID_STORE_PASSWORD=
ENV
git add . && (git diff --cached --quiet || git commit -m "chore: iskelet + CI + env example")
git push -u origin main
# 5) etiketler ve koruma
for L in bug enhancement documentation performance security chore refactor test; do
  gh label create "$L" -c "ededed" -d "$L" --repo "$USER/$NAME" --force >/dev/null 2>&1 || true
done
gh
cd ~/repos/studio
cat > scripts/new-repo.sh <<'SH'
#!/usr/bin/env bash
set -e
USER=$(gh api user -q .login)
NAME="$1"
[ -z "$NAME" ] && { echo "kullanım: scripts/new-repo.sh <ad>"; exit 1; }

# 1) template'ten oluştur
gh repo create "$NAME" --public --template "$USER/repo-template"

# 2) yerel klon ve iskelet
git clone "git@github.com:$USER/$NAME.git" "$HOME/repos/$NAME"
cd "$HOME/repos/$NAME"
mkdir -p src scripts docs tests .github/workflows
[ -f README.md ] || echo "# $NAME" > README.md

# 3) CI
[ -f .github/workflows/ci.yml ] || cat > .github/workflows/ci.yml <<'YML'
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.x'
      - run: python -V
YML

# 4) .env.example
[ -f .env.example ] || cat > .env.example <<'ENV'
OPENAI_API_KEY=
SENTRY_DSN=
PYPI_API_TOKEN=
NPM_TOKEN=
DOCKERHUB_USERNAME=
DOCKERHUB_PASSWORD=
ANDROID_KEYSTORE_BASE64=
ANDROID_KEY_ALIAS=
ANDROID_KEY_PASSWORD=
ANDROID_STORE_PASSWORD=
ENV

git add . && (git diff --cached --quiet || git commit -m "chore: iskelet + CI + env example")
git push -u origin main

# 5) etiketler ve koruma
for L in bug enhancement documentation performance security chore refactor test; do
  gh label create "$L" -c "ededed" -d "$L" --repo "$USER/$NAME" --force >/dev/null 2>&1 || true
done

gh api -X PUT "repos/$USER/$NAME/branches/main/protection" \
  -H "Accept: application/vnd.github+json" --input - <<'JSON'
{"required_status_checks":null,"enforce_admins":true,"required_pull_request_reviews":{"required_approving_review_count":1},"restrictions":null,"required_linear_history":true,"allow_force_pushes":false,"allow_deletions":false}
JSON

for ENV in dev staging prod; do
  gh api -X PUT "repos/$USER/$NAME/environments/$ENV" >/dev/null 2>&1 || true
done

echo "Hazır: $NAME"
