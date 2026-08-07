import httpx
from duckduckgo_search import DDGS
from config import settings
from logger import logger

class SearchEngine:
    _client = None
    @classmethod
    def get_client(cls):
        if cls._client is None: cls._client = httpx.AsyncClient(timeout=30.0)
        return cls._client
    @classmethod
    async def close_client(cls):
        if cls._client: await cls._client.aclose(); cls._client = None
    
    def __init__(self): self.client = self.get_client()
    
    async def search(self, query: str, sources: list = ["web"]) -> list:
        results = []
        if "web" in sources: results.extend(await self._search_ddg(query))
        if "tavily" in sources and settings.TAVILY_API_KEY: results.extend(await self._search_tavily(query))
        seen = set(); unique = []
        for r in results:
            key = r.get("url", r.get("title"))
            if key not in seen: seen.add(key); unique.append(r)
        return unique[:10]
    
    async def _search_ddg(self, query: str) -> list:
        try:
            with DDGS() as ddgs:
                results = list(ddgs.text(query, max_results=5))
                return [{"title": r.get("title", ""), "snippet": r.get("body", ""), "url": r.get("href", "#"), "source": "duckduckgo"} for r in results]
        except Exception as e: logger.error(f"DDG error: {e}"); return []
    
    async def _search_tavily(self, query: str) -> list:
        try:
            r = await self.client.post("https://api.tavily.com/search", headers={"Authorization": f"Bearer {settings.TAVILY_API_KEY}"}, json={"query": query, "max_results": 3})
            data = r.json()
            return [{"title": r.get("title", ""), "snippet": r.get("content", ""), "url": r.get("url", "#"), "source": "tavily"} for r in data.get("results", [])]
        except Exception as e: logger.error(f"Tavily error: {e}"); return []