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
import os

from CTFd.models import Awards, Solves, db
from CTFd.utils.decorators import admins_only
from flask import Blueprint, jsonify
from sqlalchemy import event

BONUS = int(os.environ.get("FIRST_BLOOD_BONUS", "50"))
_CATEGORY = "first_blood"


def _already_awarded(challenge_id: int) -> bool:
    return (
        Awards.query.filter_by(category=_CATEGORY)
        .filter(Awards.description == f"chal:{challenge_id}")
        .first()
        is not None
    )


def _grant_first_blood(solve: Solves) -> None:
    """Create the bonus award if this is the first solve of the challenge."""
    if BONUS <= 0:
        return
    if _already_awarded(solve.challenge_id):
        return
    # Guard: only the earliest solve for this challenge earns the bonus.
    earliest = (
        Solves.query.filter_by(challenge_id=solve.challenge_id)
        .order_by(Solves.date.asc())
        .first()
    )
    if earliest is None or earliest.id != solve.id:
        return
    award = Awards(
        user_id=solve.user_id,
        team_id=solve.team_id,
        name="First Blood",
        description=f"chal:{solve.challenge_id}",
        value=BONUS,
        category=_CATEGORY,
    )
    db.session.add(award)
    db.session.commit()


@event.listens_for(Solves, "after_insert")
def _on_solve(mapper, connection, target):  # noqa: ANN001
    # Deferred to after the surrounding transaction commits, so the Solve row
    # is visible when we query for the earliest solve.
    @event.listens_for(db.session, "after_commit", once=True)
    def _after(session):  # noqa: ANN001
        try:
            _grant_first_blood(target)
        except Exception:  # never break a solve because a bonus failed
            db.session.rollback()


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
