"""
APScheduler jobs — all async since they now use the asyncpg pool.
AsyncIOScheduler runs coroutines natively on the same event loop as FastAPI.
"""
import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

scheduler = AsyncIOScheduler(timezone="Asia/Kolkata")
log = logging.getLogger("scheduler")


async def _auto_fail_stuck():
    from services.penalties import auto_fail_stuck_orders
    from config import get_settings
    count = await auto_fail_stuck_orders(get_settings().auto_fail_hours)
    if count:
        log.info("auto-failed %d stuck orders", count)


async def _lift_suspensions():
    from services.penalties import lift_expired_suspensions
    count = await lift_expired_suspensions()
    if count:
        log.info("lifted %d suspensions", count)


async def _generate_settlements():
    from services.settlements import generate_weekly_settlements, mark_overdue_settlements
    n = await generate_weekly_settlements()
    o = await mark_overdue_settlements()
    log.info("created %d settlements, marked %d overdue", n, o)


def start_scheduler() -> None:
    scheduler.add_job(_auto_fail_stuck,      CronTrigger(minute="*/30"), id="auto_fail")
    scheduler.add_job(_lift_suspensions,     CronTrigger(hour=6, minute=0), id="lift_suspensions")
    scheduler.add_job(_generate_settlements, CronTrigger(day_of_week="mon", hour=8, minute=0),
                      id="weekly_settlements")
    scheduler.start()
