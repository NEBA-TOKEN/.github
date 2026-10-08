# NEBA TOKEN — Organization Security Policy

This is the default security policy for all repositories in the
**NEBA-TOKEN** organization. Repositories may provide a more specific
`SECURITY.md`, which takes precedence for that repository.

## Reporting a vulnerability

- **Do not open a public GitHub issue, discussion or pull request for a
  suspected vulnerability.**
- Email: **security@nebatoken.com**
- Include: affected component/repository, reproduction steps or proof of
  concept, impact assessment, and a way to contact you.

## What to expect

1. Acknowledgement within **48 hours**.
2. Triage and severity classification (P0–P3) within 5 business days.
3. Coordinated fix and disclosure timeline agreed with the reporter.
4. Credit in the fix announcement unless you prefer to stay anonymous.

## Scope

In scope: NEBA Token web platform, payment and purchase flows, smart-contract
interfaces, token distribution and vesting logic, referral program logic,
KYT/compliance paths, and this organization's CI/CD governance.

Out of scope: social engineering, physical attacks, third-party services not
operated by NEBA TOKEN, and denial-of-service against shared infrastructure.

## Safe harbor

Research performed in good faith against your own accounts or staging
environments, without accessing other users' data or production funds, will not
be pursued legally by NEBA TOKEN.

## Disclosure handling

- We never ask reporters to delete their findings.
- We do not share reporter identities outside the security response team.
- Public disclosure is coordinated; minimum embargo is 90 days or until a fix
  is released, whichever comes first.

*Operational note for maintainers: security findings are tracked privately;
fixes follow the normal protected-branch and QA review process. Never commit
credentials, private keys or wallet material in reports or evidence.*
