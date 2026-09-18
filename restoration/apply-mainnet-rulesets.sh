#!/usr/bin/env bash
# =============================================================================
# apply-mainnet-rulesets.sh — възстановяване на rulesets за NEBA-TOKEN/neba-token-mainnet
# след upgrade на плана (Team/Enterprise). Idempotent: НЕ дублира съществуващи
# rulesets (проверява по име). НИЩО не трие и не променя съществуващи rulesets.
#
# Източници на канон (commit-нати в neba-token-mainnet):
#   - docs/github/MERGE_QUEUE_RULESET_CANON_14910183.json  (Main Branch Protection)
#   - docs/github/MERGE_QUEUE_RULESET_CANON_21761089.json  (Main Safety — NO BYPASS)
#   - reports/github-stability/GLOBAL_RULESETS.md          (governance push + org rulesets)
#
# Употреба:
#   ./apply-mainnet-rulesets.sh            # dry-run: отпечатва payload-ите
#   ./apply-mainnet-rulesets.sh --apply    # създава липсващите rulesets
#   ./apply-mainnet-rulesets.sh --apply --org   # + org-level GLOBAL rulesets (evaluate)
# =============================================================================
set -euo pipefail

ORG="NEBA-TOKEN"
REPO="neba-token-mainnet"
APPLY=false
WITH_ORG=false
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=true ;;
    --org)   WITH_ORG=true ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

command -v gh >/dev/null || { echo "gh CLI е задължителен"; exit 1; }
command -v jq >/dev/null || { echo "jq е задължителен"; exit 1; }

# Правила на plans: rulesets API работи само на Team+ за private repos.
if ! gh api "repos/$ORG/$REPO/rulesets" >/dev/null 2>&1; then
  echo "ГРЕШКА: GET /repos/$ORG/$REPO/rulesets не минава — планът още не позволява rulesets." >&2
  echo "Първо изпълни Фаза 0 (billing) от restoration/README.md." >&2
  exit 1
fi

existing_names() { gh api "repos/$ORG/$REPO/rulesets?per_page=100" --jq '.[].name'; }

create_ruleset() {
  local name="$1" payload="$2"
  if existing_names | grep -qxF "$name"; then
    echo "SKIP  '$name' — вече съществува (не пипаме)."
    return 0
  fi
  echo "----- PAYLOAD: $name -----"
  echo "$payload" | jq .
  if $APPLY; then
    echo "$payload" | gh api -X POST "repos/$ORG/$REPO/rulesets" --input - \
      --jq '"CREATED id=\(.id) name=\(.name) enforcement=\(.enforcement)"'
  else
    echo "DRY-RUN: няма създаване (добави --apply)."
  fi
}

REQUIRED_CHECKS='[{"context":"FAST-LITE Summary"},{"context":"Secrets Scan Summary"}]'

# --- 1) NEBA Main Branch Protection (canon 14910183) -------------------------
# pull_request: 1 approve + dismiss stale + last-push approval + thread resolution
# + creation/deletion/non_fast_forward (по GLOBAL_RULESETS.md §4)
# + required checks FAST-LITE Summary / Secrets Scan Summary
# bypass: RepositoryRole admin (actor_id 5)
P1=$(jq -n --argjson rc "$REQUIRED_CHECKS" '{
  name: "NEBA Main Branch Protection",
  target: "branch",
  enforcement: "active",
  bypass_actors: [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always"}],
  conditions: {ref_name: {include: ["refs/heads/main"], exclude: []}},
  rules: (
    [{type: "creation"}, {type: "deletion"}, {type: "non_fast_forward"}]
    + [{type: "pull_request", parameters: {
        required_approving_review_count: 1,
        dismiss_stale_reviews_on_push: true,
        require_last_push_approval: true,
        require_code_owner_review: false,
        required_review_thread_resolution: true
      }}]
    + [{type: "required_status_checks", parameters: {
        do_not_enforce_on_create: false,
        strict_required_status_checks_pattern: false,
        required_status_checks: $rc
      }}]
  )
}')
create_ruleset "NEBA Main Branch Protection" "$P1"

# --- 2) NEBA Main Safety — NO BYPASS (canon 21761089) ------------------------
# dismiss stale reviews, 0 допълнителни approvals, thread resolution,
# bypass: Integration 10562 (exempt) — Mergify per canon
P2=$(jq -n --argjson rc "$REQUIRED_CHECKS" '{
  name: "NEBA Main Safety - NO BYPASS",
  target: "branch",
  enforcement: "active",
  bypass_actors: [{actor_id: 10562, actor_type: "Integration", bypass_mode: "exempt"}],
  conditions: {ref_name: {include: ["refs/heads/main"], exclude: []}},
  rules: [
    {type: "pull_request", parameters: {
      required_approving_review_count: 0,
      dismiss_stale_reviews_on_push: true,
      require_last_push_approval: false,
      require_code_owner_review: false,
      required_review_thread_resolution: true,
      allowed_merge_methods: ["merge","squash","rebase"]
    }},
    {type: "required_status_checks", parameters: {
      do_not_enforce_on_create: false,
      strict_required_status_checks_pattern: false,
      required_status_checks: $rc
    }}
  ]
}')
create_ruleset "NEBA Main Safety - NO BYPASS" "$P2"

# --- 3) Governance Files — Restricted Writers (push ruleset, стар id 20593243)
# Пътищата са по .mergify.yml коментара + governance/expected-repo-state.yml
P3=$(jq -n '{
  name: "Governance Files — Restricted Writers",
  target: "push",
  enforcement: "active",
  bypass_actors: [{actor_id: 5, actor_type: "RepositoryRole", bypass_mode: "always"}],
  conditions: {repository_name: {include: ["neba-token-mainnet"], exclude: []}},
  rules: [{type: "file_path_restriction", parameters: {restricted_file_paths: [
    ".github/workflows/**/*",
    ".github/CODEOWNERS",
    "CODEOWNERS",
    ".github/dependabot.yml",
    "governance/**/*",
    ".protected-policy.manifest",
    "AGENTS.md",
    "opencode.json",
    ".cursor/hooks/**/*",
    ".cursor/rules/**/*",
    "scripts/guards/**/*",
    "scripts/security/**/*",
    "scripts/ops/**/*"
  ]}}]
}')
create_ruleset "Governance Files — Restricted Writers" "$P3"

# --- 4) ORG-level GLOBAL rulesets (Team план; evaluate — не блокират) --------
if $WITH_ORG; then
  org_existing() { gh api "/orgs/$ORG/rulesets?per_page=100" --jq '.[].name' 2>/dev/null || true; }
  create_org() {
    local name="$1" payload="$2"
    if org_existing | grep -qxF "$name"; then
      echo "SKIP  org '$name' — вече съществува."
      return 0
    fi
    echo "----- ORG PAYLOAD: $name -----"
    echo "$payload" | jq .
    if $APPLY; then
      echo "$payload" | gh api -X POST "/orgs/$ORG/rulesets" --input - \
        --jq '"CREATED org id=\(.id) name=\(.name) enforcement=\(.enforcement)"'
    else
      echo "DRY-RUN (--apply за създаване)."
    fi
  }

  O1=$(jq -n '{
    name: "GLOBAL — Governance Files Protected",
    target: "push",
    enforcement: "evaluate",
    bypass_actors: [],
    conditions: {repository_name: {include: ["~ALL"], exclude: []}},
    rules: [{type: "file_path_restriction", parameters: {restricted_file_paths: [
      ".github/workflows/**/*",
      ".github/CODEOWNERS",
      "CODEOWNERS",
      ".github/dependabot.yml",
      ".github/governance/**/*",
      ".protected-policy.manifest",
      "AGENTS.md"
    ]}}]
  }')
  create_org "GLOBAL — Governance Files Protected" "$O1"

  O2=$(jq -n '{
    name: "GLOBAL — Protected Main",
    target: "branch",
    enforcement: "evaluate",
    bypass_actors: [],
    conditions: {
      ref_name: {include: ["~DEFAULT_BRANCH"], exclude: []},
      repository_name: {include: ["~ALL"], exclude: []}
    },
    rules: [
      {type: "pull_request", parameters: {
        required_approving_review_count: 1,
        dismiss_stale_reviews_on_push: true,
        require_last_push_approval: true,
        require_code_owner_review: false,
        required_review_thread_resolution: false
      }},
      {type: "deletion"},
      {type: "non_fast_forward"}
    ]
  }')
  create_org "GLOBAL — Protected Main" "$O2"
fi

echo
echo "Готово. Верификация:"
echo "  gh api repos/$ORG/$REPO/rulesets --jq '.[] | \"\\(.id) \\(.name) \\(.enforcement)\"'"
if $WITH_ORG; then
  echo "  gh api /orgs/$ORG/rulesets --jq '.[] | \"\\(.id) \\(.name) \\(.enforcement)\"'"
fi
