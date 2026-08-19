# CYPHER 4.0 — Phase 2: Operation Serendib Shield
### Onsite Capture The Flag Finals
Knowledge Partner plan prepared by GDG Sri Lanka / Women Techmakers

---

## The story

The ten teams that survived the trials are now sworn into the **Serendib Cyber Task Force**. On the morning of 5 September, an alert breaks: **Ape Ride**, the super-app half the country uses to get to work, is mid-breach. An attacker chained a small mistake into a foothold and is moving deeper. Customer data is at risk, and the attacker left something behind to hold their access.

The mission, **Operation Serendib Shield**, runs live for the competition day. Each team works the same unfolding incident: get in the way the attacker got in, follow the trail up through the cloud, reach the objective, and shut the door. The mission status board (the live leaderboard) shows the room who is closing in. Standalone challenges run alongside so every team always has something they can solve.

---

## Objective

Test finalists on realistic cloud attack chains under time pressure, in an isolated environment, with a live audience. Keep the early stages approachable so every finalist team makes progress, and reserve the separation for the later stages and the harder standalone challenges.

---

## Difficulty and support (accessible by design)

- **A gentle on-ramp.** The mission's first two stages are approachable, and one reuses the exact metadata technique from the trials, so teams start with something familiar.
- **A free hint on every challenge and every mission stage.** Hints cost zero points.
- **No hard blocks.** If a team stalls on a mission stage, a floor mentor can give a sanctioned stage-bypass hint so the team keeps moving instead of losing the whole day to one step.
- **Floor mentors.** SCTF mentors walk the room, handle infrastructure issues, and give sanctioned nudges when a challenge stalls many teams.
- **A short practice window.** The first block opens with a platform check and a practice flag so teams settle in before the real clock pressure.
- **Separation preserved.** The final mission stage, the hard standalone challenge, and solve times still decide the podium, so accessibility does not flatten the result.

---

## Format at a glance

| Item | Decision |
|---|---|
| Mode | Onsite, live, jeopardy-style with one chained storyline |
| Venue | FGS Auditorium, KDU |
| Date and time | 5 September 2026, 08:00 to 18:00 |
| Active CTF time | Roughly 5 to 6 hours within the day |
| Platform | CTFd, fresh instance, scaffolded challenge set |
| Hints | Free on every challenge and stage, plus mentor bypass hints |
| Per-team infra | On-demand isolated instances for exploitable services |
| Leaderboard | Live on the main screen, frozen for the final 45 minutes |

---

## The main mission: Operation Serendib Shield

A chained scenario in five stages. Each stage yields a flag and unlocks the next, with a gentle rising curve. A team can attempt standalone challenges at any time, and a mentor can unblock a stalled stage, so no team is ever stuck for long.

| Stage | Codename | What the team does | Difficulty | Pts |
|---|---|---|---|---|
| M1 | First Contact | Find an exposed Ape Ride asset holding initial credentials | Easy | 200 |
| M2 | Through the Door | Use the app's fetch feature to reach the metadata server and pull a token | Medium | 250 |
| M3 | Climbing Higher | Use the token's identity to act as a more privileged one | Medium | 300 |
| M4 | Into the Vault | With the higher identity, read the protected store holding customer data | Medium | 350 |
| M5 | Shut the Door | Recover the objective flag and remove the attacker's persistence artifact | Medium-Hard | 450 |

Free hints per stage:
- **M1:** recon the target's public assets. One of them holds a login you can use.
- **M2:** the same metadata trick from the trials, `169.254.169.254` through the app's fetch feature.
- **M3:** the token's identity can act as a more powerful one. List which, then switch.
- **M4:** with the higher identity, read the protected store where the customer data sits.
- **M5:** find the objective flag, then spot the one thing the attacker left behind to keep access, and remove it.

---

## Standalone challenges

Six challenges across categories, weighted toward medium so teams always have a win in reach. Same flag format, `CYPHER{...}`. Each has a free hint.

| # | Challenge | Company | Category | Difficulty | Pts |
|---|---|---|---|---|---|
| S1 | The Surfer's Secret | Arugam Waves | Cloud storage / access control | Easy-Medium | 200 |
| S2 | Twelve Factor Slip | Ceylon Kade | Serverless / env leak | Medium | 250 |
| S3 | Role Reversal | Ruhunu Bank | IAM misconfiguration | Medium | 300 |
| S6 | Audit Trail | Ape Ride | Cloud log analysis | Medium | 250 |
| S5 | The Model in the Middle | Sethsuwa Health | AI service security (optional) | Medium | 300 |
| S4 | Container Overboard | Pearl Telecom | Container escape | Hard | 400 |

S4 is the one genuinely hard standalone, kept as a separator for strong teams. S5 is optional and nods to the AI Security thread in your sessions: a model-serving endpoint that reveals its configuration when given crafted input. Include it only if an author is comfortable building it.

---

## Technical build notes

Everything runs in an isolated finals environment the SCTF owns on GCP, separate from the Phase 1 sandbox, torn down after the event.

**Main mission**
- M1: an exposed asset serving credentials for a low-privilege identity.
- M2: an app with a fetch feature reaching the real GCP metadata server, returning a scoped service account token.
- M3: that identity can act as one higher service account through impersonation.
- M4: the higher identity reads a protected secret or record holding the customer data and the next hint.
- M5: the objective flag plus a planted persistence artifact (a rogue key or scheduled job) the team must find and remove; removal reveals the final flag.

**Standalone**
- S1: enumerable GCS signed URL or object name reaching a protected object.
- S2: serverless function leaking environment variables through unsanitised input.
- S3: an IAM grant that unintentionally allows escalation to another role.
- S6: a bundle of Cloud Logging exports; the flag is recovered by tracing the attacker's actions.
- S5: a model-serving endpoint that echoes its configuration or a secret when given crafted input.
- S4: a container with a mounted socket or excessive capability enabling escape into a throwaway inner sandbox, where the flag sits.

Every service account is least-privilege, so a leaked token or key reaches only its intended next step, never project-wide access.

---

## Per-team isolation and infrastructure

For the exploitable-service items (mission stages and S2, S4, S5), each team gets its own on-demand instance via ctfd-whale, so teams cannot step on each other or share a live flag. Storage, IAM, and log challenges (S1, S3, S6) stay shared with unique per-team flags. Size the finals VM for ten teams running instances at once and load-test the day before.

---

## Scoring and the mission status board

- Dynamic decay and first-blood bonuses, same model as Phase 1. Hints stay free.
- The live leaderboard is projected as the mission status board throughout the day.
- **Freeze the board for the final 45 minutes.** Teams keep solving, but the room does not see rank changes until the reveal.

---

## Run of day (08:00 to 18:00)

| Time | Segment |
|---|---|
| 08:00 to 09:00 | Arrival, registration, seating, network and instance check |
| 09:00 to 09:30 | Opening, mission briefing, rules, and a practice flag |
| 09:30 to 12:30 | CTF block one |
| 12:30 to 13:30 | Lunch |
| 13:30 to 16:15 | CTF block two |
| 16:15 to 17:00 | Final push with the board frozen |
| 17:00 to 17:30 | Scoreboard reveal, top three confirmed |
| 17:30 to 18:00 | Awards ceremony and close |

---

## Anti-cheat and support

- Isolated competition network, with phones and personal devices governed by the handbook rules.
- Floor mentors handle infrastructure issues and give sanctioned hints, including stage-bypass hints so no team is hard-blocked.
- Per-team instances remove flag-sharing incentives; monitoring catches anomalies.
- A clear escalation path for disputes, decided by the technical panel on the spot.

---

## Awards

Top three teams recognised at the ceremony. Consider a first-blood mention for the mission's final stage, since being first to shut the door is a strong moment for the room and for post-event coverage.

---

## Ownership split

**GDG / Women Techmakers (SCTF side):** CTFd finals instance and ctfd-whale, the full mission and standalone challenges, per-team isolation, hints and mentor support, the live board, and scoring.

**KDU IEEE WIE:** venue and network, participant and delegate logistics, ceremony, judging panel coordination, and communications.

---

## What comes next

Once approved, the configuration scripts provision the finals environment: the five mission stages and their chained credentials, the standalone challenges, ctfd-whale for per-team instances, and CTFd with challenges, dynamic scoring, free hints, and the board configured. Those bash scripts are the next deliverable.
