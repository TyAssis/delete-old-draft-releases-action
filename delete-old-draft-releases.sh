#!/usr/bin/env bash
set -euo pipefail

while getopts "r:t:d:" opt; do
  case $opt in
    r) repo="$OPTARG" ;;
    t) token="$OPTARG" ;;
    d) older_than="$OPTARG" ;;
    \?) echo "Invalid option -$OPTARG" >&2 ; exit 1 ;;
  esac
done

repo_api="https://api.github.com/repos/$repo"
auth_header="authorization: Bearer $token"

function sort_age_desc { jq 'sort_by(.id) | reverse'; }

function split_releases { jq -c '.[] | {id, name, draft,created_at}'; }

function delete_old_drafts {
  start_deleting=false
  while read -r release; do
    id=$(jq '.id' <<< "$release")
    name=$(jq '.name' <<< "$release")
    draft=$(jq '.draft' <<< "$release")
    created_at=$(jq '.created_at' <<< "$release" | xargs -I{} date --date="{}" +"%s")
    echo $name
    echo $draft

    today=$(date)
    expiring_date=$(date --date="today $older_than days ago" +%s)

    echo "$(date --date=@${created_at})"
    echo "$(date --date=@${expiring_date})"
    if [[ "$created_at" -le "$expiring_date" && "$draft" = true ]]; then
      echo "Deleting draft release $id ($name)"
    fi
  done
}

curl -# -H "$auth_header" "$repo_api/releases?per_page=100" \
  | sort_age_desc | split_releases | delete_old_drafts
