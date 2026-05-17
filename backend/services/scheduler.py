from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

scheduler = AsyncIOScheduler(timezone="Asia/Kolkata")


def _auto_fail_stuck():
    from services.penalties import auto_fail_stuck_orders
    from config import get_settings
    count = auto_fail_stuck_orders(get_settings().auto_fail_hours)
    if count:
        print(f"[scheduler] auto-failed {count} stuck orders")


def _lift_suspensions():
    from services.penalties import lift_expired_suspensions
    count = lift_expired_suspensions()
    if count:
        print(f"[scheduler] lifted {count} suspensions")


def _generate_settlements():
    from services.settlements import generate_weekly_settlements, mark_overdue_settlements
    n = generate_weekly_settlements()
    o = mark_overdue_settlements()
    print(f"[scheduler] created {n} settlements, marked {o} overdue")


def start_scheduler() -> None:
    scheduler.add_job(_auto_fail_stuck, CronTrigger(minute="*/30"), id="auto_fail")
    scheduler.add_job(_lift_suspensions, CronTrigger(hour=6, minute=0), id="lift_suspensions")
    scheduler.add_job(
        _generate_settlements,
        CronTrigger(day_of_week="mon", hour=8, minute=0),
        id="weekly_settlements",
    )
    scheduler.start()
