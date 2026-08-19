# CYPHER 4.0 — Phase 1: The Recruitment Trials
### Hackathon Pre-Task and Finalist Selection
Knowledge Partner plan prepared by GDG Sri Lanka / Women Techmakers

---

## The story

The **Serendib Cyber Task Force (SCTF)** is recruiting. Across the island, companies moved to the cloud faster than they secured it. A tea exporter in Nuwara Eliya left a storage bucket open. A ride-hailing app in Colombo trusts user input a little too much. A telecom operator forgot to lock a folder on its web server.

The SCTF needs analysts who can find these doors before real attackers do. This is the entry trial. It is meant to be approachable: any team that attended the technical session and is willing to try should walk away with solves. Every challenge is one company's cloud slip-up, and the flags are the proof. The ten teams that find the most, fastest, are inducted into the finals.

---

## What this phase selects for

Cloud recon and enumeration, spotting misconfigurations, and basic web-to-cloud thinking. It rewards persistence and willingness to learn over prior expertise. The 20 August technical session teaches the techniques the trial then tests, so no one is being asked to know something they were never shown.

---

## Difficulty and support (accessible by design)

- **Guaranteed early wins.** A warm-up plus five easy challenges every team can solve. Momentum matters more than filtering at this stage.
- **A free hint on every challenge.** Hints cost zero points, so using them is never a penalty. Each hint names the technique in plain language.
- **Reduced multi-step depth.** Only one challenge is a true multi-step separator. The rest are single ideas.
- **Learning resources released before the window.** A short list of tools and the session recording, so teams prepare rather than guess.
- **Differentiation still holds.** Dynamic scoring, first-blood bonuses, solve times, the one hard challenge, and the written brief separate the top teams cleanly, so an accessible floor does not blur the top 10.

---

## Format at a glance

| Item | Decision |
|---|---|
| Mode | Online, remote, jeopardy-style |
| Window | 48 to 72 hours over a weekend |
| Platform | CTFd (self-hosted, auto-scored) |
| Team size | 2 to 4, same university (per event rules) |
| Hints | Free (zero cost), one on every challenge |
| Scoring | Dynamic decay plus first-blood bonus |
| Output | Auto-ranked scoreboard, top 10 advance |

---

## Challenge set

A warm-up plus twelve challenges, weighted toward easy and medium. All flags use the format `CYPHER{...}`.

| # | Challenge | Company | Category | Difficulty | Pts |
|---|---|---|---|---|---|
| 00 | Practice Range | SCTF | Warm-up | Trivial | 10 |
| 01 | The Open Warehouse | Ceylon Kade | Cloud storage / recon | Easy | 75 |
| 02 | Leaked Ledger | Highland Leaf | Web / secrets exposure | Easy | 75 |
| 03 | The Forgotten Backup | Pearl Telecom | Web / recon | Easy | 100 |
| 05 | Git Happens | Pearl Telecom | Web / source disclosure | Easy | 100 |
| 04 | Metadata Mischief | Ape Ride | SSRF / cloud metadata | Medium | 150 |
| 06 | Signed and Sealed | Arugam Waves | Cloud storage / access control | Medium | 150 |
| 07 | Too Many Permissions | Ruhunu Bank | Cloud IAM | Medium | 150 |
| 10 | Function Leak | Ruhunu Bank | Serverless | Medium | 150 |
| 09 | Peering Into the Cluster | Ape Ride | Kubernetes (read only) | Medium | 175 |
| 08 | The Careless Container | Ceylon Kade | Container exposure | Medium | 200 |
| 11 | The Escalation | Ape Ride | IAM privilege escalation | Hard | 300 |
| 12 | Blue Team Brief | Any of the above | Written remediation (bonus) | Bonus | 100 |

Target outcome: almost every team clears the warm-up and the easy tier, most teams reach several mediums, and the top teams are separated by challenge 11, solve speed, and the written brief. A mid-tier team should finish the trial feeling successful, not shut out.

---

## Guided hints (all free)

- **00 Practice Range:** submit `CYPHER{welcome_to_cypher}` to learn how flags work.
- **01 Open Warehouse:** open storage buckets can be listed by anyone. The `gsutil` tool lists and downloads bucket contents.
- **02 Leaked Ledger:** config files like `.env` are sometimes left reachable. Try requesting it directly in the browser.
- **03 Forgotten Backup:** old backups get left behind with predictable names. Guess common backup filenames and paths.
- **05 Git Happens:** a `.git` folder left on a web server lets you rebuild the source and its history.
- **04 Metadata Mischief:** cloud servers expose an internal address at `169.254.169.254`. If the app fetches URLs for you, point it there. This is the technique from the technical session.
- **06 Signed and Sealed:** object links can be guessed if they follow a pattern. Change the object name and see what else you can reach.
- **07 Too Many Permissions:** the credentials you were given can do more than they should. List what your identity is allowed to do, then read the secret.
- **10 Function Leak:** the function trusts its input. Send it something that makes it print its own environment.
- **09 Peering Into the Cluster:** a cluster dashboard is reachable without a login. Browse to it and read the stored secret.
- **08 Careless Container:** a container management port is open. Ask it to list containers, then read a running container's environment for the flag.
- **11 The Escalation:** start with the low-privilege key. List which higher identity you can act as, switch to it, then read the protected secret.
- **12 Blue Team Brief:** pick any challenge above and write three sentences on how the company should have prevented it.

---

## Technical build notes

Deployable artifacts per challenge, all in an isolated GCP sandbox the SCTF owns. Two challenges were softened from an earlier draft to keep the floor low:

- **08 Careless Container** now asks teams to list containers on an exposed Docker API and read a running container's environment for the flag, rather than perform a full host escape.
- **11 The Escalation** is a two-step chain (leaked low-privilege key, then assume one higher identity to read the secret), rather than a longer path.

The remaining challenges are as before: a public GCS bucket (01), a reachable `.env` (02), a guessable backup path (03), an SSRF app plus the real GCP metadata server with a least-privilege service account (04), an exposed `.git` (05), enumerable signed URLs (06), a low-privilege service account against Secret Manager (07), a serverless function that leaks env vars (10), and a kind cluster with an anonymous-read secret (09). Challenge 12 has no infrastructure, just a CTFd submission field.

---

## Scoring model

- **Dynamic decay.** Each challenge starts at its base value and drops as more teams solve it, so the hard challenge carries the most weight.
- **First blood.** A small bonus for the first team to solve each challenge.
- **Free hints.** Hints do not reduce points, so a team that needs a nudge is not punished.
- **Tie-break.** Ties resolve by earliest last-accepted solve. The written brief acts as a secondary tie-break.

---

## Rules and anti-cheat

- Teams solve only on the CTFd instance. Flag format is announced up front.
- No sharing of flags or solutions between teams. Identical solve patterns across teams are flagged for review.
- No attacks on the CTFd platform itself or anything outside the provided scope.
- Any breach means disqualification. This rule goes in the delegate handbook.

---

## Selection and cut to top 10

At window close, the CTFd scoreboard is final. Rank by points, then tie-break rules. The top 10 teams are the finalists, confirmed publicly on 26 August. Scoring is automatic, so no manual panel review is needed to produce the list.

---

## Timeline (mapped to the event dates)

| Date | Milestone | Owner |
|---|---|---|
| Now to 20 Aug | Build and test all challenges, provision sandbox, write hints and resources | GDG / SCTF |
| 20 Aug | Technical session teaches the techniques the trial tests, with a live metadata demo | Joint |
| 22 Aug | Registration closes; final team list locked | KDU |
| 22 to 25 Aug | Pre-task window open (exact hours TBF) | Joint |
| 25 to 26 Aug | Scoreboard finalised, written briefs reviewed | GDG / SCTF |
| 26 Aug | Top 10 finalists confirmed publicly | KDU |

---

## Toolbox and resources (share with teams before the window)

- Tools: a web browser, `curl`, `git`, and the Google Cloud SDK (`gcloud` and `gsutil`). Nothing exotic.
- The technical session recording and slides, which cover storage, metadata, IAM, and the tools above.
- A one-page primer on reading cloud permissions and listing bucket contents.

---

## Ownership split

**GDG / Women Techmakers (SCTF side):** CTFd platform and hosting, all challenges and their sandbox, hints and resources, scoring configuration, the live scoreboard, and review of the written briefs.

**KDU IEEE WIE:** registration, team verification, participant communications, and public announcement of finalists.

---

## What comes next

Once approved, the configuration scripts provision each challenge above and load them into CTFd with dynamic scoring and free hints. Those bash scripts are the next deliverable.
