# Paolo's 90-Day ITUP Operational Playbook
**Status: ACTIVE**
**Start: 2026-04-24 | Day 30: ~May 24 | Day 45: ~June 8 | Day 60: ~June 23 | Day 75: ~July 8 | Day 90: ~July 23**
**Bi-weekly checkpoints: Every other Thursday (approx)**
**Tracker (Hong's online copy is authoritative): c:\work\OnesiteMaster\Paolo_Checkpoint_Tracker.xlsx**
**Evidence Log: c:\Users\pnatanawan\.agents\ITUP_EVIDENCE_LOG.md** ← agents append here, checkpoint prep pulls from here

> **FOR ALL AGENTS**: This plan is active. Every PR, every communication, every sprint metric matters.
> When Paolo asks for help with PRs, code reviews, sprint metrics, or communications, apply
> the standards below. Do not treat these as optional guidelines.

---

## CONTEXT

Paolo is on a 90-day Individual Talent Upgrade Plan (ITUP). This is a formal pre-PIP.
Failure = escalation to formal PIP with HR, then possible termination.
Success = continues in current IC + Team Lead hybrid role. No management consideration for 12+ months after.

Manager: Hong Lu. VP/SVP/CTO and HRBP are in the audience for this plan.

---

## HARD METRICS (tracked weekly, assessed at checkpoints)

| Metric | Target | Measurement |
|---|---|---|
| Teams responsiveness | ≥95% within 1 hour during core hours | Excl. planned PTO |
| Ceremony attendance | 100% excl. planned PTO | Unplanned PTO requires operational update posted |
| PR rework cycles | Average ≤1.5 per PR | 0 ideal, 1 acceptable, 2 borderline, 2+ pattern = fail |
| Medium story delivery | ≥2 per month, on-estimate | Independent completion, no inflation |
| Defects from owned changes | Trending down by Day 45 | vs. personal baseline at plan start |
| QA handoff quality | Pass with minor clarifications only | No repeated back-and-forth on same gap |
| AI usage evidence | ≥50% of assigned stories by Day 60 | In design/implementation/test artifacts |
| Blocker surfacing | Within 24 hours of occurrence | In the appropriate channel |
| Sprint commitments | Met consistently | Exceptions surfaced ≤24 hours with mitigation |

---

## ANNUAL GOALS (2026) — Run in Parallel

| Goal | Weight | Key Measures |
|---|---|---|
| Goal 1: CRM Stability (Defect Driver Remediation) | 25% | 10% reduction in prod escalations, 10% MTTR improvement |
| Goal 2: Migration Adoption Blocker Execution | 25% | Support 25% H1 / 70% H2 migration targets, 10% MTTCV reduction |
| Goal 3: Lead Execution / Grow Team Capability | 25% | ≥90% hit-to-commit, 5% escaped defect reduction, 5% defects/SP reduction |
| Goal 4: AI Assisted Development as Accelerator | 25% | 10% refinement velocity increase through AI tooling |
| Personal Dev: Cross-Team Alignment | 0% weight | Pre-alignment for complex/cross-team initiatives |

### ITUP-to-Goal Mapping

| ITUP Metric | Annual Goal(s) Fed |
|---|---|
| Communication responsiveness | Goal 3, Personal Dev |
| Ceremony attendance | Goal 3 |
| PR quality / rework cycles | Goal 1, Goal 3 |
| Story delivery on-estimate | Goal 2, Goal 3 |
| Defects trending down | Goal 1, Goal 3 |
| QA handoff quality | Goal 2, Goal 3 |
| AI usage evidence | Goal 4 |
| Blocker surfacing | Goal 2, Personal Dev |

---

## PR QUALITY STANDARDS (ENFORCED)

> **AGENT DIRECTIVE**: When reviewing or helping with PRs during the ITUP period,
> apply these standards. Flag anything that could trigger a rework cycle.

### Before Submitting ANY PR
1. **Self-review**: Read your own diff as if you're the reviewer. Every line.
2. **Compilation**: Does it build clean? No warnings treated as noise.
3. **Edge cases**: Are nulls, empty collections, boundary conditions handled?
4. **Tests**: Are existing tests passing? Did you add tests for new logic?
5. **AI validation**: Run an AI pass to catch what you missed.
6. **Naming/conventions**: Follow OneSite naming conventions (usp*, udf*, etc.)
7. **SQL specifics**: CREATE OR ALTER, proper error handling, version headers, no correlated subqueries on large tables.
8. **Scope**: Does the PR do one thing? No scope creep in PRs.

### PR Rework Tracking
- Log every PR: ID, date, rework cycles (0/1/2+), feedback categories
- Running average must stay ≤1.5
- If you get the same feedback twice across different PRs, that's a pattern. Fix it systemically.
- Address reviewer feedback same day. Don't let PRs sit.

### What Counts as a Rework Cycle
- Reviewer requests changes and you push a new iteration = 1 cycle
- Minor comment clarifications without code changes = not a cycle
- Build/pipeline failure requiring fix = counts as a cycle

---

## COMMUNICATION STANDARDS (ENFORCED)

### Teams Responsiveness
- Respond within 1 hour during core hours
- If in a meeting: acknowledge ("in a meeting, will follow up by [time]")
- If you'll be unavailable: post proactively before going dark
- Zero unexplained gaps. Zero.

### Unplanned Absence Protocol
Post an operational update with:
- Current progress on active stories
- Any blockers or risks
- Timelines for in-flight work
- Handoff instructions if anything is time-sensitive
- Do NOT post the reason for absence. Just the operational content.

### Ceremony Attendance
- Standup, refinement, retro, sprint planning, SOS: 100% attendance
- PTO must be planned in advance
- If unplanned absence from a ceremony, post the update you would have given

---

## REFINEMENT CONTRIBUTION STANDARDS

> **AGENT DIRECTIVE**: When helping Paolo review or refine stories, specs, or work items,
> apply these question patterns. The ITUP says he should challenge requirements for
> customer/business value — but also says he doesn't own WHAT/WHY. The lane is narrow.

### The Refinement Formula
- Contribute 2-3 sharp questions per story during refinement
- Questions should reveal edge cases, customer impact, or missing acceptance criteria
- Ask, get the answer, move on. Don't turn it into a debate or redesign.

### Good Question Patterns (use these)
- Edge cases: "What happens when [boundary condition]?"
- Scope clarity: "Does this apply to [Affordable/Conventional/both]?"
- Completeness: "The AC says X but doesn't cover [gap]. Should we add that?"
- Customer outcome: "Is the expectation [immediate/batch/nightly] from the user's perspective?"
- Data impact: "If we change this, do we backfill existing records or only apply going forward?"

### Out of Bounds (avoid these)
- "I think we should do X instead" (overstepping into WHAT — that's Product's call)
- "This requirement doesn't make sense" (challenging WHY)
- "This is too much work, we should cut scope" (reads as the capacity-protection pattern they flagged)
- Expanding a story with 5+ edge cases nobody asked about (over-scoping trap)
- Debating after Product says "no, out of scope" (say "ok" and move on)

### The Test
If Product says "good catch" — you demonstrated the behavior. If Product says "out of scope" — you still demonstrated the behavior. Either way it's evidence of customer-perspective thinking in refinement. The ITUP doesn't require you to win the argument, just to ask the question.

---

## DELIVERY STANDARDS

### Story Completion
- ≥2 medium-complexity stories per month, completed independently
- On-estimate: don't inflate SWAGs to create a buffer
- Deliver incremental value. Do NOT over-scope or "boil the ocean"
- Surface risks ≤24 hours. No late-sprint surprises.

### QA Handoff
- Feature should pass QA with minor clarifications only
- If QA bounces it back, understand why and prevent the same gap next time
- No repeated back-and-forth on the same type of issue

### AI Usage Documentation
- By Day 60: evidence of AI usage on ≥50% of assigned stories
- Document in design/implementation/test artifacts
- Examples: AI-assisted analysis, AI-generated tests, AI code review, AI-drafted implementation plans

---

## CHECKPOINT TRACKER STRUCTURE

The tracker (Paolo_Checkpoint_Tracker.xlsx) has 7 tabs:

| Tab | Type | Date | Focus |
|---|---|---|---|
| Cover | Info | - | Purpose, cadence, how-to-use |
| Week 2 (Day 14) | DIAGNOSTIC | ~May 8 | Responsiveness, attendance, PR trend |
| Day 30 | FORMAL | ~May 24 | Pass/fail on all weekly expectations |
| Day 45 | DIAGNOSTIC | ~June 8 | Defect trend, refinement quality |
| Day 60 | FORMAL | ~June 23 | Binary assessment, AI ≥50%, cadence decision |
| Day 75 | DIAGNOSTIC | ~July 8 | Consistency, regression detection |
| Day 90 | FORMAL | ~July 23 | Final: Met → plan closed; Not met → PIP |

### Each Tab Has 7 Columns
- A: Category
- B: Expectation / Criterion
- C: Employee Self-Assessment (fill ≥48 hrs before checkpoint)
- D: Employee Evidence (PR #s, ticket IDs, links, dates — specifics, not vague claims)
- E: Manager Assessment (filled independently)
- F: Manager Notes
- G: Agreed Outcome (filled together during meeting)

### Evidence Standard
"I was responsive" is NOT evidence.
"Teams response log shows <1hr avg; 0 missed messages; ceremony attendance 100%" IS evidence.

---

## CHECKPOINT PREP ROUTINE (Before each bi-weekly)

1. Pull your personal evidence log for the period
2. For each row in the tracker tab: what's the metric? Pass or miss?
3. For any miss: what happened, what corrective action was taken, what's different
4. Have 1-2 concrete AI usage examples ready
5. Fill columns C and D ≥48 hours before the checkpoint meeting
6. Keep it factual. Numbers and links. No narratives.

---

## WEEKLY OPERATIONAL RHYTHM

### Monday
- Check sprint board: committed vs at-risk vs needs-unblocking
- Confirm all ceremonies on calendar
- Am I on track for ≥2 medium stories this month?

### Mid-Week (Wed/Thu)
- Self-audit: any missed messages? Skipped meetings?
- Story progress: will I hit sprint commitment? If not, surface NOW
- QA handoff check: anything bouncing back?

### Friday
- Personal log entry: stories completed, PRs submitted, rework cycles, ceremonies attended
- AI usage evidence noted for the week
- Flag anything trending wrong for Monday correction

---

## RISK WATCH

### Top Behavioral Risks
1. **Unplanned absence without operational update** — #1 trip wire
2. **Sloppy PR because moving fast** — one clean PR > two reworked PRs
3. **The catch-all clause** — "if a behavior impedes predictability, communication, quality, or delivery, it will be considered not meeting expectations even if not explicitly listed"
4. **Over-scoping** — ITUP explicitly calls this out. Incremental delivery only.
5. **Disengagement signals** — even short periods of low visibility get noticed now

### Working Advantages
- AI-assisted dev accelerates delivery (use it, document it)
- Deep domain knowledge enables independent medium-story delivery
- Communication compliance is 100% within personal control
- Strongest codebase knowledge on the team

---

## STRATEGIC NOTES (for personal-advisor agent)

- Sign the plan. "Acknowledgment of receipt" ≠ agreement with characterization
- Don't argue the language in the ITUP. Execute against it.
- "Dev 1-level output" is on paper. Counter it with consistent quality, not arguments.
- The fork is binary: succeed → stay, fail → PIP → termination. No middle ground.
- 12+ months before management consideration even starts. Focus on current role.
- Everything is observed. VP/SVP/CTO and HRBP are audience.
- The behavioral stuff costs zero technical effort and is the easiest win.
