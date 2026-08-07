from celery import Celery
from config import settings
from logger import logger
import asyncio, nest_asyncio
celery_app = Celery("nexus", broker=settings.REDIS_URL, backend=settings.REDIS_URL)
celery_app.conf.update(task_serializer="json", accept_content=["json"], result_serializer="json", timezone="UTC", enable_utc=True, task_track_started=True, task_time_limit=3600, task_soft_time_limit=3000)
@celery_app.task
def process_agent_task(user_id: int, task: str):
    from agents.manager import AgentManager
    async def _run():
        agent = await AgentManager.get_agent(task, user_id)
        return await agent.execute(task, user_id)
    try: return asyncio.run(_run())
    except RuntimeError as e:
        if "event loop is already running" in str(e):
            nest_asyncio.apply()
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            return loop.run_until_complete(_run())
        raise