#!/usr/bin/env bash
# Tests pre-pr.sh against scratch repositories. Run: bash omp/commands/pre-pr.test.sh
set -euo pipefail
export LC_ALL=C GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
script=$(realpath -- "$(dirname -- "$0")/pre-pr.sh")
scratch=$(mktemp -d)
export PRE_PR_RUNS="$scratch/runs"
cleanup() {
	chmod -R u+rwX -- "$scratch" 2>/dev/null || true
	rm -rf -- "$scratch"
}
trap cleanup EXIT
failures=0

check() { # check <name> <expected> <actual>
	if [ "$2" = "$3" ]; then
		echo "ok   $1"
	else
		echo "FAIL $1: expected [$2], got [$3]"
		failures=$((failures + 1))
	fi
}

val() { sed -n "s/^$1=//p" <<<"$2" | head -n 1; }

# A repository with origin, on branch "feature", whose path contains a space.
new_repo() {
	local d="$scratch/$1 repo" o="$scratch/$1-origin.git"
	git init -q --bare -b main "$o"
	git init -q -b main "$d"
	(
		cd "$d"
		printf 'ign*\n' >.gitignore
		mkdir sub
		echo c >tracked
		echo d >deleted
		echo s >sub/staged
		echo a >assumed
		echo b >both
		echo w >sw
		ln -s tracked link
		git add -A
		git commit -qm init
		git remote add origin "$o"
		git push -q origin main
		git fetch -q origin
		git remote set-head origin main
		git switch -qc feature
		# A user diff.external must not reach diff.patch.
		git config diff.external 'echo not-a-patch'
	)
	echo "$d"
}

prepare() { # prepare <dir> <args...>
	(cd "$1" && shift && "$script" prepare "$@")
}

# --- snapshot of the current branch ---
d=$(new_repo snap)
(
	cd "$d"
	echo changed >tracked
	rm deleted
	echo new >ita && git add -N ita
	echo st >sub/staged && git add sub/staged
	echo u >untracked && echo u >sub/untracked
	echo f >ign-forced && git add -f ign-forced
	git update-index --assume-unchanged assumed && echo hidden >assumed
	git update-index --skip-worktree both && git update-index --assume-unchanged both && echo changed >both
	git update-index --skip-worktree sw && rm sw && ln -s missing sw
)
index_before=$(sha1sum <"$d/.git/index")
out=$(cd "$d/sub" && "$script" prepare current)
run=$(val run "$out")
head=$(val head "$out")
check "snapshot file list" ".gitignore assumed both ign-forced ita link sub/staged sub/untracked sw tracked untracked" "$(git -C "$d" ls-tree -r --name-only "$head" | tr '\n' ' ' | sed 's/ $//')"
check "snapshot keeps unstaged content" changed "$(git -C "$d" show "$head:tracked")"
check "snapshot keeps assume-unchanged content" hidden "$(git -C "$d" show "$head:assumed")"
check "real index unchanged" "$index_before" "$(sha1sum <"$d/.git/index")"
check "snapshot keeps a file with both index flags" changed "$(git -C "$d" show "$head:both")"
check "snapshot keeps a dangling symlink over a skip-worktree file" "120000 missing" "$(git -C "$d" ls-tree "$head" sw | cut -c1-6) $(git -C "$d" show "$head:sw")"
check "diff.patch is a git patch" "diff --git" "$(head -c 10 "$run/diff.patch")"

# --- clones and guard ---
"$script" clones "$run" opus-general gpt-general >/dev/null
c="$run/clones/opus-general"
check "clone has no remote" "" "$(git -C "$c" remote)"
check "clone is at head" "$head" "$(git -C "$c" rev-parse HEAD)"
check "push from clone fails" fail "$(git -C "$c" push -q origin HEAD:refs/heads/x 2>/dev/null && echo pushed || echo fail)"
(cd "$c" && echo x >>tracked && git stash -q && git branch evil && git config core.hooksPath /tmp/evil && git commit -q --allow-empty -m x)
check "git ops in clone leave guard unchanged" unchanged "$("$script" guard "$run")"

guard_after() { # guard_after <label> <command run in the main checkout> [setup command]
	local d r out
	d=$(new_repo "g$RANDOM")
	(cd "$d" && echo changed >tracked && echo 1 >>sub/staged && git stash -q && echo 2 >>sub/staged && git stash -q && echo changed >tracked && eval "${3:-:}")
	out=$(prepare "$d" current)
	r=$(val run "$out")
	"$script" clones "$r" a >/dev/null
	(cd "$d" && eval "$2")
	"$script" guard "$r" >/dev/null 2>&1 && status=0 || status=$?
	check "guard detects $1" 3 "$status"
}
guard_after "edit of a dirty file" 'echo evil >tracked'
guard_after "CRLF change" 'printf "changed\r\n" >tracked'
guard_after "edit of an assume-unchanged file" 'git update-index --assume-unchanged deleted && echo evil >deleted'
guard_after "chmod" 'chmod +x tracked'
guard_after "branch switch at the same commit" 'git switch -qc other'
guard_after "detached HEAD" 'git checkout -q --detach'
guard_after "drop of an older stash" 'git stash drop -q "stash@{1}"'
guard_after "index flag" 'git update-index --assume-unchanged tracked'
guard_after "local config" 'git config core.hooksPath /tmp/evil'
guard_after "commit" 'git commit -q --allow-empty -m evil'
guard_after "symlink retarget" 'ln -sfn deleted link'
guard_after "worktree config" 'git config --worktree x.y b' 'git config extensions.worktreeConfig true && git config --worktree x.y a'
guard_after "included config" 'git config -f .git/extra x.y b' 'git config -f .git/extra x.y a && git config include.path extra'
guard_after "fsmonitor-valid flag" 'git update-index --fsmonitor-valid tracked' 'git config core.fsmonitor true && git update-index --fsmonitor'

# --- failures stop loudly ---
d=$(new_repo fail)
(cd "$d" && git init -q nested && echo x >tracked)
check "unaddable file stops prepare" fail "$(cd "$d" && "$script" prepare current >/dev/null 2>&1 && echo ok || echo fail)"
check "failed prepare leaves no run folder" 0 "$(find "$PRE_PR_RUNS" -maxdepth 1 -name 'fail_repo.*' | wc -l)"

d=$(new_repo nest)
(cd "$d" && git init -q nested && git -C nested commit -q --allow-empty -m n && echo x >nested/code)
check "nested repository stops prepare" fail "$(cd "$d" && "$script" prepare current >/dev/null 2>&1 && echo ok || echo fail)"

d=$(new_repo sparse)
(cd "$d" && git sparse-checkout set --no-cone '/sub/' && echo modified >tracked)
out=$(prepare "$d" current)
check "snapshot keeps a present file outside the sparse checkout" modified "$(git -C "$d" show "$(val head "$out"):tracked")"

d=$(new_repo sm)
git init -q -b main "$scratch/lib" && git -C "$scratch/lib" commit -q --allow-empty -m l
(cd "$d" && git -c protocol.file.allow=always submodule add -q "$scratch/lib" lib && git commit -qm sub && echo x >lib/dirty)
check "dirty submodule stops prepare" "lib" "$(cd "$d" && "$script" prepare current 2>&1 >/dev/null | sed -n 's/.*first: //p')"

git clone -q --depth 1 "file://$scratch/snap-origin.git" "$scratch/shallow"
check "shallow repository stops prepare" fail "$(cd "$scratch/shallow" && "$script" prepare commit HEAD >/dev/null 2>&1 && echo ok || echo fail)"

# --- other targets ---
o="$scratch/t-origin.git"
d=$(new_repo t)
(
	cd "$d"
	git switch -q main
	git switch -qc release && echo r >r && git add r && git commit -qm rel && git push -q origin release
	git switch -qc topic && echo t >t && git add t && git commit -qm top && git push -q origin topic "topic:refs/pull/7/head"
	git switch -q main && git branch -qD release topic
	git update-ref -d refs/remotes/origin/release 2>/dev/null || true
	git update-ref -d refs/remotes/origin/topic 2>/dev/null || true
	echo m >m && git add m && git commit -qm main-moved
)
refs_before=$(git -C "$d" for-each-ref)
origin_url="https://example.com/$(basename -- "$scratch")/t-origin"
out=$(prepare "$d" pr "$origin_url/pull/7" release)
check "PR diff" "t" "$(git -C "$d" diff --name-only "$(val base "$out")" "$(val head "$out")")"
out=$(prepare "$d" branch topic)
check "remote-only branch diff" "r t" "$(git -C "$d" diff --name-only "$(val base "$out")" "$(val head "$out")" | tr '\n' ' ' | sed 's/ $//')"
check "fetch writes no refs" "$refs_before" "$(git -C "$d" for-each-ref)"
root=$(git -C "$d" rev-list --max-parents=0 HEAD)
out=$(prepare "$d" commit "$root")
check "root commit diff" ".gitignore assumed both deleted link sub/staged sw tracked" "$(git -C "$d" diff --name-only "$(val base "$out")" "$(val head "$out")" | tr '\n' ' ' | sed 's/ $//')"
for url in "$origin_url/pull/7/files" "$origin_url/pull/7#issuecomment-1" "#7"; do
	out=$(prepare "$d" pr "$url" release)
	check "PR form $url" "t" "$(git -C "$d" diff --name-only "$(val base "$out")" "$(val head "$out")")"
done
mid=$(git -C "$d" rev-parse HEAD)
out=$(prepare "$d" range "$root..$mid")
check "range diff" "m" "$(git -C "$d" diff --name-only "$(val base "$out")" "$(val head "$out")")"
# A fork checkout where origin and upstream both have a PR 7 with different heads.
git clone -q --bare "$o" "$scratch/x/fork.git"
git clone -q "$o" "$scratch/fork-work"
(cd "$scratch/fork-work" && git switch -q release && echo f >f && git add f && git commit -qm f && git push -q "$scratch/x/fork.git" HEAD:refs/pull/7/head)
git -C "$d" remote add upstream "$o" && git -C "$d" remote set-url origin "$scratch/x/fork.git"
out=$(prepare "$d" pr 7 release)
check "bare PR number uses the upstream remote" "t" "$(git -C "$d" diff --name-only "$(val base "$out")" "$(val head "$out")")"
out=$(prepare "$d" pr https://example.com/x/fork/pull/7 release)
check "PR URL uses the remote of its repository" "f" "$(git -C "$d" diff --name-only "$(val base "$out")" "$(val head "$out")")"
check "PR URL of an unknown repository stops prepare" fail "$(prepare "$d" pr https://example.com/y/other/pull/7 release >/dev/null 2>&1 && echo ok || echo fail)"

# --- run folders and cleanup ---
d=$(new_repo runs)
(cd "$d" && echo x >tracked)
r1=$(val run "$(prepare "$d" current)")
r2=$(val run "$(prepare "$d" current)")
check "runs get distinct folders" yes "$([ -d "$r1" ] && [ -d "$r2" ] && [ "$r1" != "$r2" ] && echo yes)"
mkdir "$scratch/outside" && touch "$scratch/outside/state"
check "cleanup refuses a path outside the runs folder" fail "$("$script" cleanup "$PRE_PR_RUNS/../outside" >/dev/null 2>&1 && echo ok || echo fail)"
"$script" clones "$r1" a >/dev/null
mkdir -p "$r1/clones/a/ro/dir" "$r1/clones/a/locked/d" && echo x >"$r1/clones/a/ro/dir/f" && chmod -R a-w "$r1/clones/a/ro" && chmod 000 "$r1/clones/a/locked"
"$script" cleanup "$r1" >/dev/null
check "cleanup removes read-only clone content" gone "$([ -e "$r1/clones" ] && echo left || echo gone)"
check "cleanup keeps the run folder" yes "$([ -f "$r1/state" ] && echo yes)"

# An edit with the same size and stat data as the index entry, as an edit in the
# same clock tick as the index write gives on coarse timestamps. git rehashes it
# only because the index is not older than the entry, so the copy keeps its mtime.
d=$(new_repo racy)
(cd "$d" && git config core.trustctime false && touch -d @1600000000 tracked && git update-index -q --refresh && echo x >tracked && touch -d @1600000000 tracked .git/index)
out=$(prepare "$d" current)
check "snapshot sees a racily clean edit" x "$(git -C "$d" show "$(val head "$out"):tracked")"

if [ "$failures" -ne 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
