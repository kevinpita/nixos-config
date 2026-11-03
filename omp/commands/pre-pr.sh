#!/usr/bin/env bash
# Shell steps of the /pre-pr command (pre-pr.md). Each subcommand keeps its
# state in the run folder, so the caller needs no shell variables between calls.
#
#   pre-pr.sh prepare current | pr <number|url> [base-branch] | branch <name> | commit <rev> | range <a>..<b>
#   pre-pr.sh clones <run> <name>...
#   pre-pr.sh guard <run>
#   pre-pr.sh cleanup <run>
set -euo pipefail

runs_root=${PRE_PR_RUNS:-/tmp/pre-pr}

die() {
	echo "pre-pr: $*" >&2
	exit 1
}

# Prints "key=value" for the caller and stores it in the run state.
emit() {
	printf '%s=%s\n' "$1" "$2" | tee -a "$run/state"
}

state() {
	sed -n "s/^$1=//p" "$run/state" | tail -n 1
}

load_run() {
	[ -n "${1:-}" ] || die "missing run folder"
	run=$(realpath -e -- "$1") || die "no run folder '$1'"
	[ "$(dirname -- "$run")" = "$runs_root" ] || die "refusing run folder '$1' outside $runs_root"
	[ -f "$run/state" ] || die "no state in '$run'"
	top=$(state top)
	cd "$top"
}

# Fetches one ref into FETCH_HEAD only: the empty refmap keeps remote-tracking
# refs unchanged, and no recursion keeps submodule refs unchanged.
fetch_rev() { # fetch_rev <remote> <ref>
	git fetch -q --no-tags --recurse-submodules=no --refmap= "$1" "$2" || die "cannot fetch '$2' from $1"
	git rev-parse FETCH_HEAD
}

default_base_ref() {
	local name
	name=$(git symbolic-ref -q --short refs/remotes/origin/HEAD) && name=${name#origin/}
	if [ -z "$name" ]; then
		for name in main master ""; do
			git rev-parse -q --verify "$name^{commit}" >/dev/null && break
			git rev-parse -q --verify "origin/$name^{commit}" >/dev/null && break
		done
	fi
	[ -n "$name" ] || die "cannot find the default branch"
	if git rev-parse -q --verify "origin/$name^{commit}" >/dev/null; then
		echo "origin/$name"
	else
		echo "$name"
	fi
}

# Commits the working tree as git would see it after "git add -A", without
# touching the real index: staged, unstaged, deleted, intent-to-add, untracked,
# force-added, sparse, and assume-unchanged or skip-worktree files that are present.
snapshot() {
	local dirty index="$run/snapshot.index" tag path real_index line nested=""
	# shellcheck disable=SC2016 # git submodule foreach expands this script.
	dirty=$(git submodule foreach --quiet --recursive 'test -z "$(git status --porcelain)" || echo "$displaypath"')
	[ -z "$dirty" ] || die "dirty submodules, commit or stash their changes first: $dirty"
	real_index=$(git rev-parse --git-path index)
	# -p keeps the index mtime, so git still rehashes racily clean entries.
	if [ -f "$real_index" ]; then cp -p -- "$real_index" "$index"; fi
	git ls-files -v -z | while IFS= read -r -d '' line; do
		tag=${line%% *} path=${line#* }
		if [[ $tag == [a-z] ]]; then
			GIT_INDEX_FILE=$index git update-index --no-assume-unchanged -- "$path"
		fi
		if [[ $tag == [Ss] ]] && { [ -e "$path" ] || [ -L "$path" ]; }; then
			GIT_INDEX_FILE=$index git update-index --no-skip-worktree -- "$path"
		fi
	done
	GIT_INDEX_FILE=$index git add -A --sparse || die "git add -A failed, so the working tree cannot be snapshotted"
	while IFS= read -r -d '' line; do
		[[ $line == 160000\ * ]] || continue
		path=${line#*$'\t'}
		git config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null | cut -d ' ' -f 2- | grep -Fxq -- "$path" || nested+=" $path"
	done < <(GIT_INDEX_FILE=$index git ls-files -s -z)
	[ -z "$nested" ] || die "nested repositories that are not submodules, the snapshot cannot include their files:$nested"
	local tree
	tree=$(GIT_INDEX_FILE=$index git write-tree)
	git -c user.name=pre-pr -c user.email=pre-pr@localhost commit-tree "$tree" -p HEAD -m pre-pr-snapshot
}

cmd_prepare() {
	local kind=${1:-current} top repo base head note=""
	top=$(git rev-parse --show-toplevel) || die "not in a git repository"
	cd "$top"
	[ "$(git rev-parse --is-shallow-repository)" = false ] || die "shallow repository, run 'git fetch --unshallow' first"
	repo=$(basename -- "$top")
	mkdir -p "$runs_root"
	run=$(mktemp -d "$runs_root/${repo//[^A-Za-z0-9._-]/_}.XXXXXX")
	: >"$run/state"
	trap 'rm -rf -- "$run"' EXIT
	case $kind in
	current)
		base=$(git merge-base "$(default_base_ref)" HEAD)
		head=$(snapshot)
		if [ "$(git rev-parse HEAD)" = "$(git rev-parse "$(default_base_ref)")" ]; then
			note="HEAD is at the base ref: the scope is the working tree only"
		fi
		;;
	pr)
		local number=${2:-} base_branch=${3:-} remote=origin repo_path="" r url
		if [[ $number =~ ://[^/]+/([^/]+/[^/]+)/pull/([0-9]+) ]]; then
			repo_path=${BASH_REMATCH[1]} number=${BASH_REMATCH[2]}
		fi
		number=${number#\#}
		[[ $number =~ ^[0-9]+$ ]] || die "usage: prepare pr <number|url> [base-branch]"
		[ -n "$base_branch" ] || base_branch=$(gh pr view "$2" --json baseRefName -q .baseRefName) || die "cannot read the base branch of PR $2"
		if [ -n "$repo_path" ]; then
			# PR numbers belong to one repository: use the remote that the URL names.
			remote=""
			for r in $(git remote); do
				url=$(git remote get-url "$r") url=${url%.git} url=${url%/}
				if [[ $url == *[/:]"$repo_path" ]]; then remote=$r && break; fi
			done
			[ -n "$remote" ] || die "no remote points to $repo_path"
		elif git remote get-url upstream >/dev/null 2>&1; then
			# In a fork checkout a bare PR number belongs to the upstream repository.
			remote=upstream
		fi
		head=$(fetch_rev "$remote" "pull/$number/head")
		base=$(git merge-base "$(fetch_rev "$remote" "$base_branch")" "$head")
		;;
	branch)
		[ -n "${2:-}" ] || die "usage: prepare branch <name>"
		head=$(git rev-parse -q --verify "refs/heads/$2^{commit}") || head=$(fetch_rev origin "$2")
		base=$(git merge-base "$(default_base_ref)" "$head")
		;;
	commit)
		head=$(git rev-parse --verify "${2:-}^{commit}") || die "usage: prepare commit <rev>"
		base=$(git rev-parse -q --verify "$head^1") || base=$(git hash-object -t tree /dev/null)
		;;
	range)
		local a=${2%%..*} b=${2##*..}
		[ -n "${2:-}" ] && [ "$a" != "$2" ] && [ -n "$a" ] && [ -n "$b" ] || die "usage: prepare range <a>..<b>"
		head=$(git rev-parse --verify "$b^{commit}")
		base=$(git merge-base "$a" "$head")
		;;
	*) die "unknown target '$kind'" ;;
	esac
	git --no-pager diff --no-ext-diff --no-textconv --no-color --binary "$base" "$head" >"$run/diff.patch"
	[ -s "$run/diff.patch" ] || die "no changes between $base and $head"
	trap - EXIT
	emit run "$run"
	emit top "$top"
	emit target "$*"
	emit base "$base"
	emit head "$head"
	emit diff "$run/diff.patch"
	emit size "$(git diff --shortstat "$base" "$head")"
	[ -z "$note" ] || emit note "$note"
	if git cat-file -e "$head:.gitmodules" 2>/dev/null; then
		emit note "submodules stay empty in the clones"
	fi
}

cmd_clones() {
	load_run "${1:-}"
	shift
	[ $# -gt 0 ] || die "usage: clones <run> <name>..."
	local name clone head
	head=$(state head)
	mkdir -p "$run/clones"
	for name in "$@"; do
		[[ $name =~ ^[A-Za-z0-9._-]+$ ]] || die "bad clone name '$name'"
		clone="$run/clones/$name"
		[ ! -e "$clone" ] || die "clone '$name' exists"
		git clone -q --shared --no-checkout -- "$top" "$clone"
		[ -f "$clone/.git/objects/info/alternates" ] || die "clone '$name' does not share objects"
		git -C "$clone" remote remove origin
		git -C "$clone" checkout -q --detach "$head"
		echo "clone=$clone"
	done
	fingerprint >"$run/before.guard"
}

# State of the main checkout: file bytes and modes, the index with its flags,
# HEAD and its branch, refs, every stash entry, and the repository config.
# Not covered: ignored files, intent-to-add flags, and submodule content.
fingerprint() {
	git symbolic-ref -q HEAD || echo detached
	git rev-parse HEAD
	git ls-files --stage -v
	git ls-files -f
	git for-each-ref --format='%(objectname) %(refname)'
	git reflog show --format=%H refs/stash -- 2>/dev/null || true
	git config --list --includes --show-scope | grep -E '^(local|worktree)\b' || true
	local files="$run/fingerprint.files"
	git ls-files -z --cached --others --exclude-standard | sort -zu >"$files"
	xargs -0 -r stat -c '%a %F %s %n' -- <"$files" 2>&1 || true
	# Symlink lines go to fd 3, the caller's stdout; file names go to sha1sum.
	{
		while IFS= read -r -d '' path; do
			if [ -L "$path" ]; then
				printf 'link %s -> %s\n' "$path" "$(readlink -- "$path")" >&3
			elif [ -f "$path" ] && [ -r "$path" ]; then
				printf '%s\0' "$path"
			fi
		done <"$files" | xargs -0 -r sha1sum --
	} 3>&1
}

cmd_guard() {
	load_run "${1:-}"
	[ -f "$run/before.guard" ] || die "no guard record, run 'clones' first"
	fingerprint >"$run/after.guard"
	if diff -- "$run/before.guard" "$run/after.guard"; then
		echo unchanged
	else
		exit 3
	fi
}

cmd_cleanup() {
	load_run "${1:-}"
	if [ -d "$run/clones" ]; then
		chmod -R u+rwX -- "$run/clones"
		rm -rf -- "$run/clones"
	fi
	echo "removed $run/clones"
}

sub=${1:-}
shift || true
case $sub in
prepare) cmd_prepare "$@" ;;
clones) cmd_clones "$@" ;;
guard) cmd_guard "$@" ;;
cleanup) cmd_cleanup "$@" ;;
*) die "usage: pre-pr.sh prepare|clones|guard|cleanup ..." ;;
esac
