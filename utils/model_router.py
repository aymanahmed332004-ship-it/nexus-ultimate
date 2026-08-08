import httpx, asyncio
from tenacity import retry, stop_after_attempt, wait_exponential, retry_if_exception
from typing import AsyncGenerator
from config import settings
from logger import logger

class ModelRouter:
    _client = None
    @classmethod
    def get_client(cls):
        if cls._client is None: cls._client = httpx.AsyncClient(timeout=settings.API_TIMEOUT)
        return cls._client
    @classmethod
    async def close_client(cls):
        if cls._client: await cls._client.aclose(); cls._client = None
    
    def __init__(self):
        self.models = []
        # المفاتيح الأساسية
        if settings.GROQ_API_KEY: 
            self.models.append({"name": "groq", "key": settings.GROQ_API_KEY, "url": "https://api.groq.com/v1/chat/completions"})
        if settings.OPENROUTER_KEY: 
            self.models.append({"name": "openrouter", "key": settings.OPENROUTER_KEY, "url": "https://openrouter.ai/api/v1/chat/completions"})
        
        # 🟢 المفتاح الجديد (احتياطي إضافي للمحادثة)
        if settings.MY_CHAT_API:
            self.models.append({
                "name": "my_provider", 
                "key": settings.MY_CHAT_API, 
                "url": "https://api.groq.com/v1/chat/completions"  # لو مفتاح Groq جديد. لو حاجة تانية غير الرابط ده.
            })
        
        if not self.models: 
            logger.warning("⚠️ لا توجد مفاتيح API")
            self.models.append({"name": "mock", "key": "", "url": ""})
            
        self.current_index = 0
        self.client = self.get_client()
    
    def _is_retryable(self, exc):
        if isinstance(exc, (httpx.TimeoutException, httpx.ConnectError)): return True
        if isinstance(exc, httpx.HTTPStatusError) and exc.response.status_code in [429, 500]: return True
        return False
    
    @retry(stop=stop_after_attempt(3), wait=wait_exponential(multiplier=2, min=4, max=60), retry=retry_if_exception(_is_retryable))
    async def ask(self, prompt: str, system: str = "") -> str:
        if len(self.models) == 1 and self.models[0]["name"] == "mock": return "⚠️ رد تجريبي"
        for _ in range(len(self.models)):
            model = self.models[self.current_index % len(self.models)]
            try:
                if model["name"] == "groq": 
                    return await self._call_groq(prompt, system, model)
                elif model["name"] == "openrouter": 
                    return await self._call_openrouter(prompt, system, model)
                elif model["name"] == "my_provider": 
                    # هنا بنادي على دالة جديدة خاصة بالمزود الجديد
                    return await self._call_my_provider(prompt, system, model)
                elif model["name"] == "mock": 
                    return "رد تجريبي"
            except httpx.HTTPStatusError as e:
                if e.response.status_code == 429: 
                    logger.warning(f"Rate limit {model['name']}"); await asyncio.sleep(5); self.current_index += 1; continue
                elif e.response.status_code == 401: 
                    logger.error(f"Invalid key {model['name']}"); self.current_index += 1; continue
                else: 
                    logger.warning(f"{model['name']} failed: {e}"); self.current_index += 1; await asyncio.sleep(1)
            except Exception as e: 
                logger.warning(f"{model['name']} failed: {e}"); self.current_index += 1; await asyncio.sleep(1)
        return "🚫 جميع النماذج غير متاحة"
    
    async def ask_stream(self, prompt: str, system: str = "") -> AsyncGenerator[str, None]:
        # في حالة الـ stream، بنفضل نستخدم Groq لأنه الأسرع
        model = next((m for m in self.models if m["name"] == "groq"), None)
        if not model: yield "⚠️ تدفق غير متاح"; return
        try:
            async with self.client.stream("POST", model["url"], headers={"Authorization": f"Bearer {model['key']}"}, json={"model": "mixtral-8x7b-32768", "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}], "temperature": 0.7, "max_tokens": 4096, "stream": True}) as response:
                async for line in response.aiter_lines():
                    if line.startswith("data: "):
                        data = line[6:]
                        if data == "[DONE]": break
                        import json
                        chunk = json.loads(data)
                        content = chunk.get("choices", [{}])[0].get("delta", {}).get("content", "")
                        if content: yield content
        except Exception as e: 
            logger.error(f"Stream error: {e}"); yield f"⚠️ خطأ: {e}"
    
    async def _call_groq(self, prompt, system, model):
        r = await self.client.post(model["url"], headers={"Authorization": f"Bearer {model['key']}"}, json={"model": "mixtral-8x7b-32768", "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}], "temperature": 0.7, "max_tokens": 4096})
        r.raise_for_status(); return r.json()["choices"][0]["message"]["content"]
    
    async def _call_openrouter(self, prompt, system, model):
        r = await self.client.post(model["url"], headers={"Authorization": f"Bearer {model['key']}", "Content-Type": "application/json"}, json={"model": "nousresearch/hermes-3-llama-3.1-405b:free", "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}], "temperature": 0.7, "max_tokens": 4096}, timeout=settings.API_TIMEOUT)
        r.raise_for_status(); return r.json()["choices"][0]["message"]["content"]

    # 🟢 دالة جديدة خاصة بالمزود الجديد (الاحتياطي)
    async def _call_my_provider(self, prompt, system, model):
        # حالياً بنفترض إن المزود الجديد هو نفس تنسيق Groq (أو OpenRouter)
        # لو جبت مفتاح لخدمة تانية (مثل OpenAI أو Gemini)، لازم تغير الرابط والـ model name هنا
        r = await self.client.post(model["url"], headers={"Authorization": f"Bearer {model['key']}"}, json={"model": "mixtral-8x7b-32768", "messages": [{"role": "system", "content": system}, {"role": "user", "content": prompt}], "temperature": 0.7, "max_tokens": 4096})
        r.raise_for_status(); return r.json()["choices"][0]["message"]["content"]