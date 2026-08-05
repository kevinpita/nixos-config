set -euo pipefail

notify() {
	local body="${2:-}"
	local sound="${3:-none}"

	herdr notification show "$1" --body "$body" --sound "$sound" >/dev/null 2>&1 || true
}

find_open_workspace() {
	local repo_root="$1"
	local worktree_path="$2"
	local log_file="$3"
	local worktrees_json

	worktrees_json="$(herdr worktree list --cwd "$repo_root" 2>>"$log_file" || true)"
	jq -r --arg path "$worktree_path" '
    .result.worktrees
    | map(select(.path == $path and .open_workspace_id != null))
    | .[0].open_workspace_id // empty
  ' <<<"$worktrees_json" 2>/dev/null || true
}

write_worker_result() {
	local result_file="$1"
	local workspace_id="$2"
	local outcome="$3"
	local failure_count="$4"

	jq -n \
		--arg workspaceId "$workspace_id" \
		--arg outcome "$outcome" \
		--argjson failureCount "$failure_count" \
		'{
      workspaceId: $workspaceId,
      outcome: $outcome,
      failureCount: $failureCount
    }' >"$result_file"
}

load_pull_requests() {
	local repo_root="$1"
	local remote="$2"
	local result_file="$3"
	local log_file="$4"

	if [[ -n "$remote" ]] && ! git -C "$repo_root" fetch --prune "$remote" >>"$log_file" 2>&1; then
		return 1
	fi

	(
		cd "$repo_root"
		gh api \
			--paginate \
			--slurp \
			'repos/{owner}/{repo}/pulls?state=open&per_page=100' 2>>"$log_file" |
			jq '[
        .[][]
        | {
            number,
            title,
            url: .html_url,
            isDraft: (.draft // false)
          }
      ]' >"$result_file" 2>>"$log_file"
	)
}

open_pull_request() {
	local repo_root="$1"
	local source_workspace_id="$2"
	local number="$3"
	local url="$4"
	local log_file="$5"
	local result_file="$6"
	local worktree_path
	local workspace_id
	local outcome
	local open_json
	local wt_json
	local failure_count=0

	printf '[%s] PR #%s: %s\n' "$(date --iso-8601=seconds)" "$number" "$url" >>"$log_file"

	if ! wt_json="$(wt -C "$repo_root" -y switch "$url" --no-cd --format=json 2>>"$log_file")"; then
		printf 'PR #%s: worktrunk failed.\n' "$number" >>"$log_file"
		write_worker_result "$result_file" "" failed 1
		return 1
	fi

	worktree_path="$(jq -r '.path // empty' <<<"$wt_json" 2>/dev/null || true)"
	if [[ -z "$worktree_path" ]]; then
		printf 'PR #%s: worktrunk returned no path.\n' "$number" >>"$log_file"
		write_worker_result "$result_file" "" failed 1
		return 1
	fi

	workspace_id="$(find_open_workspace "$repo_root" "$worktree_path" "$log_file")"
	open_json=""

	if [[ -n "$workspace_id" ]]; then
		outcome="reused"
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
				outcome="reused"
			else
				outcome="created"
			fi
		else
			open_json="$(
				herdr workspace create \
					--cwd "$worktree_path" \
					--label "#$number" \
					--no-focus 2>>"$log_file" || true
			)"
			workspace_id="$(jq -r '.result.workspace.workspace_id // empty' <<<"$open_json" 2>/dev/null || true)"
			outcome="created"
		fi
	fi

	if [[ -z "$workspace_id" ]]; then
		printf 'PR #%s: Herdr could not open a workspace.\n' "$number" >>"$log_file"
		write_worker_result "$result_file" "" failed 1
		return 1
	fi

	if [[ "$outcome" == "created" ]]; then
		local tab_id
		local pane_id
		local lazygit_json
		local lazygit_pane_id

		tab_id="$(jq -r '.result.tab.tab_id // empty' <<<"$open_json")"
		pane_id="$(jq -r '.result.root_pane.pane_id // empty' <<<"$open_json")"

		if [[ -z "$tab_id" || -z "$pane_id" ]]; then
			failure_count=1
		else
			herdr tab rename "$tab_id" pi >>"$log_file" 2>&1 || failure_count=1
			herdr pane run "$pane_id" pi >>"$log_file" 2>&1 || failure_count=1

			lazygit_json="$(
				herdr tab create \
					--workspace "$workspace_id" \
					--cwd "$worktree_path" \
					--label lazygit \
					--no-focus 2>>"$log_file" || true
			)"
			lazygit_pane_id="$(jq -r '.result.root_pane.pane_id // empty' <<<"$lazygit_json" 2>/dev/null || true)"
			if [[ -n "$lazygit_pane_id" ]]; then
				herdr pane run "$lazygit_pane_id" lazygit >>"$log_file" 2>&1 || failure_count=1
			else
				failure_count=1
			fi
		fi

		if [[ "$failure_count" -gt 0 ]]; then
			printf 'PR #%s: workspace opened, but tab setup failed.\n' "$number" >>"$log_file"
		fi
	fi

	write_worker_result "$result_file" "$workspace_id" "$outcome" "$failure_count"
	[[ "$failure_count" -eq 0 ]]
}

case "${1:-}" in
--load-prs)
	[[ "$#" -eq 5 ]] || exit 2
	load_pull_requests "$2" "$3" "$4" "$5"
	exit
	;;
--open-pr)
	[[ "$#" -eq 7 ]] || exit 2
	open_pull_request "$2" "$3" "$4" "$5" "$6" "$7"
	exit
	;;
esac

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

pr_file="$(mktemp "$runtime_dir/herdr-pr-list.XXXXXX")"
worker_result_file="$(mktemp "$runtime_dir/herdr-pr-result.XXXXXX")"
trap 'rm -f "$pr_file" "$worker_result_file"' EXIT

load_status=0
gum spin \
	--spinner pulse \
	--title "Fetching Git data and loading open PRs..." \
	-- "$0" --load-prs "$repo_root" "$remote" "$pr_file" "$log_file" || load_status=$?

if [[ "$load_status" -eq 130 ]]; then
	exit 0
fi
if [[ "$load_status" -ne 0 ]]; then
	notify "PR workspaces" "Git fetch or GitHub PR lookup failed. See $log_file." request
	exit 1
fi

pr_json="$(<"$pr_file")"
if ! jq -e 'type == "array"' >/dev/null <<<"$pr_json"; then
	notify "PR workspaces" "GitHub returned invalid PR data. See $log_file." request
	exit 1
fi

pr_count="$(jq 'length' <<<"$pr_json")"
if [[ "$pr_count" -eq 0 ]]; then
	notify "PR workspaces" "This repository has no open pull requests." "done"
	exit 0
fi

if ! menu_choice="$(
	gum choose \
		--header "Open PR workspaces" \
		--height 8 \
		"All open PRs" \
		"Ready to review" \
		"Draft PRs" \
		"Start at a PR"
)"; then
	exit 0
fi

case "$menu_choice" in
"All open PRs")
	selected_prs="$(jq 'sort_by(.number)' <<<"$pr_json")"
	;;
"Ready to review")
	selected_prs="$(jq 'map(select(.isDraft == false)) | sort_by(.number)' <<<"$pr_json")"
	;;
"Draft PRs")
	selected_prs="$(jq 'map(select(.isDraft == true)) | sort_by(.number)' <<<"$pr_json")"
	;;
"Start at a PR")
	if ! selected_line="$(
		jq -r 'sort_by(.number)[] | "#\(.number)\t\(.title)"' <<<"$pr_json" |
			gum filter \
				--header "Select the first PR" \
				--placeholder "Type a PR number or title" \
				--height 15 \
				--limit 1 \
				--strict \
				--no-fuzzy-sort
	)"; then
		exit 0
	fi
	start_number="${selected_line%%$'\t'*}"
	start_number="${start_number#\#}"
	selected_prs="$(jq --argjson start "$start_number" 'sort_by(.number) | map(select(.number >= $start))' <<<"$pr_json")"
	;;
*)
	exit 0
	;;
esac

selected_count="$(jq 'length' <<<"$selected_prs")"
if [[ "$selected_count" -eq 0 ]]; then
	notify "PR workspaces" "The selected group has no open pull requests." "done"
	exit 0
fi

initial_worktrees="$(herdr worktree list --cwd "$repo_root" 2>>"$log_file" || true)"
source_workspace_id="$(jq -r '.result.source.source_workspace_id // empty' <<<"$initial_worktrees" 2>/dev/null || true)"

first_workspace_id=""
opened_count=0
created_count=0
reused_count=0
failed_count=0
current_count=0

while IFS=$'\t' read -r number url; do
	current_count=$((current_count + 1))
	: >"$worker_result_file"

	open_status=0
	gum spin \
		--spinner pulse \
		--title "Opening PR #$number ($current_count/$selected_count)..." \
		-- "$0" --open-pr \
		"$repo_root" \
		"$source_workspace_id" \
		"$number" \
		"$url" \
		"$log_file" \
		"$worker_result_file" || open_status=$?

	if [[ "$open_status" -eq 130 ]]; then
		notify "PR workspaces" "Stopped after $opened_count PR workspaces."
		exit 0
	fi

	if ! jq -e '
    type == "object"
    and (.workspaceId | type == "string")
    and (.outcome == "created" or .outcome == "reused" or .outcome == "failed")
    and (.failureCount | type == "number")
  ' >/dev/null 2>&1 <"$worker_result_file"; then
		failed_count=$((failed_count + 1))
		continue
	fi

	workspace_id="$(jq -r '.workspaceId' <"$worker_result_file")"
	outcome="$(jq -r '.outcome' <"$worker_result_file")"
	operation_failures="$(jq -r '.failureCount' <"$worker_result_file")"
	failed_count=$((failed_count + operation_failures))

	case "$outcome" in
	created)
		created_count=$((created_count + 1))
		;;
	reused)
		reused_count=$((reused_count + 1))
		;;
	esac

	if [[ -n "$workspace_id" ]]; then
		if [[ -z "$first_workspace_id" ]]; then
			first_workspace_id="$workspace_id"
		fi
		opened_count=$((opened_count + 1))
	fi
done < <(jq -r '.[] | [.number, .url] | @tsv' <<<"$selected_prs")

if [[ -n "$first_workspace_id" ]]; then
	herdr workspace focus "$first_workspace_id" >>"$log_file" 2>&1 || failed_count=$((failed_count + 1))
fi

summary="$opened_count PR workspaces are ready ($created_count new, $reused_count reused)."
if [[ "$failed_count" -gt 0 ]]; then
	notify "PR workspaces" "$summary $failed_count operations failed. See $log_file." request
	exit 1
fi

notify "PR workspaces" "$summary" "done"
