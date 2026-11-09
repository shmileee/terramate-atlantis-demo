#!/usr/bin/env bash
# End-to-end scenarios against GitHub and the Atlantis from `make up`. Each
# scenario opens a pull request with `gh`, drives Atlantis with comments,
# asserts on what it answers and on the CI check, and ends with every plan
# applied. Afterwards the pull request is closed and its branch deleted;
# KEEP_OPEN=1 leaves it open, and only releases its Atlantis locks so the
# next scenario can plan the same stacks. Run one with: atlantis/e2e.sh <name>
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
source .env

REPO=$(git remote get-url origin | sed -E 's#\.git$##; s#.*[:/]([^/]+/[^/]+)$#\1#')
BOT="${ATLANTIS_GH_APP_SLUG}[bot]"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
LOG_DIR=${LOG_DIR:-$PWD/.e2e-comments}
mkdir -p "$LOG_DIR"

PR=""
SEEN=0
COMMENT=""

say() { printf '  %s\n' "$*"; }
fail() {
	printf '  FAIL: %s\n' "$*" >&2
	exit 1
}

branch() { # branch NAME: fresh clone on a new branch, cwd is the clone
	rm -rf "$WORK/repo"
	gh repo clone "$REPO" "$WORK/repo" -- -q
	cd "$WORK/repo"
	git checkout -q -b "demo/$1-$(date +%s)"
}

open_pr() { # open_pr TITLE BODY: commit, push, open a pull request
	git add -A
	git commit -qm "$1"
	git push -q -u origin HEAD 2>/dev/null
	PR=$(gh pr create -R "$REPO" --title "$1" --body "$2" | grep -oE '[0-9]+$')
	SEEN=0
	say "PR #$PR https://github.com/$REPO/pull/$PR"
}

comment() { # comment BODY
	SEEN=$(gh api "repos/$REPO/issues/$PR/comments" -f body="$1" --jq .id)
	say "> $1"
}

wait_for() { # wait_for REGEX: next Atlantis comment matching REGEX
	local body
	for _ in $(seq 1 60); do
		body=$(gh api "repos/$REPO/issues/$PR/comments?per_page=100" |
			jq -r --arg bot "$BOT" --argjson after "$SEEN" \
				'[.[] | select(.id > $after and .user.login == $bot)] | last // empty
				 | "\(.id)\n\(.body)"')
		if [ -n "$body" ] && grep -qE "$1" <<<"$body"; then
			SEEN=$(head -1 <<<"$body")
			COMMENT=$(tail -n +2 <<<"$body")
			printf '%s\n' "$COMMENT" >"$LOG_DIR/$SCENARIO-$SEEN.md"
			no_red_lines
			return 0
		fi
		sleep 5
	done
	fail "no Atlantis comment matching /$1/"
}

no_red_lines() { # GitHub renders a line starting with "-" red in Atlantis' diff blocks
	! grep -nE '^-([^-]|$)' <<<"$COMMENT" >&2 || fail "comment has lines GitHub renders red"
}

has() { grep -qF -- "$1" <<<"$COMMENT" || fail "comment lacks: $1"; say "ok: $1"; }
lacks() { ! grep -qF -- "$1" <<<"$COMMENT" || fail "comment has: $1"; say "ok, absent: $1"; }

ci_is() { # ci_is pass|fail: the generated-files check on the head commit
	local state=""
	for _ in $(seq 1 60); do
		state=$(gh pr checks -R "$REPO" "$PR" --json name,bucket \
			--jq '.[] | select(.name == "check") | .bucket' 2>/dev/null || true)
		case "$state" in pass | fail) break ;; esac
		sleep 5
	done
	[ "$state" = "$1" ] || fail "CI check is '$state', expected '$1'"
	say "ok: CI check $1"
}

applied() { # applied N: `atlantis apply` applies all N planned projects
	comment "atlantis apply"
	wait_for 'Ran Apply|Error'
	if [ "$1" = 1 ]; then has 'Apply complete!'; else has "$1 successful, 0 failed, 0 errored"; fi
	lacks 'Apply Failed'
}

finish() {
	ci_is pass
	comment "atlantis unlock"
	wait_for 'unlocked'
	[ -z "${KEEP_OPEN:-}" ] || return 0
	gh pr close -R "$REPO" "$PR" --delete-branch >/dev/null
}

DEV=stacks/aws/acme-development/eu-west-1
PROD=stacks/aws/acme-production/eu-west-1

count_is() { # count_is TEXT N: TEXT appears N times in the comment
	local got
	got=$({ grep -oF -- "$1" <<<"$COMMENT" || true; } | wc -l | tr -d ' ')
	[ "$got" = "$2" ] || fail "expected '$1' $2 time(s), found $got"
	say "ok: '$1' x$2"
}

scenario_new_stack() {
	branch new-stack
	terramate create "$DEV/new-stack" --name new-stack >/dev/null
	cat >"$DEV/new-stack/main.tf" <<'TF'
resource "terraform_data" "this" {
  input = "${local.account_name}-${local.region}-new-stack"
}
TF
	terramate generate >/dev/null
	open_pr "feat: add a new stack" "$(
		cat <<'MD'
Adds a brand new stack, `stacks/aws/acme-development/eu-west-1/new-stack`, created with `terramate create`.

**What to look for:** nobody edited `atlantis.yaml`. It isn't in the repository at all. Atlantis generates it for this pull request, finds the new stack, and plans it as `acme-development-eu-west-1-new-stack`.

**Expected:** one project planned, then applied with `atlantis apply`.
MD
	)"
	wait_for 'Ran Plan|Error'
	has 'project: `acme-development-eu-west-1-new-stack` dir: `'$DEV'/new-stack`'
	has 'Plan: 1 to add, 0 to change, 0 to destroy.'
	applied 1
	finish
}

scenario_per_account() {
	branch per-account
	sed -i.bak 's/-network"/-network-v2"/' "$DEV/network/main.tf" "$PROD/network/main.tf"
	rm "$DEV/network/main.tf.bak" "$PROD/network/main.tf.bak"
	open_pr "feat: change a stack in each account" "$(
		cat <<'MD'
Changes the `network` stack in both accounts.

**What to look for:** the production account's `account.tm.hcl` sets two Atlantis settings for every stack in that account, and the development account sets none. So the two projects behave differently:

- The production project runs the server's `production` workflow, which validates before it plans. Its output shows `Success! The configuration is valid.`
- Before apply, the production project needs the pull request to be mergeable and up to date with `main`. The development project only needs it to be mergeable, the repository-wide default.

**Expected:** both projects planned, then applied with `atlantis apply`.
MD
	)"
	wait_for 'Ran Plan|Error'
	has 'Ran Plan for 2 projects'
	has 'project: `acme-development-eu-west-1-network`'
	has 'project: `acme-production-eu-west-1-network`'
	count_is 'The configuration is valid.' 1
	applied 2
	finish
}

scenario_skip_and_manual() {
	branch skip-and-manual
	for s in "$PROD/skipped" "$PROD/manual" "$DEV/app"; do
		sed -i.bak 's/"$/-v2"/; s/-v2-v2"/-v2"/' "$s/main.tf" && rm "$s/main.tf.bak"
	done
	open_pr "feat: change the skipped and manual stacks" "$(
		cat <<'MD'
Changes three stacks: `skipped`, `manual` and the development `app`.

**What to look for:**

- `skipped` sets `atlantis_skip = true`. It isn't an Atlantis project, so it doesn't show up at all.
- `manual` sets `atlantis_autoplan = false`. Atlantis knows about it but doesn't plan it until someone comments `atlantis plan -p acme-production-eu-west-1-manual`.
- `app` has no special settings and is planned right away.

**Expected:** `app` planned when the pull request opens, `manual` planned on request, then both applied with `atlantis apply`.
MD
	)"
	wait_for 'Ran Plan|Error'
	has 'project: `acme-development-eu-west-1-app`'
	lacks 'skipped'
	lacks 'manual'
	comment "atlantis plan -p acme-production-eu-west-1-manual"
	wait_for 'Ran Plan|Error'
	has 'project: `acme-production-eu-west-1-manual`'
	has 'Plan: 1 to add, 0 to change, 0 to destroy.'
	applied 2
	finish
}

ALL="new_stack per_account skip_and_manual"
for SCENARIO in ${*:-$ALL}; do
	echo "== $SCENARIO"
	(cd "$PWD" && "scenario_$SCENARIO")
done
echo "all scenarios passed"
