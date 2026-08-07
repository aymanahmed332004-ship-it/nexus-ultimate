import httpx, json, re
from config import settings
from logger import logger

class IntentRouter:
    _client = None
    @classmethod
    def get_client(cls):
        if cls._client is None: cls._client = httpx.AsyncClient(timeout=10.0)
        return cls._client
    @classmethod
    async def close_client(cls):
        if cls._client: await cls._client.aclose(); cls._client = None
    
    def __init__(self): self.client = self.get_client()
    
    async def classify(self, query: str, user_id: int = 0) -> dict:
        try:
            r = await self.client.post("https://api.groq.com/v1/chat/completions", headers={"Authorization": f"Bearer {settings.GROQ_API_KEY}"}, json={"model": "mixtral-8x7b-32768", "messages": [{"role": "system", "content": "صنف نية المستخدم إلى: coding, search, design. أخرج JSON فقط: {\"agent\": \"coding\", \"confidence\": 0.9}"}, {"role": "user", "content": query}], "temperature": 0.3, "max_tokens": 100})
            data = r.json()
            result = data.get("choices", [{}])[0].get("message", {}).get("content", "{}")
            return json.loads(result)
        except Exception as e: logger.error(f"Intent failed: {e}"); return {"agent": "search", "confidence": 0.5}
    
    async def detect_language(self, text: str, user_id: int = 0) -> str:
        cleaned = re.sub(r'[^\w\s]', '', text)
        if len(cleaned.strip()) < 3: return 'arabic'
        try:
            from langdetect import detect
            lang = detect(text)
            lang_map = {'ar':'arabic','en':'english','fr':'french','es':'spanish','de':'german','it':'italian','ru':'russian','zh-cn':'chinese','ja':'japanese','ko':'korean','hi':'hindi','pt':'portuguese'}
            return lang_map.get(lang, 'english')
        except: return 'arabic'