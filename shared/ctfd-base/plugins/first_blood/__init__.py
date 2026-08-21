"""
first_blood — award a fixed bonus to the first solver of each challenge.

Vanilla CTFd records solve order but grants no bonus. This plugin listens for
the first Solve on every challenge and creates a one-off Award for that team,
worth FIRST_BLOOD_BONUS points (env-configurable, default 50). Idempotent: the
bonus is granted at most once per challenge.

Tie-break and dynamic scoring are left to core CTFd. Hints remain free (their
cost is set to 0 at challenge-sync time by ctfcli), so this plugin never touches
hint economics.
"""
import logging
import os

from CTFd.models import Awards, Solves, db
from CTFd.utils.decorators import admins_only
from flask import Blueprint, jsonify
from sqlalchemy import event

log = logging.getLogger("CTFd.plugins.first_blood")

BONUS = int(os.environ.get("FIRST_BLOOD_BONUS", "50"))
_CATEGORY = "first_blood"


def _first_blood_for(session, challenge_id: int) -> bool:
    """True if this challenge has no prior solve and no bonus yet."""
    if session.query(Awards.id).filter(
        Awards.category == _CATEGORY,
        Awards.description == f"chal:{challenge_id}",
    ).first():
        return False
    # No Solve row for this challenge exists YET (ours is still pending in the
    # flush), so the solve being inserted is the first one.
    if session.query(Solves.id).filter(Solves.challenge_id == challenge_id).first():
        return False
    return True


@event.listens_for(db.session, "before_flush")
def _grant_first_blood(session, flush_context, instances):  # noqa: ANN001
    """Attach the bonus Award in the SAME transaction as the Solve.

    Earlier versions registered an `after_commit` listener from inside
    `after_insert` and called db.session.commit() there. SQLAlchemy does not
    permit committing inside after_commit, and a blanket `except Exception`
    swallowed the error — so no bonus was EVER awarded and nothing was logged.
    before_flush is the supported place to add a dependent row: it uses the ORM
    (so column defaults and polymorphic identity apply) and is committed
    atomically with the solve.
    """
    if BONUS <= 0:
        return
    seen = set()
    # no_autoflush: querying during before_flush would otherwise re-enter the
    # flush and recurse.
    with session.no_autoflush:
        for obj in list(session.new):
            if not isinstance(obj, Solves):
                continue
            cid = obj.challenge_id
            if cid is None or cid in seen:
                continue
            seen.add(cid)
            try:
                if not _first_blood_for(session, cid):
                    continue
                session.add(
                    Awards(
                        user_id=obj.user_id,
                        team_id=obj.team_id,
                        name="First Blood",
                        description=f"chal:{cid}",
                        value=BONUS,
                        category=_CATEGORY,
                    )
                )
            except Exception:
                # Never break a solve because the bonus failed — but make it
                # visible, instead of failing silently as before.
                log.exception("first_blood: could not award bonus for challenge %s", cid)


def load(app):
    bp = Blueprint("first_blood", __name__)

    @bp.route("/api/v1/first-blood", methods=["GET"])
    @admins_only
    def list_first_bloods():
        rows = Awards.query.filter_by(category=_CATEGORY).all()
        return jsonify(
            {
                "success": True,
                "data": [
                    {"team_id": a.team_id, "challenge": a.description, "value": a.value}
                    for a in rows
                ],
            }
        )

    app.register_blueprint(bp)
