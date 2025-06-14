#!/usr/bin/env bash
set -euo pipefail

# Parse colors
IFS=',' read -r COL1 COL2 COL3 COL4 <<< "${COLORS}"

# Fetch contributors
DATA=$(curl -s "${GITHUB_API_URL:-https://api.github.com}/repos/${REPO}/stats/contributors")
TOTAL=$(echo "$DATA" | jq length)
INDEX=$(echo "$DATA" | jq -r '.[].author.login' | grep -n "^${USER}$" | cut -d: -f1 || true)
if [[ -z "$INDEX" ]]; then
  COMMITS=0
  RANK="N/A"
else
  INDEX=$((INDEX-1))
  RANK=$((TOTAL - INDEX))
  COMMITS=$(echo "$DATA" | jq ".[$INDEX].total")
fi

OPEN_PRS=$(curl -s "${GITHUB_API_URL:-https://api.github.com}/search/issues?q=repo:${REPO}+is:pr+is:open+draft:false+author:${USER}" \
  | jq '.total_count')

TIMESTAMP=$(curl -s "${GITHUB_API_URL:-https://api.github.com}/repos/${REPO}/commits?author=${USER}&per_page=1" \
  | jq -r '.[0].commit.committer.date' )
UNIX_TS=$(date -d "$TIMESTAMP" +%s)
RAW_MSG=$(curl -s "${GITHUB_API_URL:-https://api.github.com}/repos/${REPO}/commits?author=${USER}&per_page=1" \
  | jq -r '.[0].commit.message' | head -n1 | sed 's/"/\\"/g')
MSG=$(echo "$RAW_MSG" | sed 's/([^)]*)//g' | xargs)
REL_TIME=$(curl -s "https://img.shields.io/date/${UNIX_TS}.json" | jq -r '.value')
COMBINED_ESC=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "${REL_TIME} | ${MSG}")
LAST_SHA=$(curl -s \
  "${GITHUB_API_URL:-https://api.github.com}/repos/${REPO}/commits?author=${USER}&per_page=1" \
  | jq -r '.[0].sha')

mkdir -p docs

curl -s "https://img.shields.io/static/v1?label=contributor&message=%23${RANK}&color=${COL1}&style=flat" \
  > docs/contributor.svg

curl -s "https://img.shields.io/static/v1?label=commits&message=${COMMITS}&color=${COL2}&style=flat" \
  > docs/commits.svg

curl -s "https://img.shields.io/static/v1?label=open%20pull%20requests&message=${OPEN_PRS}&color=${COL3}&style=flat" \
  > docs/open-pull-requests.svg

curl -s "https://img.shields.io/static/v1?label=last%20commit&message=${COMBINED_ESC}&color=${COL4}&style=flat" \
  > docs/last-commit.svg

cat > docs/latest-commit.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Latest commit for ${USER}</title>
  <meta http-equiv="refresh" content="0;url=https://github.com/${REPO}/commit/${LAST_SHA}">
  <!-- If meta-refresh is blocked, show a normal link -->
  <link rel="canonical" href="https://github.com/${REPO}/commit/${LAST_SHA}">
</head>
<body>
  <p>Redirecting to the latest commit… <a href="https://github.com/${REPO}/commit/${LAST_SHA}">click here</a>.</p>
</body>
</html>
EOF

touch docs/.nojekyll

git config --global user.email "actions@github.com"
git config --global user.name "GitHub Action"

git add docs/

if [[ "${GITHUB_EVENT_NAME}" == "schedule" ]]; then
  git commit -m "Update badges ($(date +'%Y-%m-%d %H:00'))" || echo "No changes"
else
  git commit -m "Update badges" || echo "No changes"
fi

git push
