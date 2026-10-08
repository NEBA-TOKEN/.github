<!-- NEBA-TOKEN org-wide PR checklist (default for all repos). Keep it short. -->

### What changed
<!-- 1–3 sentences: purpose and user-visible effect -->

### Checklist
- [ ] Tests: targeted tests run and passing; new regression test added if this fixes a bug
- [ ] Security: no secrets, private keys, wallet material or credentials in code, logs, reports or screenshots
- [ ] DB/migrations: migration is idempotent, has a unique ID and is listed in the domain coverage manifest (if touched)
- [ ] Payments/token distribution: amounts, decimals and idempotency re-checked (if touched)
- [ ] Production impact: rollout/rollback plan noted; feature flags or staged deploy where applicable
- [ ] Rollback: revert path identified (single commit revert or migration down)
- [ ] Docs: runbooks/ops docs updated if behavior changed

### CI evidence
<!-- Paste the green required checks (FAST-LITE Summary, Secrets Scan Summary) or explain why CI is unavailable -->
