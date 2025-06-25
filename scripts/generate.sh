#!/usr/bin/env bash
set -euo pipefail

# Functions
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }

fetch_github_data() {
  local url=$1
  curl -s "${GITHUB_API_URL:-https://api.github.com}${url}"
}

create_badge() {
  local label=$1 message=$2 color=$3 file=$4
  if [[ -z "$message" ]]; then
    log "  • Skipping ${file}.svg (no valid data)"
    return 0
  fi
  curl -s "https://img.shields.io/static/v1?label=${label}&message=${message}&color=${color}&style=flat" > "docs/${file}.svg"
  log "  • ${file}.svg created"
}

# Parse colors
IFS=',' read -r COL1 COL2 COL3 COL4 <<< "${COLORS}"

# Fetch contributor stats
log "Fetching contributor stats for ${REPO}..."
CONTRIBUTOR_DATA=$(fetch_github_data "/repos/${REPO}/stats/contributors")
if [[ -n "$CONTRIBUTOR_DATA" ]]; then
  TOTAL=$(jq length <<< "$CONTRIBUTOR_DATA")
  INDEX=$(jq -r '.[].author.login' <<< "$CONTRIBUTOR_DATA" | grep -n "^${USER}$" | cut -d: -f1 || true)
  INDEX=$((INDEX - 1))
  COMMITS=$(jq ".[$INDEX].total" <<< "$CONTRIBUTOR_DATA")
  RANK=$((TOTAL - INDEX))
fi

# Fetch open PR count
log "Fetching open pull requests for ${USER}..."
PRS_DATA=$(fetch_github_data "/search/issues?q=repo:${REPO}+is:pr+is:open+draft:false+author:${USER}")
if [[ -n "$PRS_DATA" ]]; then
  OPEN_PRS=$(jq '.total_count' <<< "$PRS_DATA")
fi

# Fetch latest commit info
log "Fetching latest commit for ${USER}..."
COMMITS_DATA=$(fetch_github_data "/repos/${REPO}/commits?author=${USER}&per_page=1")
if [[ -n "$COMMITS_DATA" ]]; then
  LAST_COMMIT=$(echo "$COMMITS_DATA" | jq '.[0]')
  TIMESTAMP=$(jq -r '.commit.committer.date' <<< "$LAST_COMMIT")
  RAW_MSG=$(jq -r '.commit.message'  <<< "$LAST_COMMIT" | head -n1 | sed 's/"/\\"/g')
  LAST_SHA=$(jq -r '.sha' <<< "$LAST_COMMIT")

  UNIX_TS=$(date -d "$TIMESTAMP" +%s)
  REL_TIME=$(curl -s "https://img.shields.io/date/${UNIX_TS}.json" | jq -r '.value')
  MSG=$(echo "$RAW_MSG" | sed 's/([^)]*)//g' | xargs)
  COMBINED_ESC=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "${REL_TIME} | ${MSG}")
fi

# Prepare badges
log "Generating badges..."
mkdir -p docs

create_badge "contributor" "%23${RANK}" "$COL1" "contributor"
create_badge "commits" "${COMMITS}" "$COL2" "commits"
create_badge "open%20pull%20requests" "${OPEN_PRS}" "$COL3" "open-pull-requests"
create_badge "last%20commit" "${COMBINED_ESC}" "$COL4" "last-commit"

# Create latest commit redirect
cat > docs/latest-commit.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Latest commit for ${USER}</title>
  <meta http-equiv="refresh" content="0;url=https://github.com/${REPO}/commit/${LAST_SHA}">
  <link rel="canonical" href="https://github.com/${REPO}/commit/${LAST_SHA}">
</head>
<body>
  <p>Redirecting to the latest commit… <a href="https://github.com/${REPO}/commit/${LAST_SHA}">click here</a>.</p>
</body>
</html>
EOF

touch docs/.nojekyll

# Git config and push
log "Committing and pushing changes..."
git config --global user.email "actions@github.com"
git config --global user.name "GitHub Action"
git add docs/

if git diff --cached --quiet; then
  log "No changes to commit"
  exit 0
fi

COMMIT_MESSAGE="Update badges"
[[ "${GITHUB_EVENT_NAME:-}" == "schedule" ]] && COMMIT_MESSAGE+=" ($(date +'%Y-%m-%d %H:00'))"

git commit -m "${COMMIT_MESSAGE}"
git push
