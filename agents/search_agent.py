from agents.base_agent import BaseAgent
from utils.model_router import ModelRouter
from utils.search_engine import SearchEngine
class SearchAgent(BaseAgent):
    name = "search"
    def __init__(self):
        self.router = ModelRouter()
        self.search_engine = SearchEngine()
    async def process(self, query: str, context: str, language: str, user_id: int) -> str:
        results = await self.search_engine.search(query)
        search_text = "\n".join([f"- {r['title']}: {r['snippet']}" for r in results[:5]])
        return await self.router.ask(query, f"أنت وكيل بحث. اللغة: {language}. نتائج: {search_text}. السياق: {context}")
    async def execute(self, task: str, user_id: int) -> str:
        results = await self.search_engine.search(task)
        return "\n".join([f"{r['title']}: {r['snippet']}" for r in results[:5]])