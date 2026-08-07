from agents.base_agent import BaseAgent
from utils.model_router import ModelRouter
class CodingAgent(BaseAgent):
    name = "coding"
    def __init__(self): self.router = ModelRouter()
    async def process(self, query: str, context: str, language: str, user_id: int) -> str:
        return await self.router.ask(query, f"أنت وكيل برمجة. اللغة: {language}. السياق: {context}")
    async def execute(self, task: str, user_id: int) -> str:
        return await self.router.ask(task, "أنت وكيل برمجة. نفذ المهمة.")
    async def process_stream(self, query: str, context: str, language: str, user_id: int):
        async for chunk in self.router.ask_stream(query, f"أنت وكيل برمجة. اللغة: {language}. السياق: {context}"):
            yield chunk