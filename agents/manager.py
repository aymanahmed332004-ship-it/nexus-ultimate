from agents.base_agent import BaseAgent
from agents.coding_agent import CodingAgent
from agents.search_agent import SearchAgent
from agents.design_agent import DesignAgent
from utils.intent_router import IntentRouter
from logger import logger
class AgentManager:
    _agents = {"coding": CodingAgent(), "search": SearchAgent(), "design": DesignAgent()}
    @classmethod
    async def get_agent(cls, query: str, user_id: int = 0) -> BaseAgent:
        router = IntentRouter()
        intent = await router.classify(query, user_id)
        agent_type = intent.get("agent", "search")
        logger.info(f"Agent selected: {agent_type} for query: {query[:50]}...")
        return cls._agents.get(agent_type, cls._agents["search"])