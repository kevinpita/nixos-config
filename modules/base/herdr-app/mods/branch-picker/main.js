// Branches and pull requests of the focused pane's repo, by latest activity.
// Enter or a click goes to the space that shows the row's checkout, or asks for
// a folder and opens a new git worktree there as a space. A PR whose branch is
// gone is fetched from GitHub. Tab cycles the filter, ctrl+o opens the PR page.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input, Scrollbar, TextView, v_virtual_list, VirtualListScrollHandle } from "gpui-base";
import { run, props, closeOverlay, theme, spaces, panes, focused, exec, home, settings } from "herdr";

// A new checkout goes beside the current one by default: ~/src/repo/main ->
// ~/src/repo/<branch>, with slashes as dashes so feature/x stays one folder.
const besides = (top, branch) => `${top.replace(/\/[^/]*$/, "")}/${branch.replace(/\//g, "-")}`;
const tilde = (path, userHome) => (userHome && path.startsWith(userHome) ? `~${path.slice(userHome.length)}` : path);
const ago = (s) => {
  const d = Date.now() / 1000 - s;
  return d < 3600 ? `${Math.max(1, Math.round(d / 60))}m` : d < 86400 ? `${Math.round(d / 3600)}h` : d < 86400 * 60 ? `${Math.round(d / 86400)}d` : `${Math.round(d / 86400 / 30)}mo`;
};

const STATES = {
  OPEN: { label: "Open", color: "#238636" },
  DRAFT: { label: "Draft", color: "#6e7681" },
  MERGED: { label: "Merged", color: "#8957e5" },
  CLOSED: { label: "Closed", color: "#da3633" },
};
const stateOf = (pr) => STATES[pr.state === "OPEN" && pr.isDraft ? "DRAFT" : pr.state] ?? STATES.CLOSED;

const FILTERS = [
  { label: "All", keep: () => true },
  { label: "Open PRs", keep: (r) => r.pr?.state === "OPEN" },
  { label: "PRs", keep: (r) => Boolean(r.pr) },
  { label: "Branches", keep: (r) => r.local || r.remotes.length > 0 },
];

const ROW = 54;
// The list stays light: GitHub times out on 200 PRs with bodies and diff stats.
// Those load for the selected PR only.
const PR_FIELDS = "number,title,state,isDraft,headRefName,headRepository,headRepositoryOwner,isCrossRepository,author,updatedAt,url,baseRefName";
const PR_DETAIL_FIELDS = "body,additions,deletions,changedFiles,reviewDecision";
const REVIEW = { APPROVED: "approved", CHANGES_REQUESTED: "changes requested", REVIEW_REQUIRED: "review required" };

// "owner/repo" of a GitHub remote URL, lowercased; null for other hosts.
const githubSlug = (url) => url.match(/github\.com[:/]([^/]+\/[^/]+?)(?:\.git)?\/?$/)?.[1].toLowerCase() ?? null;

// The focused pane's folder and machine, as the lazygit popup finds them.
function location() {
  const space = spaces().find((s) => s.active), f = focused();
  const pane = f?.pane ? panes().find((p) => p.pane === f.pane) : null;
  const on = f?.pane === null ? (f.terminal?.includes("/") ? f.terminal.split("/")[0] : null) : space?.machine ?? null;
  return { cwd: pane?.cwd || f?.cwd || space?.folder, on };
}

// The space whose first terminal is inside a checkout (the deepest checkout wins).
function spaceOf(path, all, on) {
  const inside = (p, dir) => p === dir || p.startsWith(dir + "/");
  return spaces().find((s) => {
    if ((s.machine ?? null) !== (on ?? null)) return false;
    const tabs = new Set(s.tabs.map((c) => c.id));
    const at = panes().find((p) => tabs.has(p.tab) && p.cwd)?.cwd || s.folder;
    if (!at || !inside(at, path)) return false;
    return !all.some((c) => c.path !== path && c.path.length > path.length && inside(at, c.path));
  });
}

async function git(cwd, args, on) {
  const r = await exec("git", args, { cwd, on });
  return { ok: r.code === 0, out: (r.stdout ?? "").trim(), err: (r.stderr || r.stdout || "").trim() };
}

async function gh(cwd, args, on) {
  try {
    const r = await exec("gh", args, { cwd, on });
    return { ok: r.code === 0, out: (r.stdout ?? "").trim(), err: (r.stderr || r.stdout || "").trim() };
  } catch (error) {
    return { ok: false, out: "", err: `gh: ${error}` };
  }
}

export default class BranchPicker extends View {
  init(_props, cx) {
    const { cwd, on } = location();
    this.on = on;
    this.cwd = cwd;
    this.userHome = on ? null : home();
    this.repo = undefined; // undefined: looking, null: not in git
    this.branches = [];
    this.worktrees = [];
    this.remotes = new Map(); // remote name -> GitHub slug
    this.ghRepo = null;
    this.prs = null; // null: not read yet
    this.prError = "";
    this.rows = [];
    this.logs = new Map(); // row key -> commits, or "loading"
    this.details = new Map(); // PR number -> PR_DETAIL_FIELDS, or "loading"
    this.selected = null; // the selected row's key, kept across reloads
    this.filter = 0;
    this.text = "";
    this.at = 0;
    this.width = 0;
    this.syncing = true;
    this.busy = "";
    this.error = "";
    this.scroll = VirtualListScrollHandle.new();
    this.handle = cx.focus_handle();
    this.input = InputState.new({ placeholder: "Filter by branch, title, author or #number" });
    this.input.on("change", (_e, cx) => {
      this.text = this.input.value();
      this.select(0, cx);
    });
    this.input.on("submit", (_e, cx) => this.open(this.shown()[this.at], cx));
    this.input.focus();
    cx.timer.after(600, () => this.input.focus());
    // The folder prompt for a branch that has no checkout yet.
    this.pending = null;
    this.pathInput = InputState.new({ placeholder: "Folder for the new worktree" });
    this.pathInput.on("change", (_e, cx) => {
      this.error = "";
      cx.notify();
    });
    this.pathInput.on("submit", (_e, cx) => this.create(cx));
    cx.spawn(async (cx) => {
      try {
        await this.load(cx);
      } catch (error) {
        this.error = String(error);
      }
      this.syncing = false;
      cx.notify();
    });
  }

  close() {
    closeOverlay(props().overlay);
  }

  async load(cx) {
    if (this.on) {
      const r = await exec("sh", ["-c", 'printf %s "$HOME"'], { on: this.on });
      this.userHome = r.stdout.trim() || null;
    }
    if (!this.cwd) return void (this.repo = null);
    const top = await git(this.cwd, ["rev-parse", "--show-toplevel"], this.on);
    const common = await git(this.cwd, ["rev-parse", "--path-format=absolute", "--git-common-dir"], this.on);
    if (!top.ok || !common.ok) return void (this.repo = null);
    const main = common.out.endsWith("/.git") ? common.out.slice(0, -5) : common.out;
    this.repo = { top: top.out, main, name: main.split("/").pop() };
    await Promise.all([this.readRefs(), this.readRemotes()]);
    this.rebuild(cx);
    // Branches show at once; PRs and a fetch follow.
    await Promise.all([
      this.readPRs().then(() => this.rebuild(cx)),
      git(this.repo.main, ["fetch", "--all", "--prune", "--quiet"], this.on).then(async (r) => {
        if (!r.ok) this.error = `git fetch: ${r.err}`;
        await this.readRefs();
        this.rebuild(cx);
      }),
    ]);
  }

  async readRefs() {
    const fmt = "%(refname)%09%(committerdate:unix)%09%(authorname)%09%(upstream:short)%09%(contents:subject)";
    const [refs, list] = await Promise.all([
      git(this.repo.main, ["for-each-ref", `--format=${fmt}`, "refs/heads", "refs/remotes"], this.on),
      git(this.repo.main, ["worktree", "list", "--porcelain"], this.on),
    ]);
    const byName = new Map();
    for (const line of refs.out.split("\n").filter(Boolean)) {
      const [ref, at, author, upstream, ...subject] = line.split("\t");
      let name, remote = null;
      if (ref.startsWith("refs/heads/")) name = ref.slice(11);
      else {
        [remote, ...name] = ref.slice(13).split("/");
        name = name.join("/");
        if (name === "HEAD") continue;
      }
      const b = byName.get(name) ?? { name, local: false, upstream: "", remotes: [], at: 0, author: "", subject: "", ref: "" };
      if (remote) b.remotes.push(remote);
      else Object.assign(b, { local: true, upstream });
      if (Number(at) > b.at) Object.assign(b, { at: Number(at), author, subject: subject.join("\t"), ref: remote ? `${remote}/${name}` : name });
      byName.set(name, b);
    }
    this.branches = [...byName.values()];
    this.worktrees = [];
    for (const block of list.out.split(/\n\n+/)) {
      const lines = block.split("\n");
      const path = lines.find((l) => l.startsWith("worktree "))?.slice(9);
      if (!path || lines.some((l) => l === "bare" || l.startsWith("prunable"))) continue;
      const branch = lines.find((l) => l.startsWith("branch "))?.slice(7).replace(/^refs\/heads\//, "") ?? null;
      this.worktrees.push({ path, branch, main: this.worktrees.length === 0 });
    }
  }

  async readRemotes() {
    const r = await git(this.repo.main, ["remote", "-v"], this.on);
    for (const line of r.out.split("\n")) {
      const [name, url, kind] = line.split(/\s+/);
      if (kind === "(fetch)") this.remotes.set(name, githubSlug(url ?? ""));
    }
  }

  // PRs of the repo gh is set to, else of the upstream remote, else origin's.
  async readPRs() {
    const set = await gh(this.repo.top, ["repo", "set-default", "--view"], this.on);
    const named = (n) => this.remotes.get(n);
    this.ghRepo = (set.ok && /^[^/\s]+\/[^/\s]+$/.test(set.out) ? set.out.toLowerCase() : null) ?? named("upstream") ?? named("origin") ?? [...this.remotes.values()].find(Boolean) ?? null;
    if (!this.ghRepo) {
      this.prError = "No GitHub remote";
      return;
    }
    // Recent activity misses old open PRs, so those are read on their own.
    const list = (state, extra) => gh(this.repo.top, ["pr", "list", "--repo", this.ghRepo, "--state", state, ...extra, "--limit", "100", "--json", PR_FIELDS], this.on);
    const [recent, open] = await Promise.all([list("all", ["--search", "sort:updated-desc"]), list("open", [])]);
    if (!recent.ok || !open.ok) {
      this.prError = (recent.ok ? open : recent).err.split("\n")[0] || "gh pr list failed";
      return;
    }
    const byNumber = new Map([...JSON.parse(open.out), ...JSON.parse(recent.out)].map((pr) => [pr.number, pr]));
    this.prs = [...byNumber.values()];
  }

  remoteOf(slug) {
    return [...this.remotes].find(([, s]) => s === slug)?.[0] ?? null;
  }

  // Rows: every branch, local and remote merged by name, each with its newest
  // PR; PRs without a branch here get their own row.
  rebuild(cx) {
    const byName = new Map(this.branches.map((b) => [b.name, { ...b, key: `b:${b.name}`, pr: null }]));
    const rows = [...byName.values()];
    // A branch shows one PR: an open one first, else the newest.
    const prs = [...(this.prs ?? [])].sort((a, b) => (b.state === "OPEN") - (a.state === "OPEN") || Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
    for (const pr of prs) {
      const owner = pr.headRepositoryOwner?.login ?? "";
      const headSlug = pr.isCrossRepository ? `${owner}/${pr.headRepository?.name ?? ""}`.toLowerCase() : this.ghRepo;
      const headRemote = this.remoteOf(headSlug);
      const same = byName.get(pr.headRefName);
      // A same-name branch is the PR's only when it comes from the PR's head
      // repo: a local one must track it (or track nothing, for a same-repo PR,
      // as after a pull/<n>/head checkout), else a remote copy must be there.
      const tracksHead = (b) => b.upstream === `${headRemote}/${pr.headRefName}` || (!b.upstream && !pr.isCrossRepository);
      const isHead = (b) => Boolean(headRemote) && (b.local ? tracksHead(b) : b.remotes.includes(headRemote));
      // Fork PRs, and PRs whose branch name is taken here by another branch, get owner/branch.
      const local = pr.isCrossRepository || (same?.local && !isHead(same)) ? `${owner}/${pr.headRefName}` : pr.headRefName;
      const own = byName.get(local);
      const row = same && !same.pr && isHead(same) ? same : local !== pr.headRefName && own && !own.pr && own.local ? own : null;
      const at = Date.parse(pr.updatedAt) / 1000 || 0;
      if (row) Object.assign(row, { pr, headRemote, at: Math.max(row.at, at) });
      else rows.push({ key: `pr:${pr.number}`, name: local, local: false, upstream: "", remotes: [], at, author: pr.author?.login ?? "", subject: pr.title, ref: "", pr, headRemote });
    }
    this.rows = rows.sort((a, b) => b.at - a.at);
    const kept = this.shown().findIndex((r) => r.key === this.selected);
    this.select(kept < 0 ? this.at : kept, cx);
  }

  shown() {
    const f = this.text.trim().toLowerCase();
    const keep = FILTERS[this.filter].keep;
    return this.rows.filter((r) => keep(r) && (!f || [r.name, r.subject, r.author, r.pr ? `#${r.pr.number} ${r.pr.title} ${r.pr.author?.login ?? ""}` : ""].join(" ").toLowerCase().includes(f)));
  }

  checkout(row) {
    return this.worktrees.find((w) => w.branch === row.name) ?? null;
  }

  select(i, cx) {
    const rows = this.shown();
    this.at = Math.max(0, Math.min(i, rows.length - 1));
    if (rows.length) this.scroll.scroll_to_item(this.at);
    const row = rows[this.at];
    this.selected = row?.key ?? null;
    if (row?.ref && !this.logs.has(row.key)) {
      this.logs.set(row.key, "loading");
      cx.spawn(async (cx) => {
        const r = await git(this.repo.main, ["log", "-8", "--format=%h%x09%ct%x09%an%x09%s", row.ref, "--"], this.on);
        this.logs.set(row.key, r.ok ? r.out.split("\n").filter(Boolean).map((l) => l.split("\t")) : []);
        cx.notify();
      });
    }
    const n = row?.pr?.number;
    if (n && !this.details.has(n)) {
      this.details.set(n, "loading");
      cx.spawn(async (cx) => {
        const r = await gh(this.repo.top, ["pr", "view", String(n), "--repo", this.ghRepo, "--json", PR_DETAIL_FIELDS], this.on);
        this.details.set(n, r.ok ? JSON.parse(r.out) : null);
        cx.notify();
      });
    }
    cx.notify();
  }

  open(row, cx) {
    if (!row || this.busy || !this.repo) return;
    const there = this.checkout(row);
    if (there) return this.show(there.path);
    this.pending = row;
    this.error = "";
    this.pathInput.set_value(tilde(besides(this.repo.top, row.name), this.userHome));
    this.pathInput.focus();
    cx.notify();
  }

  back(cx) {
    this.pending = null;
    this.error = "";
    this.input.focus();
    cx.notify();
  }

  create(cx) {
    const row = this.pending;
    if (!row || this.busy) return;
    const typed = this.pathInput.value().trim().replace(/\/+$/, "");
    if (!typed) return void ((this.error = "Type a folder."), cx.notify());
    // exec runs git without a shell: expand ~ and resolve ../x against this checkout.
    const expanded = typed === "~" || typed.startsWith("~/") ? `${this.userHome}${typed.slice(1)}` : typed;
    const parts = [];
    for (const part of (expanded.startsWith("/") ? expanded : `${this.repo.top}/${expanded}`).split("/")) {
      if (part === "..") parts.pop();
      else if (part && part !== ".") parts.push(part);
    }
    const path = `/${parts.join("/")}`;
    this.busy = `Creating a worktree for ${row.name}…`;
    this.error = "";
    cx.notify();
    cx.spawn(async (cx) => {
      const r = await this.add(row, path).catch((error) => ({ ok: false, err: String(error) }));
      this.busy = "";
      if (r.ok) return this.show(path);
      this.error = r.err || "git worktree add failed";
      cx.notify();
    });
  }

  // A local branch is checked out as is, a remote one gets a tracking branch,
  // and a PR goes through gh, else its pull/<n>/head ref.
  async add(row, path) {
    const { main } = this.repo;
    if (row.local) return git(main, ["worktree", "add", path, row.name], this.on);
    if (row.remotes.length) {
      const remote = [row.headRemote, "origin", ...row.remotes].find((r) => r && row.remotes.includes(r));
      return git(main, ["worktree", "add", "--track", "-b", row.name, path, `${remote}/${row.name}`], this.on);
    }
    const n = String(row.pr.number);
    const added = await git(main, ["worktree", "add", "--detach", path], this.on);
    if (!added.ok) return added;
    let r = await gh(path, ["pr", "checkout", n, "--repo", this.ghRepo, "--branch", row.name], this.on);
    if (!r.ok) {
      const fetched = await git(path, ["fetch", this.remoteOf(this.ghRepo) ?? `https://github.com/${this.ghRepo}.git`, `pull/${n}/head`], this.on);
      r = fetched.ok ? await git(path, ["switch", "-c", row.name, "FETCH_HEAD"], this.on) : fetched;
    }
    if (!r.ok) await git(main, ["worktree", "remove", "--force", path], this.on);
    return r;
  }

  show(path) {
    this.close();
    const s = spaceOf(path, this.worktrees, this.on);
    // Unnamed, so the space follows the checkout folder and nests under the repo.
    if (s) run("space.select", { id: s.id });
    else run("space.new", { folder: path, machine: this.on });
  }

  key(e, cx) {
    if (this.pending) {
      if (e.key !== "escape") return;
      cx.stop_propagation();
      return this.back(cx);
    }
    const n = this.shown().length;
    if (e.key === "escape") return this.close();
    if (e.key === "down" && n) this.select((this.at + 1) % n, cx);
    else if (e.key === "up" && n) this.select((this.at + n - 1) % n, cx);
    else if (e.key === "pagedown") this.select(this.at + 8, cx);
    else if (e.key === "pageup") this.select(this.at - 8, cx);
    else if (e.key === "tab") {
      this.filter = (this.filter + (e.modifiers.shift ? FILTERS.length - 1 : 1)) % FILTERS.length;
      this.select(0, cx);
    } else if (e.key === "o" && e.modifiers.control) {
      const url = this.shown()[this.at]?.pr?.url;
      if (url) exec("xdg-open", [url]).catch(() => {});
    } else return;
    cx.stop_propagation();
  }

  chip(pr, big) {
    const s = stateOf(pr);
    return h_flex()
      .flex_none()
      .h(big ? 22 : 18)
      .px(big ? 9 : 7)
      .gap(5)
      .items_center()
      .rounded(big ? 11 : 9)
      .bg(s.color)
      .text_size(big ? 12 : 11)
      .font_semibold()
      .text_color("#ffffff")
      .when(big, (el) => el.child(svg("mods/branch-picker/pr.svg").size(12).text_color("#ffffff")))
      .child(big ? s.label : `PR #${pr.number}`);
  }

  badge(t, text, color) {
    return div()
      .flex_none()
      .px(5)
      .h(16)
      .rounded(4)
      .border_1()
      .border_color(color ?? t.border)
      .text_size(10.5)
      .text_color(color ?? t.dim)
      .child(text);
  }

  renderRow(t, row, selected) {
    const there = this.checkout(row);
    const space = there && spaceOf(there.path, this.worktrees, this.on);
    return h_flex()
      .h(ROW)
      .mx(6)
      .px(10)
      .gap(10)
      .items_center()
      .rounded(8)
      .cursor_pointer()
      .when(selected, (el) => el.bg(t.selected))
      .when(!selected, (el) => el.hover((s) => s.bg(t.hover)))
      .child(svg(row.pr ? "mods/branch-picker/pr.svg" : "mods/branch-picker/branch.svg").flex_none().size(16).text_color(row.pr ? stateOf(row.pr).color : t.dim))
      .child(
        v_flex()
          .flex_1()
          .min_w(0)
          .gap(3)
          .child(
            h_flex()
              .gap(8)
              .items_center()
              .min_w(0)
              .child(div().min_w(0).truncate().font_medium().text_color(t.foreground).child(row.name))
              .when(Boolean(row.pr), (el) => el.child(this.chip(row.pr))),
          )
          .child(div().truncate().text_size(11.5).text_color(t.muted).child([row.pr?.title ?? row.subject, row.author].filter(Boolean).join("  ·  "))),
      )
      .child(
        v_flex()
          .flex_none()
          .items_end()
          .gap(4)
          .child(div().text_size(11).text_color(t.dim).child(row.at ? ago(row.at) : ""))
          .child(
            h_flex()
              .gap(4)
              .when(Boolean(space), (el) => el.child(this.badge(t, "open", t.accent)))
              .when(Boolean(there) && !space, (el) => el.child(this.badge(t, there?.main ? "main checkout" : "worktree")))
              .when(!there && row.local, (el) => el.child(this.badge(t, "local")))
              .when(!there && !row.local && row.remotes.length > 0, (el) => el.child(this.badge(t, row.remotes[0]))),
          ),
      );
  }

  renderDetail(t, row) {
    if (!row) return v_flex().flex_1().items_center().justify_center().text_color(t.dim).child("Nothing selected");
    const pr = row.pr;
    const there = this.checkout(row);
    const log = this.logs.get(row.key);
    const more = pr && this.details.get(pr.number);
    const facts = more && more !== "loading" ? more : null;
    const target = there ? there.path : besides(this.repo.top, row.name);
    const section = (title) => div().pt(6).text_size(11).font_semibold().text_color(t.dim).child(title);
    return v_flex()
      .id("bp-detail")
      .size_full()
      .p(16)
      .gap(10)
      .overflow_y_scroll()
      .when(Boolean(pr), (el) =>
        el
          .child(h_flex().gap(8).items_center().child(this.chip(pr, true)).child(div().text_size(12).text_color(t.dim).child(`#${pr.number}`)))
          .child(div().text_size(15).font_semibold().text_color(t.foreground).child(pr.title))
          .child(div().text_size(12).text_color(t.muted).child(`${pr.author?.login ?? "someone"} wants ${pr.headRefName} -> ${pr.baseRefName}`))
          .child(
            h_flex()
              .gap(10)
              .text_size(12)
              .when(Boolean(facts), (el) =>
                el
                  .child(div().text_color(STATES.OPEN.color).child(`+${facts?.additions ?? 0}`))
                  .child(div().text_color(STATES.CLOSED.color).child(`-${facts?.deletions ?? 0}`))
                  .child(div().text_color(t.dim).child(`${facts?.changedFiles ?? 0} files`)),
              )
              .when(Boolean(REVIEW[facts?.reviewDecision]), (el) => el.child(div().text_color(t.dim).child(REVIEW[facts?.reviewDecision] ?? "")))
              .child(div().text_color(t.dim).child(`updated ${ago(Date.parse(pr.updatedAt) / 1000)} ago`)),
          )
          .when(more === "loading", (el) => el.child(div().text_color(t.dim).child("…")))
          .when(Boolean(facts?.body?.trim()), (el) =>
            el.child(
              div()
                .p(10)
                .rounded(8)
                .bg(t.background)
                .text_size(12.5)
                .text_color(t.foreground)
                .child(TextView.markdown(`bp-body-${pr.number}`, facts.body.length > 6000 ? `${facts.body.slice(0, 6000)}\n\n…` : facts.body)),
            ),
          ),
      )
      .when(!pr, (el) =>
        el
          .child(h_flex().gap(8).items_center().child(svg("mods/branch-picker/branch.svg").size(16).text_color(t.muted)).child(div().text_size(15).font_semibold().text_color(t.foreground).child(row.name)))
          .child(
            h_flex()
              .gap(4)
              .when(row.local, (el) => el.child(this.badge(t, "local")))
              .children(row.remotes.map((r) => this.badge(t, r))),
          ),
      )
      .when(Boolean(row.ref), (el) =>
        el
          .child(section("RECENT COMMITS"))
          .when(log === "loading" || log === undefined, (el) => el.child(div().text_color(t.dim).child("…")))
          .when(Array.isArray(log), (el) =>
            el.children(
              (Array.isArray(log) ? log : []).map(([hash, at, author, subject]) =>
                h_flex()
                  .gap(8)
                  .text_size(12)
                  .child(div().flex_none().font_family(String(settings().font_family ?? "JetBrains Mono")).text_color(t.accent).child(hash))
                  .child(div().flex_1().min_w(0).truncate().text_color(t.foreground).child(subject ?? ""))
                  .child(div().flex_none().text_color(t.dim).child(`${author} · ${ago(Number(at))}`)),
              ),
            ),
          ),
      )
      .child(section(there ? "CHECKED OUT AT" : "SUGGESTED FOLDER"))
      .child(div().text_size(12).text_color(t.muted).child(tilde(target, this.userHome)));
  }

  render() {
    const t = theme();
    const rows = this.shown();
    const sel = rows[this.at];
    const counts = FILTERS.map((f) => this.rows.filter(f.keep).length);
    const wide = this.width >= 820;
    const r = this.repo;
    return v_flex()
      .id("branch-picker")
      .track_focus(this.handle)
      .on_key_down((e, cx) => this.key(e, cx))
      .on_size_change((size, cx) => {
        this.width = size.width;
        cx.notify();
      })
      .size_full()
      .bg(t.popover)
      .text_size(13)
      .child(
        h_flex()
          .flex_none()
          .px(18)
          .pt(16)
          .pb(12)
          .gap(10)
          .items_center()
          .child(svg("mods/branch-picker/branch.svg").size(18).text_color(t.accent))
          .child(div().text_size(15).font_semibold().text_color(t.foreground).child("Branches & pull requests"))
          .child(div().text_size(13).text_color(t.dim).child(r ? r.name : ""))
          .child(div().flex_1())
          .when(this.syncing, (el) => el.child(h_flex().gap(6).items_center().text_size(11).text_color(t.dim).child(svg("mods/workspace-chrome/spinner.svg").size(12).text_color(t.working).spin(900)).child("syncing")))
          .when(!this.syncing && Boolean(this.ghRepo), (el) => el.child(div().text_size(11).text_color(t.dim).child(this.ghRepo ?? ""))),
      )
      .when(r === undefined, (el) => el.child(div().flex_1().px(18).text_color(t.muted).child("Reading the repository…")))
      .when(r === null, (el) => el.child(div().flex_1().px(18).text_color(t.muted).child(`${this.cwd ? tilde(this.cwd, this.userHome) : "This pane"} is not in a git repository.`)))
      .when(Boolean(r), (el) =>
        el
          .child(
            h_flex()
              .flex_none()
              .mx(18)
              .h(36)
              .px(10)
              .gap(8)
              .items_center()
              .rounded(9)
              .border_1()
              .border_color(t.accent)
              .bg(t.background)
              .child(svg("mods/workspace-chrome/search.svg").size(15).text_color(t.dim))
              .child(Input.new(this.input).flex_1().h_full().text_size(12.8).text_color(t.foreground)),
          )
          .child(
            h_flex()
              .flex_none()
              .px(18)
              .pt(10)
              .pb(8)
              .gap(6)
              .items_center()
              .children(
                FILTERS.map((f, i) =>
                  h_flex()
                    .id(`bp-filter-${i}`)
                    .h(26)
                    .px(10)
                    .gap(6)
                    .items_center()
                    .rounded(13)
                    .cursor_pointer()
                    .text_size(12)
                    .when(i === this.filter, (el) => el.bg(t.selected).text_color(t.foreground).font_medium())
                    .when(i !== this.filter, (el) => el.text_color(t.muted).hover((s) => s.bg(t.hover)))
                    .on_click((_e, cx) => {
                      this.filter = i;
                      this.select(0, cx);
                    })
                    .child(f.label)
                    .child(div().text_size(11).text_color(t.dim).child(String(counts[i]))),
                ),
              )
              .child(div().flex_1())
              .when(Boolean(this.prError), (el) => el.child(div().max_w(320).truncate().text_size(11).text_color(t.blocked).child(`PRs unavailable: ${this.prError}`))),
          )
          .child(
            h_flex()
              .flex_1()
              .min_h(0)
              .border_t_1()
              .border_color(t.border)
              .child(
                div()
                  .relative()
                  .flex_1()
                  .min_w(0)
                  .h_full()
                  .pt(6)
                  .when(rows.length === 0, (el) => el.child(div().p(18).text_color(t.dim).child(this.syncing ? "…" : "Nothing matches.")))
                  .child(
                    v_virtual_list("bp-rows", rows.length, ROW, (i) => rows[i].key, (range) => rows.slice(range.start, range.end).map((row, j) => this.renderRow(t, row, range.start + j === this.at)))
                      .track_scroll(this.scroll)
                      .size_full()
                      .on_item_click((key, cx) => this.open(this.rows.find((x) => x.key === key), cx)),
                  )
                  .child(Scrollbar.vertical("bp-rows").absolute().inset_0()),
              )
              .when(wide, (el) => el.child(div().w(Math.round(this.width * 0.42)).flex_none().h_full().border_l_1().border_color(t.border).child(this.renderDetail(t, sel)))),
          ),
      )
      .when(Boolean(this.pending), (el) =>
        el.child(
          v_flex()
            .flex_none()
            .px(18)
            .py(12)
            .gap(8)
            .border_t_1()
            .border_color(t.border)
            .bg(t.raised)
            .child(
              h_flex()
                .gap(8)
                .items_center()
                .child(svg(this.pending?.pr ? "mods/branch-picker/pr.svg" : "mods/branch-picker/branch.svg").size(14).text_color(t.accent))
                .child(div().font_semibold().text_color(t.foreground).child(`New worktree for ${this.pending?.name ?? ""}`))
                .child(div().flex_1())
                .child(
                  div()
                    .id("bp-back")
                    .px(8)
                    .h(22)
                    .rounded(6)
                    .cursor_pointer()
                    .text_size(11.5)
                    .text_color(t.muted)
                    .hover((s) => s.bg(t.hover))
                    .on_click((_e, cx) => this.back(cx))
                    .child("Back"),
                )
                .child(
                  div()
                    .id("bp-create")
                    .px(10)
                    .h(22)
                    .rounded(6)
                    .cursor_pointer()
                    .text_size(11.5)
                    .font_medium()
                    .bg(t.solid)
                    .text_color(t.solid_foreground)
                    .on_click((_e, cx) => this.create(cx))
                    .child("Create"),
                ),
            )
            .child(
              h_flex()
                .h(34)
                .px(10)
                .items_center()
                .rounded(8)
                .border_1()
                .border_color(t.accent)
                .bg(t.background)
                .child(Input.new(this.pathInput).flex_1().h_full().text_size(12.8).text_color(t.foreground)),
            ),
        ),
      )
      .child(
        h_flex()
          .flex_none()
          .px(18)
          .py(9)
          .gap(12)
          .border_t_1()
          .border_color(t.border)
          .text_size(11)
          .text_color(t.dim)
          .child(div().flex_none().child(this.pending ? "↵ create · esc back" : "↑↓ choose · ↵ open · tab filter · ctrl+o browser · esc close"))
          .child(div().flex_1())
          .when(Boolean(this.busy), (el) => el.child(h_flex().gap(6).items_center().child(svg("mods/workspace-chrome/spinner.svg").size(12).text_color(t.working).spin(900)).child(this.busy)))
          .when(!this.busy && Boolean(this.error), (el) => el.child(div().min_w(0).truncate().text_color(t.blocked).child(this.error))),
      );
  }
}
