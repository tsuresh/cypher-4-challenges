#!/usr/bin/env python3
"""
bootstrap_ctfd.py — configure a fresh CTFd instance entirely over the API.

Runs the /setup flow (admin user, team mode, CTF name), mints an admin API
token, and applies competition config: dynamic-scoring defaults, free hints
policy, tie-break, scoreboard visibility, and the freeze time. Prints the token
on stdout so the caller can export CTFD_ADMIN_TOKEN for ctfcli.

Usage:
  bootstrap_ctfd.py --url http://localhost:8000 \
      --admin-user admin --admin-email a@b.lk --admin-pass '...' \
      --ctf-name "CYPHER 4.0 — Recruitment Trials" \
      [--freeze-epoch 1757080500] [--scoreboard hidden|public]

Idempotent-ish: if /setup was already completed it skips straight to login.
"""
import argparse
import re
import sys

try:
    import requests
except ImportError:
    sys.exit("pip install requests  (needed for bootstrap_ctfd.py)")

NONCE_RE = re.compile(r"'csrfNonce'\s*:\s*\"([0-9a-f]+)\"")


def nonce(session, url, path="/setup"):
    r = session.get(url + path)
    m = NONCE_RE.search(r.text)
    return m.group(1) if m else None


def already_setup(session, url) -> bool:
    r = session.get(url + "/setup", allow_redirects=False)
    # A configured CTFd redirects /setup away (302) instead of serving the form.
    return r.status_code in (301, 302)


def run_setup(session, url, args):
    n = nonce(session, url, "/setup")
    if n is None:
        sys.exit("Could not read CSRF nonce from /setup — is CTFd up?")
    data = {
        "ctf_name": args.ctf_name,
        "ctf_description": args.ctf_description,
        "user_mode": "teams",
        "challenge_visibility": "private",
        "account_visibility": "private",
        "score_visibility": "public" if args.scoreboard == "public" else "private",
        "registration_visibility": "public",
        "verify_emails": "false",
        "team_size": "4",
        "name": args.admin_user,
        "email": args.admin_email,
        "password": args.admin_pass,
        "ctf_theme": "core-beta",
        "nonce": n,
        "_submit": "Finish",
    }
    r = session.post(url + "/setup", data=data, allow_redirects=True)
    r.raise_for_status()


def login(session, url, args):
    n = nonce(session, url, "/login")
    r = session.post(
        url + "/login",
        data={"name": args.admin_user, "password": args.admin_pass, "nonce": n},
        allow_redirects=True,
    )
    r.raise_for_status()


def mint_token(session, url) -> str:
    # CTFd 3.x: POST /api/v1/tokens with CSRF header from the session page.
    n = nonce(session, url, "/settings")
    r = session.post(
        url + "/api/v1/tokens",
        json={"description": "cypher4-ctfcli"},
        headers={"CSRF-Token": n, "Content-Type": "application/json"},
    )
    r.raise_for_status()
    return r.json()["data"]["value"]


def apply_config(url, token, args):
    h = {"Authorization": f"Token {token}", "Content-Type": "application/json"}
    cfg = {
        # Tie-break: points then earliest last-accepted solve is CTFd default.
        # Explicitly (re)assert public/hidden scoreboard and freeze here.
        "score_visibility": "public" if args.scoreboard == "public" else "private",
    }
    if args.freeze_epoch:
        cfg["freeze"] = int(args.freeze_epoch)
    for k, v in cfg.items():
        r = requests.patch(url + "/api/v1/configs", json={k: v}, headers=h)
        if not r.ok:
            print(f"warn: could not set {k}={v}: {r.status_code}", file=sys.stderr)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--url", required=True)
    p.add_argument("--admin-user", required=True)
    p.add_argument("--admin-email", required=True)
    p.add_argument("--admin-pass", required=True)
    p.add_argument("--ctf-name", required=True)
    p.add_argument("--ctf-description",
                   default="Serendib Cyber Task Force — authorised CTF sandbox.")
    p.add_argument("--freeze-epoch", type=int, default=0)
    p.add_argument("--scoreboard", choices=["public", "hidden"], default="hidden")
    args = p.parse_args()

    s = requests.Session()
    if not already_setup(s, args.url):
        run_setup(s, args.url, args)
    else:
        print("CTFd already set up; logging in.", file=sys.stderr)
    login(s, args.url, args)
    token = mint_token(s, args.url)
    apply_config(args.url, token, args)
    print(token)  # stdout: the caller captures this


if __name__ == "__main__":
    main()
