from agents.base_agent import BaseAgent
from utils.model_router import ModelRouter
class DesignAgent(BaseAgent):
    name = "design"
    def __init__(self): self.router = ModelRouter()
    async def process(self, query: str, context: str, language: str, user_id: int) -> str:
        return await self.router.ask(query, f"أنت وكيل تصميم. اللغة: {language}. السياق: {context}")
    async def execute(self, task: str, user_id: int) -> str:
        return await self.router.ask(task, "أنت وكيل تصميم. نفذ المهمة.")