# ITUP Evidence Log
**Purpose:** Running operational data that feeds Hong's checkpoint tracker (columns C & D).
**Updated by:** Any agent session. PR sessions feed PR data. Sprint sessions feed delivery data. Etc.
**Consumed by:** Checkpoint prep routine (ÃƒÂ¢Ã¢â‚¬Â°Ã‚Â¥48 hrs before each bi-weekly).

> **AGENT DIRECTIVE**: When completing work that generates ITUP-relevant evidence,
> append to the appropriate section below. Use the exact format shown. Do not reorganize
> or rewrite existing entries ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â only append new ones or update the current week's section.

---

## HOW TO USE

- Each week gets a section under the relevant metric
- Agents append entries in the format shown
- Before each checkpoint, the personal-advisor session rolls up the data into tracker columns C & D
- Keep entries factual: numbers, IDs, dates, links. No narratives.

---

## PR REWORK TRACKING

> Fed by: PR review sessions, os-db-approver, any session that submits or reviews PRs

### Day 0 Baseline (9-Month IC Tenure: Jul 2025 - Apr 2026)
Established: 2026-04-24 | Source: TFS API thread analysis

**9-Month Aggregate**
- Substantive PRs authored: 34
- Total rework cycles: 17
- **Average rework cycles: 0.50** (target ÃƒÂ¢Ã¢â‚¬Â°Ã‚Â¤1.5)
- Clean first-pass (0 rework): 23/34 (68%)
- PRs at 2+ cycles: 4/34 (12%)
- Architect-level redos: **0**

**2025 H2 (Jul-Dec 2025)**: 17 PRs, 3 rework cycles, 0.18 avg, 82% clean
**2026 Q1-Q2 (Jan-Apr 2026)**: 17 PRs, 14 rework cycles, 0.82 avg, 53% clean

Trend note: 2026 increase driven by complexity (PII consolidation, async patterns, SQL precision), not quality regression. Zero architectural reversals in 34 PRs.

**2025 H2 Per-PR Detail**
| PR | Date | Rework | Category |
|---|---|---|---|
| 353735 | Aug 08 | 1 | Compact code + rename (Peter, Muntyaz) |
| 353775 | Aug 08 | 0 | Clean |
| 354235 | Aug 12 | 0 | Clean |
| 354539 | Aug 13 | 0 | Clean |
| 364387 | Oct 07 | 0 | Clean |
| 365585 | Oct 14 | 1 | Add NOLOCK (Ganesan). 54 iters = merge conflicts. |
| 368312 | Oct 28 | 0 | Clean |
| 370059 | Nov 04 | 0 | Clean (WMU) |
| 370121 | Nov 04 | 0 | Clean (WMU) |
| 370295 | Nov 04 | 0 | Clean (WMU) |
| 370528 | Nov 05 | 0 | Clean (WMU) |
| 370576 | Nov 05 | 0 | Clean |
| 370579 | Nov 05 | 0 | Clean |
| 370669 | Nov 06 | 1 | Add change history (Ganesan) |
| 373621 | Nov 18 | 0 | Clean |
| 374574 | Nov 20 | 0 | Clean (15 iters, 0 human threads) |
| 378666 | Dec 15 | 0 | Clean |

**2026 Per-PR Detail**
| PR | Date | Rework | Category |
|---|---|---|---|
| 385881 | Jan 30 | 0 | Clean |
| 389004 | Feb 13 | 2 | AngularJS (scope/vm, LD placement) |
| 390850 | Feb 20 | 0 | Clean |
| 393698 | Mar 6 | 1 | LD flag wrapping |
| 393958 | Mar 9 | 1 | Missing braces |
| 394206 | Mar 10 | 0 | Clean |
| 397535 | Mar 25 | 0 | All deferred to Phase 3 |
| 398264 | Mar 28 | 3 | Async fixes + design extension |
| 398415 | Mar 30 | 0 | Clean |
| 398620 | Mar 31 | 0 | Clean |
| 399242 | Apr 2 | 0 | Clean |
| 399345 | Apr 2 | 0 | Clean |
| 399383 | Apr 2 | 0 | Clean |
| 399397 | Apr 2 | 4 | PII consolidation (pattern enforcement) |
| 400975 | Apr 9 | 2 | SQL quality (TOP 1, VARCHAR lengths) |
| 404185 | Apr 23 | 1 | Null handling |
| 404574 | Apr 24 | 0 | Clean |

### Active Tracking (ITUP Period: Apr 24 - Jul 23, 2026)

<!-- Format per PR:
| PR # | Date | Story/Bug | Rework Cycles | Feedback Summary | Same-Day Response? |
-->

| PR # | Date | Work Item | Rework Cycles | Feedback Summary | Same-Day Response |
|---|---|---|---|---|---|

**Running Average:** _no ITUP-period PRs yet_

---

## TEAMS RESPONSIVENESS

> Fed by: manual Friday entries or any session reviewing communication patterns

### Weekly Log

<!-- Format per week:
| Week Of | Messages Received (core hrs) | Responded <1hr | Missed/Late | % On-Time | Notes |
-->

| Week Of | Msgs (core hrs) | <1hr | Missed/Late | % | Notes |
|---|---|---|---|---|---|
| _example_ | _2026-04-28_ | _23_ | _22_ | _1_ | _95.7%_ | _late reply was during dentist appt, posted proactively_ |
| 2026-04-17 | 6 | 4 | 2 | 66.7% | Late: Leelakrishna Balu (in: Koopalings : 26.Q1 Daily Scrum) Thu 15:43(1346.6m), Leelakrishna Balu (in: Sprint Retrospective) Wed 13:27(423.1m) |

---

## CEREMONY ATTENDANCE

> Fed by: manual Friday entries

### Weekly Log

<!-- Format per week:
| Week Of | Ceremonies Scheduled | Attended | Missed | Reason if Missed |
-->

| Week Of | Scheduled | Attended | Missed | Reason |
|---|---|---|---|---|
| _example_ | _2026-04-28_ | _5_ | _5_ | _0_ | _ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â_ |

---

## AZD RESPONSIVENESS

> Fed by: `_itup_azd_responsiveness.ps1` (weekly run)
> Tracks: PR review response time, @mention response, PR comment response on own PRs
> Target: respond within 8 business hours (same business day) for all dimensions
> Core hours: 9AM-6PM PHT (UTC+8), Mon-Fri

### Weekly Log

<!-- Format per week:
| Week Of | AZD Interactions | On-Time | Late/Pending | % (PRrev/Mention/PRcmt) | Notes |
-->

| Week Of | Interactions | On-Time | Late/Pending | % (PRrev/Mention/PRcmt) | Notes |
|---|---|---|---|---|---|

---

## STORY DELIVERY

> Fed by: sprint close sessions, work-item-updater, os-pme-coordinator

### Monthly Targets: Ã¢â€°Â¥2 medium-complexity stories, on-estimate, independent

<!-- Format per story:
| Story ID | Title (short) | Complexity | Estimate | Actual | On-Estimate? | Independent? | Sprint |
-->

### Pre-ITUP Baseline (Sprints 26.07 - 26.08, Mar 25 - Apr 21)

| Story ID | Title | Complexity | Est | Actual | On-Est? | Independent? | Sprint |
|---|---|---|---|---|---|---|---|
| 2765423 | US-A1: Duration aggregation rules (rental + employment) | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.07 |
| 2776134 | US-A0: Feature flag wiring + branch setup | Low | 0 SP | 0 SP | Yes | Yes | Sprint 26.07 |
| 2784428 | NFS: PII Encryption Console Tool Technical Design | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.07 |
| 2792234 | RTW: Dynamic Security Deposit - Online Leasing | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.07 |
| 2792236 | RTW: RHEL NOE Skip Status (site name blank) | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.07 |
| 2792237 | RTW: Unable to change Leasing Consult on Prospect | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.07 |
| 2792219 | RTW: Missing Phone Number Merge Fields | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.08 |
| 2792221 | RTW: Add American Samoa to State Dropdown | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.08 |
| 2792222 | RTW: Apostrophe Backwards in Name | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.08 |
| 2792230 | RTW: CityStZip Combo Merge Field | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.08 |
| 2792241 | RTW: Unable to re-quote change move-in date | Med | 3 SP | 3 SP | Yes | Yes | Sprint 26.08 |
| 2826822 | Investigation: Reserved Quote Select Unit behavior | Low | 1 SP | 1 SP | Yes | Yes | Sprint 26.08 |

**Pre-ITUP Sprint Summary:**
- Sprint 26.07: 6/6 delivered (100%), 15 SP, 5 medium+, 0 bounces, 0 defects
- Sprint 26.08: 6/6 delivered (100%), 16 SP, 5 medium+, 0 bounces, 0 defects

### ITUP Period (Apr 24 - Jul 23, 2026)

| Story ID | Title | Complexity | Est | Actual | On-Est? | Independent? | Sprint |
|---|---|---|---|---|---|---|---|

### Monthly Rollup

| Month | Stories Completed | Medium+ | On-Estimate | Target Met? |
|---|---|---|---|---|
| Apr 2026 (pre-ITUP) | 12 (2 sprints) | 10 | 12/12 | Yes |
| May 2026 | | | | |
| Jun 2026 | | | | |
| Jul 2026 | | | | |

---

## DEFECTS FROM OWNED CHANGES

> Fed by: any session tracking bugs, PME coordinator, sprint reviews

### Day 0 Baseline (6-Month Window: Oct 2025 - Apr 2026)
Established: 2026-04-25 | Source: TFS WIQL query (AssignedTo = @me AND ever @me)

**Important Distinction**: The ITUP metric is "defects from owned changes" (i.e., bugs introduced by my code). Most bugs below are **PME triage assignments** (pre-existing production issues assigned for investigation/fix), NOT regressions from my changes.

**Defects From My Code Changes: 0**
- No bugs in the 6-month window are linked as regressions from my PRs or stories
- No QA-found defects from my story implementations during this period
- Bug 2783971 was proactively created by me (SSRF security finding in Scheduler.PostXML)

**PME Defect Workload (assigned to me for triage/fix):**

| Bug ID | Sev | State | Created | Title (short) | Escaped? | Notes |
|---|---|---|---|---|---|---|
| 2569382 | 2-High | Closed | Oct 14 | Required Field status "Complete" w/ LD ON | Yes (PME) | Fixed in Sprint 25.25 |
| 2571328 | 3-Med | Defined | Oct 16 | Phone number formatting in Contact Level Details | Yes (PME) | Still open, Sprint 26.10 |
| 2578101 | 2-High | Closed | Oct 22 | Pricing not visible in Knock Quoting | Yes (PME) | Reassigned to Gopinath |
| 2603947 | 2-High | Closed | Nov 14 | Unable to Select Unit (CheckHHMembers) | Yes (PME) | Reassigned to Jomar |
| 2603953 | 2-High | Removed | Nov 14 | Oops - CheckHHMembers (dup) | Yes (PME) | Duplicate, removed |
| 2603955 | 2-High | Removed | Nov 14 | Error Selecting Unit (CheckHHMembers dup) | Yes (PME) | Duplicate, removed |
| 2604066 | 3-Med | Defined | Nov 15 | Unit not found on dry run sync | Yes (PME) | Reassigned to Sateesh |
| 2606253 | 2-High | Closed | Nov 17 | Could not advance property date | Yes (PME) | Fixed in Sprint 25.25 |
| 2617135 | 2-High | Closed | Nov 20 | Missing Required Fields modal (WMU) | Yes (PME) | Reassigned to Rafi |
| 2620153 | 3-Med | Closed | Nov 24 | Required demographics blocking online leasing | Yes (PME) | Reassigned to Arnab |
| 2620398 | 3-Med | Removed | Nov 25 | Unable to add waitlist applicant | Yes (PME) | Removed |
| 2620565 | 3-Med | Closed | Nov 25 | Emergency Contacts not saving | Yes (PME) | Reassigned to Christian |
| 2621966 | 3-Med | Closed | Nov 26 | Prospect Required Fields show Incomplete | Yes (PME) | Reassigned to Brandon |
| 2622489 | 3-Med | Closed | Nov 26 | Emergency Contact Not Saving (tracking) | Yes (PME) | Reassigned to Suvarnamadhuri |
| 2648278 | 2-High | Closed | Dec 18 | SQL syntax error near 'group' | Yes (PME) | Fixed in Sprint 25.26 |
| 2783971 | 3-Med | Defined | Mar 17 | SSRF in Scheduler.PostXML (security) | N/A | Proactively created by me |

**Monthly PME Volume:**

| Month | Bugs Touched | Sev 2 (High) | Sev 3 (Med) | Notes |
|---|---|---|---|---|
| Oct 2025 | 3 | 2 | 1 | Required Fields + Knock Quoting |
| Nov 2025 | 10 | 5 | 5 | CheckHHMembers cluster + Emergency Contacts |
| Dec 2025 | 1 | 1 | 0 | SQL syntax fix |
| Jan 2026 | 0 | 0 | 0 | |
| Feb 2026 | 0 | 0 | 0 | |
| Mar 2026 | 1 | 0 | 1 | Security finding (proactive) |
| Apr 2026 | 0 | 0 | 0 | |

**Severity Breakdown (16 total):**
- Sev 2 (High): 9 (56%)
- Sev 3 (Medium): 7 (44%)
- Sev 1 (Critical): 0

**Baseline Summary:**
- Defects from my code changes: **0 in 6 months**
- PME triage workload: **16 bugs touched**, peak in Nov 2025 (Required Fields cluster)
- Nov 2025 cluster was a single root cause (CheckHouseholdMembersCompleteApplication) triaged across multiple PMEs
- 3 fixed by me directly (2569382, 2606253, 2648278), rest reassigned after triage

### Tracking (ITUP Period: Apr 24 - Jul 23, 2026)

<!-- Format per defect:
| Bug ID | Date Found | Source PR/Story | Severity | Root Cause (1-line) | Escaped to Prod? |
-->

| Bug ID | Date Found | Source | Severity | Root Cause | Escaped? |
|---|---|---|---|---|---|
| | | | | | |

### Trend (updated at checkpoints)

| Checkpoint | Defects This Period | vs Previous | Trend |
|---|---|---|---|
| Baseline | 0 from own code (6mo) | N/A | _starting point_ |
| Day 14 | | | |
| Day 30 | | | |
| Day 45 | | | _must be down (or sustained at 0)_ |
| Day 60 | | | _must be sustained_ |

---

## QA HANDOFF QUALITY

> Fed by: sprint sessions, QA feedback tracking

<!-- Format per handoff:
| Story/PR | QA Pass? | Bounced? | Reason if Bounced | Same Issue Repeated? |
-->

### Pre-ITUP Baseline (Sprints 26.07 - 26.08)

| Story/PR | QA Pass? | Bounced? | Reason | Repeated? |
|---|---|---|---|---|
| 2765423 | Yes | No | - | - |
| 2776134 | Yes | No | - | - |
| 2784428 | Yes | No | - | - |
| 2792234 | Yes | No | - | - |
| 2792236 | Yes | No | - | - |
| 2792237 | Yes | No | - | - |
| 2792219 | Yes | No | - | - |
| 2792221 | Yes | No | - | - |
| 2792222 | Yes | No | - | - |
| 2792230 | Yes | No | - | - |
| 2792241 | Yes | No | - | - |
| 2826822 | Yes | No | - | - |

**Baseline: 12/12 clean QA passes across 2 sprints. 0 bounces.**

### ITUP Period (Apr 24 - Jul 23, 2026)

| Story/PR | QA Pass? | Bounced? | Reason | Repeated? |
|---|---|---|---|---|

---

## PR REVIEW ACTIVITY (Quality Gatekeeping)

> Fed by: PR review sessions, os-db-approver agent, any session reviewing others' PRs
> Demonstrates: code quality leadership, cross-team contribution, Dev 4-level behavior

### Day 0 Baseline (9-Month IC Tenure: Jul 2025 - Apr 2026)
Source: TFS API by reviewerId GUID

**Aggregate Review Metrics**
- External PRs reviewed: 35 (excluding 4 self-reviews)
- PRs with substantive feedback: 16/35 (46%)
- Review threads started: 102
- Review replies: 18
- Total review interactions: 120
- Unique authors reviewed: 18+ (across multiple teams)
- Vote distribution: 28 Approved, 1 Approved w/ Suggestions, 10 No Vote

**DB Approver Role (Structured SQL Code Review)**
| PR | Author | Threads | Key Findings |
|---|---|---|---|
| 389797 | Nagesh Deshpande | 2 | MED: Route URI mismatch in IF EXISTS guard |
| 390674 | Sharvani Yellanki | 4 | CRIT: Missing parenthesis. MED: Scalar subquery, missing NOLOCK |
| 398305 | Harika Boggavarapu | 7 | MED: Missing ANSI_NULLS/GO, TOP 1 no ORDER BY, filter placement, missing NOCOUNT ON, missing Util_GrantPermit |
| 399334 | Safia Shaik | 3 | CRIT: Missing GO + Util_GrantPermit. Delta re-review approved. |
| 399960 | Kamaljit Singh | 5 | CRIT: Editing deployed static file (withdrawn after verification). MED: Non-idempotent temp proc. |
| 399915 | ShanmukhaBhargav | 3 | CRIT: Missing permission grant. Pre-existing issues documented. |
| 399935 | Saritha Katta | 2 | MED: Missing NOLOCK, NOT IN with NULL variables |
| 400636 | Nagesh Deshpande | 34 | CRIT: NULL logic bug, missing GO (x2), multi-step writes no transaction, missing permission grant. MED: Race condition, missing NOCOUNT ON (x4), missing NOLOCK, DROP+CREATE pattern, TOP 1 no ORDER BY. |
| 401410 | Dave Blommer | 12 | CRIT: Multi-step write no transaction. MED: Missing NOCOUNT ON, TOP 1 no ORDER BY, missing standard params. |
| 402509 | Phani Pallantla | 9 | CRIT: Runtime bug (missing trailing space). MED: DROP+CREATE pattern, missing changelog, missing NOLOCK, TOP 1 no ORDER BY. |

**Non-DB Reviews (Feature/API/UI)**
| PR | Author | Threads | Nature |
|---|---|---|---|
| 359258 | Ganesan | 3+2r | Async risk assessment, constant extraction, scope review |
| 360425 | Ganesan | 2+1r | Scope review, async connection pattern question |
| 360996 | Ganesan | 5+2r | NOLOCK risk analysis, transaction wrapping, error handling |
| 399859 | Marlon Rivera | 2 | Missing RETURN after early-exit, NULL audit message |
| 391145/391032 | JayAlvin/Edgar | 9 | Conflict resolution documentation |

**Defense Value:** DB Approver reviews caught CRITICAL severity bugs (NULL logic, missing transactions, syntax errors) before production. 120 total interactions = active quality leadership, not rubber-stamp approvals. Cross-team coverage (Dynamos, platform, Screening, Facilities) shows broad codebase knowledge.

### Active Tracking (ITUP Period)

| PR Reviewed | Date | Author | Threads | Key Findings | Severity |
|---|---|---|---|---|---|
| | | | | | |

---

## AI USAGE EVIDENCE

> Fed by: any session where AI tools assist with story work
> Target: ÃƒÂ¢Ã¢â‚¬Â°Ã‚Â¥50% of assigned stories by Day 60

<!-- Format per usage:
| Date | Story/Task | AI Tool/Method | What It Did | Artifact/Link |
-->

| Date | Story/Task | AI Tool | Usage | Artifact |
|---|---|---|---|---|
| 2026-04-24 | ITUP baseline establishment | Copilot agent (personal-advisor) | 9-month PR rework analysis via TFS API, thread categorization, review activity compilation, evidence log creation | ITUP_PR_BASELINE.md, ITUP_EVIDENCE_LOG.md |

### Coverage Rollup

| Month | Stories Assigned | AI-Assisted | % | Target |
|---|---|---|---|---|
| May 2026 | | | | 50% by Day 60 |
| Jun 2026 | | | | 50% by Day 60 |
| Jul 2026 | | | | ÃƒÂ¢Ã¢â‚¬Â°Ã‚Â¥50% sustained |

---

## BLOCKER SURFACING

> Fed by: any session where blockers are identified and communicated

<!-- Format:
| Date | Blocker Description | Channel Used | Time to Surface | <24hr? |
-->

| Date | Blocker | Channel | Time to Surface | <24hr? |
|---|---|---|---|---|
| | | | | |

---

## REFINEMENT CONTRIBUTIONS

> Fed by: refinement prep sessions, story review sessions

<!-- Format:
| Date | Story | Questions Asked | Product Response | Evidence Type |
-->

| Date | Story | Questions | Response | Type |
|---|---|---|---|---|
| _example_ | _2026-05-01_ | _US-99999_ | _"Does this apply to Affordable or both?"_ | _"Good catch, both"_ | _Edge case caught_ |

---

## WEEKLY FRIDAY LOG

> Quick weekly summary. Copy-paste into this section every Friday.

### Template
```
### Week of [DATE]
- Stories progressed: 
- PRs submitted: 
- PR rework cycles this week: 
- Ceremonies: X/X attended
- Teams responsiveness: ~X% on-time
- AI usage this week: 
- Blockers surfaced: 
- Anything trending wrong: 
```

### Entries

<!-- Append weekly entries below this line -->

---

## CHECKPOINT ROLLUP SUMMARIES

> Populated by personal-advisor session ÃƒÂ¢Ã¢â‚¬Â°Ã‚Â¥48 hrs before each checkpoint.
> This is what goes into columns C & D of Hong's tracker.

### Day 14 (~May 8, 2026)
_Not yet due_

### Day 30 (~May 24, 2026)
_Not yet due_

### Day 45 (~June 8, 2026)
_Not yet due_

### Day 60 (~June 23, 2026)
_Not yet due_

### Day 75 (~July 8, 2026)
_Not yet due_

### Day 90 (~July 23, 2026)
_Not yet due_
