from abc import ABC, abstractmethod
from typing import AsyncGenerator
class BaseAgent(ABC):
    name: str = "base"
    @abstractmethod
    async def process(self, query: str, context: str, language: str, user_id: int) -> str: pass
    @abstractmethod
    async def execute(self, task: str, user_id: int) -> str: pass
    async def process_stream(self, query: str, context: str, language: str, user_id: int) -> AsyncGenerator[str, None]:
        yield await self.process(query, context, language, user_id)