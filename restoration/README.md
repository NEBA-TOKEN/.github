# NEBA-TOKEN GitHub — ВЪЗСТАНОВЯВАНЕ НА ГЕЙТОВЕТЕ (runbook, 2026-09-18)

> **Контекст:** Org-ът е на **Free план** от ~01–03.09.2026 (Enterprise Cloud е изтекъл).
> От **02.09.2026 22:47 UTC** ВСИЧКИ GitHub Actions runs са `startup_failure` (27 766+ мъртви run-а
> в `neba-token-mainnet`), branch protection / rulesets / CodeQL / secret scanning са **неактивни**
> (403 "Upgrade to GitHub Pro/Team"). PR-овете се merge-ват без CI валидация.
> Данните на repo-то са НЕЗАВРЕДЕНИ: 84 secrets, 5 variables, 142 workflow-а, критичните
> 6 workflow-а са `active`, canonical ruleset JSON-и са commit-нати в repo-то.

## Вече направено (2026-09-18, без плащане)

- ✅ Dependabot alerts включени за `backup-ops` (последното repo без тях).
- ✅ Automated security fixes (Dependabot) включени за 8 активни repo-та.
- ✅ `dependabot_alerts_enabled_for_new_repositories = true` на org ниво.
- ✅ Одит: workflow файловете НЕ са причина за срива (всички third-party actions са
  в org allowlist-а; allowlist-ът е здрав).
- ✅ Одит: required secrets по `governance/expected-secrets.yml` (REVIEW_BOT_TOKEN,
  STAGING_AUTO_DEPLOY_CODE) присъстват; 5/5 critical variables присъстват.
- ⛔ Org 2FA enforcement: **НЕ е включен** — `nebaqareview` е без 2FA (виж Фаза 5).

---

## Фаза 0 — САМО Bobby (billing; GATE)

1. Organization → **Settings → Billing & plans**: възстанови платен план
   (**Team** минимум за rulesets/branch protection на private repos; **Enterprise Cloud +
   GHAS** за CodeQL/secret scanning/merge queue като преди).
2. Провери payment method и дали има "payments failed" банер.
3. Actions бюджет: текущо **$2 500/месец с `prevent_further_usage: true`**
   (август: $1 306 за 217 685 Linux минути). Прецени дали бюджетът да остане —
   той е правилният предпазител, но при изчерпване пак спира CI.
4. След промяната: `gh api /orgs/NEBA-TOKEN --jq .plan` трябва да покаже `team`/`enterprise`.

## Фаза 1 — Потвърди, че Actions тръгват

```bash
gh api repos/NEBA-TOKEN/neba-token-mainnet/actions/runs?per_page=5 \
  --jq '.workflow_runs[] | "\(.created_at) \(.name) \(.conclusion)"'
# Очаква се: реални conclusion-и (success/failure), НЕ startup_failure/BuildFailed.
```

Ако още са `startup_failure`: проблемът е в плащането/бюджета (Фаза 0), не в кода.

## Фаза 2 — Self-hosted runners (Azure)

`neba-ci-01/02/03` са **offline**. Повечето PR-gate workflow-и са
`runs-on: [self-hosted, linux, x64, neba-ci]` — без тях job-овете висят в queue.

1. Стартирай Azure VM-овете (resource group по RUNBOOK-ите в `docs/ops/` на mainnet).
2. Провери:
```bash
gh api repos/NEBA-TOKEN/neba-token-mainnet/actions/runners \
  --jq '.runners[] | "\(.name) \(.status)"'   # очаква се: online
```
3. Ако runner service-ът не се вдига: `sudo systemctl start actions.runner.*` на VM-а
   или re-register по `docs/ops/` инструкциите.

## Фаза 3 — Security features (GHAS)

След Enterprise + GHAS лиценз:

1. Org → Settings → Code security: включи **Code Security** и **Secret Scanning**
   (+ **push protection**) за `neba-token-mainnet` и останалите активни repo-та.
2. Провери:
```bash
gh api repos/NEBA-TOKEN/neba-token-mainnet --jq .security_and_analysis   # не трябва да е null
gh api repos/NEBA-TOKEN/neba-token-mainnet/secret-scanning/alerts?state=open --jq length
gh api "repos/NEBA-TOKEN/neba-token-mainnet/code-scanning/alerts?state=open" --jq length
```
3. Пусни CodeQL workflow-ите (те са в repo-то, ще тръгнат сами при следващ PR/push).

## Фаза 4 — Branch protection / rulesets

Каноничните дефиниции са commit-нати в `neba-token-mainnet`:
- `docs/github/MERGE_QUEUE_RULESET_CANON_14910183.json` — „NEBA Main Branch Protection"
  (PR: 1 approve + thread resolution; required checks: **FAST-LITE Summary**,
  **Secrets Scan Summary**; bypass: RepositoryRole admin).
- `docs/github/MERGE_QUEUE_RULESET_CANON_21761089.json` — „NEBA Main Safety - NO BYPASS"
  (dismiss stale reviews; Integration 10562 exempt; същите required checks).
- Governance push ruleset „Governance Files — Restricted Writers" (стар id 20593243,
  repo-wide file_path_restriction; bypass: RepositoryRole admin транзиционно).
- Org rulesets (Team план): „GLOBAL — Governance Files Protected" (push, evaluate)
  и „GLOBAL — Protected Main" (branch, evaluate) — дефиниции в
  `reports/github-stability/GLOBAL_RULESETS.md` на mainnet.
- Merge-queue manifests за `.github`, `backup-ops`, `neba-website-redesign`:
  `config/github-rulesets/*.merge-queue.json` на mainnet.

**Приложи с:** `restoration/apply-mainnet-rulesets.sh` (dry-run по подразбиране;
`--apply` след преглед). Скриптът първо чете live rulesets и НЕ дублира съществуващи.

Внимание: възможно е при upgrade старите rulesets да се реактивират сами —
затова скриптът е idempotent (проверява по име преди създаване).

```bash
gh api repos/NEBA-TOKEN/neba-token-mainnet/rulesets --jq '.[] | "\(.id) \(.name) \(.enforcement)"'
```

Нататък по канон: `docs/ops/BRANCH_PROTECTION_SETUP.md` и `.mergify.yml`
(Mergify е единственият merger на main; native queue е изключена нарочно).

## Фаза 5 — 2FA на org ниво

`nebaqareview` (member) е **без 2FA** → org enforcement не може да се включи.

1. Bobby: включи 2FA за акаунта `nebaqareview` (login в GitHub → Settings → 2FA).
2. После:
```bash
gh api -X PATCH /orgs/NEBA-TOKEN -F two_factor_requirement_enabled=true \
  --jq .two_factor_requirement_enabled   # очаква се: true
```

## Фаза 6 — Верификация на CI

1. Trigger на governance drift watchdog-а:
```bash
gh workflow run github-governance-drift.yml --repo NEBA-TOKEN/neba-token-mainnet
gh run list --repo NEBA-TOKEN/neba-token-mainnet --limit 5
```
2. Отвори тестов PR → задължително: `FAST-LITE Summary` + `Secrets Scan Summary`
   трябва да са required и да тръгват.
3. Провери Mergify: org → Settings → Integrations; `merge-queue` лентите да не са paused.
4. `gh api graphql` rollup на main трябва да стане SUCCESS след зелен run.

## Фаза 7 — Backlog след възстановяване

- **Dependabot PR-и** (стоят от 22.08–01.09): `neba-fe-working-latest` (#76–#93),
  `neba-token-development` (#19–#22), `openclaw-neba-setup` (#61–#65), `backup-ops` (#1).
  Refresh-ни ги (`@dependabot rebase`) и ги мержи през нормалния QA flow.
- **Supabase Preview** check-ът на main fail-ва (`failed to connect to postgres … FATAL`) —
  провери Supabase integration / preview branch DB.
- **Ретроспекция на merge-ите без CI (02–18.09):** ~150+ PR-а са merge-нати без валидация.
  След като CI тръгне: пусни пълен `Vitest Full` + `TypeScript Check` + build върху main
  и при провал — bisect по merge-натите PR-и от периода.

---

*Генерирано от OpenCode аудит 2026-09-18. Източници: GitHub API forensics +
canonical файлове в `neba-token-mainnet` (governance/, docs/github/, reports/github-stability/).*
