set -euo pipefail

notify() {
	local body="${2:-}"
	local sound="${3:-none}"

	herdr notification show "$1" --body "$body" --sound "$sound" >/dev/null 2>&1 || true
}

current_json="$(herdr pane current 2>/dev/null || true)"
cwd="$(jq -r '.result.pane.foreground_cwd // .result.pane.cwd // empty' <<<"$current_json")"

if [[ -z "$cwd" ]]; then
	notify "PR workspaces" "Herdr could not find the current directory." request
	exit 1
fi

if ! repo_root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"; then
	notify "PR workspaces" "The current directory is not in a Git repository." request
	exit 1
fi

common_dir="$(git -C "$repo_root" rev-parse --git-common-dir)"
if [[ "$common_dir" != /* ]]; then
	common_dir="$repo_root/$common_dir"
fi
repo_key="$(printf '%s' "$common_dir" | sha256sum | cut -c1-16)"
runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
lock_file="$runtime_dir/herdr-pr-workspaces-$repo_key.lock"

exec 9>"$lock_file"
if ! flock -n 9; then
	notify "PR workspaces" "This repository is already being processed."
	exit 0
fi

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
mkdir -p "$state_dir"
log_file="$state_dir/pr-workspaces.log"
printf '\n[%s] Repository: %s\n' "$(date --iso-8601=seconds)" "$repo_root" >>"$log_file"

remote=""
if git -C "$repo_root" remote get-url origin >/dev/null 2>&1; then
	remote="origin"
else
	remote="$(git -C "$repo_root" remote | head -n 1)"
fi

if [[ -n "$remote" ]] && ! git -C "$repo_root" fetch --prune "$remote" >>"$log_file" 2>&1; then
	notify "PR workspaces" "Git fetch failed. See $log_file." request
	exit 1
fi

if ! pr_json="$(cd "$repo_root" && gh pr list --state open --limit 1000 --json number,url 2>>"$log_file")"; then
	notify "PR workspaces" "GitHub PR lookup failed. See $log_file." request
	exit 1
fi

if ! jq -e 'type == "array"' >/dev/null <<<"$pr_json"; then
	notify "PR workspaces" "GitHub returned invalid PR data. See $log_file." request
	exit 1
fi

pr_count="$(jq 'length' <<<"$pr_json")"
if [[ "$pr_count" -eq 0 ]]; then
	notify "PR workspaces" "This repository has no open pull requests." "done"
	exit 0
fi

notify "PR workspaces" "Preparing $pr_count open pull requests."

initial_worktrees="$(herdr worktree list --cwd "$repo_root" 2>>"$log_file" || true)"
source_workspace_id="$(jq -r '.result.source.source_workspace_id // empty' <<<"$initial_worktrees" 2>/dev/null || true)"

find_open_workspace() {
	local worktree_path="$1"
	local worktrees_json

	worktrees_json="$(herdr worktree list --cwd "$repo_root" 2>>"$log_file" || true)"
	jq -r --arg path "$worktree_path" '
    .result.worktrees
    | map(select(.path == $path and .open_workspace_id != null))
    | .[0].open_workspace_id // empty
  ' <<<"$worktrees_json" 2>/dev/null || true
}

first_workspace_id=""
opened_count=0
created_count=0
reused_count=0
failed_count=0

while IFS=$'\t' read -r number url; do
	printf '[%s] PR #%s: %s\n' "$(date --iso-8601=seconds)" "$number" "$url" >>"$log_file"

	if ! wt_json="$(wt -C "$repo_root" -y switch "$url" --no-cd --format=json 2>>"$log_file")"; then
		printf 'PR #%s: worktrunk failed.\n' "$number" >>"$log_file"
		failed_count=$((failed_count + 1))
		continue
	fi

	worktree_path="$(jq -r '.path // empty' <<<"$wt_json" 2>/dev/null || true)"
	if [[ -z "$worktree_path" ]]; then
		printf 'PR #%s: worktrunk returned no path.\n' "$number" >>"$log_file"
		failed_count=$((failed_count + 1))
		continue
	fi

	workspace_id="$(find_open_workspace "$worktree_path")"
	created=false
	open_json=""

	if [[ -n "$workspace_id" ]]; then
		reused_count=$((reused_count + 1))
	else
		if [[ -n "$source_workspace_id" ]]; then
			open_json="$(
				herdr worktree open \
					--workspace "$source_workspace_id" \
					--path "$worktree_path" \
					--label "#$number" \
					--no-focus 2>>"$log_file" || true
			)"
		fi

		workspace_id="$(jq -r '.result.workspace.workspace_id // empty' <<<"$open_json" 2>/dev/null || true)"
		if [[ -n "$workspace_id" ]]; then
			if [[ "$(jq -r '.result.already_open // false' <<<"$open_json")" == "true" ]]; then
				reused_count=$((reused_count + 1))
			else
				created=true
			fi
		else
			open_json="$(
				herdr workspace create \
					--cwd "$worktree_path" \
					--label "#$number" \
					--no-focus 2>>"$log_file" || true
			)"
			workspace_id="$(jq -r '.result.workspace.workspace_id // empty' <<<"$open_json" 2>/dev/null || true)"
			created=true
		fi
	fi

	if [[ -z "$workspace_id" ]]; then
		printf 'PR #%s: Herdr could not open a workspace.\n' "$number" >>"$log_file"
		failed_count=$((failed_count + 1))
		continue
	fi

	if [[ "$created" == true ]]; then
		tab_id="$(jq -r '.result.tab.tab_id // empty' <<<"$open_json")"
		pane_id="$(jq -r '.result.root_pane.pane_id // empty' <<<"$open_json")"
		setup_failed=false

		if [[ -z "$tab_id" || -z "$pane_id" ]]; then
			setup_failed=true
		else
			herdr tab rename "$tab_id" pi >>"$log_file" 2>&1 || setup_failed=true
			herdr pane run "$pane_id" pi >>"$log_file" 2>&1 || setup_failed=true

			lazygit_json="$(
				herdr tab create \
					--workspace "$workspace_id" \
					--cwd "$worktree_path" \
					--label lazygit \
					--no-focus 2>>"$log_file" || true
			)"
			lazygit_pane_id="$(jq -r '.result.root_pane.pane_id // empty' <<<"$lazygit_json" 2>/dev/null || true)"
			if [[ -n "$lazygit_pane_id" ]]; then
				herdr pane run "$lazygit_pane_id" lazygit >>"$log_file" 2>&1 || setup_failed=true
			else
				setup_failed=true
			fi
		fi

		created_count=$((created_count + 1))
		if [[ "$setup_failed" == true ]]; then
			printf 'PR #%s: workspace opened, but tab setup failed.\n' "$number" >>"$log_file"
			failed_count=$((failed_count + 1))
		fi
	fi

	if [[ -z "$first_workspace_id" ]]; then
		first_workspace_id="$workspace_id"
	fi
	opened_count=$((opened_count + 1))
done < <(jq -r 'sort_by(.number)[] | [.number, .url] | @tsv' <<<"$pr_json")

if [[ -n "$first_workspace_id" ]]; then
	herdr workspace focus "$first_workspace_id" >>"$log_file" 2>&1 || failed_count=$((failed_count + 1))
fi

summary="$opened_count PR workspaces are ready ($created_count new, $reused_count reused)."
if [[ "$failed_count" -gt 0 ]]; then
	notify "PR workspaces" "$summary $failed_count operations failed. See $log_file." request
	exit 1
fi

notify "PR workspaces" "$summary" "done"
