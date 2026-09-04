# CYPHER 4.0 - Operation Serendib Shield

**Phase 2 · Onsite finals · FGS Auditorium, KDU · Organised by IEEE WIE KDU and GDG Sri Lanka**

---

## The brief

You made it through the trials. You're now sworn into the **Serendib Cyber Task Force**.

The same seven companies from Phase 1 - Ape Ride, Arugam Waves, Sethsuwa Health, Ceylon
Kade, Ruhunu Bank, LankaGov, Pearl Telecom - are back, and this time the cloud slip-ups
run deeper: SSRF chains into stolen identities, IAM misconfigurations that hand over
whole projects, containers one syscall from a host escape, and an AI assistant or two
that says more than it should. Every challenge is independent - pick your own path
through the incident, in whatever order plays to your team's strengths.

---

## The window

| | |
|---|---|
| **Date** | Saturday 5 September 2026 |
| **Onsite** | 10:00 - 14:30, FGS Auditorium, KDU |
| | *All times Asia/Colombo (UTC+5:30)* |

Challenges release through the day in four timed waves - nothing in a later wave is
visible until its wave opens. Each wave pairs an accessible foothold with its harder
drops, so there's always something in reach.

### Release waves

| Wave | Opens | Challenges |
|---|---|---|
| 1 | 10:00 | e01, e02, m01, i02, h14 |
| 2 | 10:55 | m03, i01, i03, h06, h15 |
| 3 | 11:50 | i04, h12, h10, ai1, ai2 |
| 4 | 12:45 | h05, h01, h02, h08, ai3 |
| Freeze | 14:00 | board freezes for the final 30 minutes |

---

## How it works

- **20 independent challenges** across Cloud, Web, Crypto, Reverse Engineering, Pwn,
  Forensics, Container/K8s, and AI Security - no fixed order, no chained dependencies.
- **Your team from Phase 1.** If your account or team doesn't show your seed from the
  trials, flag a floor mentor before the clock starts.
- **Every flag looks like** `CYPHER{...}` - submit it exactly as you find it.
- **Hints are limited on purpose.** Most challenges ship with none. A small number of
  the hardest carry a single **costed** hint that names the class of bug, never the
  payload - spend points on it deliberately, it's not a giveaway.
- **Floor mentors** walk the room for infrastructure issues and can nudge a stalled
  team - flag them down rather than losing time to a broken environment.

## Scoring

- **Dynamic scoring**, banded by difficulty - a challenge is worth more while few teams
  have solved it, and decays as more do. Early, confident solves pay off.
- **First blood** on any challenge earns a **+50 bonus**.
- **The board freezes for the final 30 minutes.** Keep solving - you just won't see
  rank changes until the reveal.
- Ties are broken by who reached their score first.

---

## Important: fair play

This is a live, shared environment. Attacks against the **infrastructure itself**,
rather than the intended challenge, put the event down for everyone else in the room.

**Denial-of-service attacks of any kind are strictly prohibited** - against the
platform, another team's session, or any challenge service. This includes deliberate
resource exhaustion, connection flooding, and any attempt to disrupt another team's
access.

**A team found doing this will be disqualified.** Solve the challenges, not the
scoreboard.

Automatic per-team connection-rate limiting is in place platform-wide. Some challenges
legitimately need a solve script that sends many requests - that's fine and well within
the limit. What isn't fine is deliberately flooding a service; the limit exists to
protect everyone's access, not to slow down normal solving.

---

## Getting started

1. Confirm you can see your team on the scoreboard - ask a mentor if not.
2. Watch the room for each wave opening; new challenges will simply appear.
3. Work in parallel - with 20 independent challenges, there's no reason to queue behind
   one teammate on one box.
4. Read connection info carefully - some challenges are live services, some are
   downloadable attachments, some are direct cloud resources.

Go get in the way the attacker got in.
