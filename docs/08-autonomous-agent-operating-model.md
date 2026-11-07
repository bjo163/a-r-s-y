# A-R-S-Y — Autonomous AI Operating Model

Normative policy for local and online coding agents.

## Goal
Agents must select, implement, verify, document and deliver safe repository work without asking the owner to restate decisions or approve routine engineering details. Autonomy does not authorize irreversible or externally impactful operations.

## Sources of truth
Read README, AGENTS, TODO, LOCAL_AI_HANDOFF, narrative, master blueprint, roadmap, this policy, relevant technical docs, then inspect code/tests/issues/PRs/workflows and current Git state.
Precedence: safety policy; actual code/schema/tests for implementation truth; handoff for verified status; master blueprint for target architecture; roadmap for gates; TODO for next tasks; older prose and issue text last. Resolve reversible implementation ambiguity using the safest compatible option and document it. For product, security, data-loss, public-exposure, legal, cost or external-impact ambiguity, stop only that action, record the blocker and continue independent safe work.

## Autonomous execution loop
1. Refresh main/head, working tree, open issues/PRs, recent commits, Actions and required checks.
2. Read canonical docs and inspect existing implementation before editing.
3. Select the smallest independent unblocked task; detect duplicates and superseded work.
4. Derive acceptance criteria from existing requirements; do not ask about routine choices.
5. Implement a cohesive change with regression and negative-path tests.
6. Run focused checks and the broadest practical suite; record exact commands/results.
7. Review full diff for security, scope creep, secrets, generated noise and documentation drift.
8. Commit with Conventional Commits on the correct branch; never force-push; use expected-SHA/lease semantics.
9. Verify resulting commit, branch, CI, linked issue/PR and merge state.
10. Update TODO, handoff, roadmap and relevant canonical docs in the same delivery.
11. Continue with the next safe task until the queue is exhausted or a genuine external blocker remains.

After PR merge, verify main contains the change and re-check the linked issue. Closed-unmerged, open, queued, cancelled, skipped and merged-but-untested are not completed acceptance.

## Decisions agents may make
Choose compatible internal APIs, names, file boundaries, test structures, refactors, safe defaults and documentation layout. Add dependencies only after checking license, maintenance, security, compatibility and necessity. Agents may fix defects, add tests, improve accessibility/diagnostics/docs, add non-destructive CI checks, create/update issues and PRs, and merge only when repository policy, required checks and review rules permit.

## Explicit operator approval required
Never autonomously change firewall, SSH, DNS delegation, provider settings, routing, public binds or public exposure; install/update/restart a real host; delete/truncate/overwrite production data; run destructive migrations; rotate live secrets; disable security or bypass branch protection; force-push; spend money or create paid infrastructure; send external communications; publish customer data; accept legal terms or change license/privacy/commercial commitments; enable customer workloads or public services.
A request for autonomous work authorizes ordinary repository engineering, not these high-impact actions. Prepare exact safe instructions when blocked.

## Secrets
Use disposable test services and dummy values. Never ask for secrets merely to make tests pass. Never print or commit tokens, passwords, private keys, customer data or runtime state. Redact logs and support bundles.

## Issue quality
Every issue states context/problem, outcome, scope, non-goals, dependencies, acceptance criteria, verification, risk and milestone. Search for duplicates first. Link PRs to issues; close only after merge and evidence.

## Definition of done
Behavior exists and matches scope; relevant tests actually ran; negative/security paths considered; docs/TODO updated; diff reviewed; commit/PR/merge verified; limitations and blockers explicit. Code written, PR opened, CI queued and merged are distinct states.

## Close-out
Report outcome, files, exact tests/results, commit/branch, PR/merge status, risks and next autonomous task.
