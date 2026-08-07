import httpx, os, tempfile, asyncio
from config import settings
from logger import logger
from utils.model_router import ModelRouter

class FileAnalyzer:
    _client = None
    @classmethod
    def get_client(cls):
        if cls._client is None: cls._client = httpx.AsyncClient(timeout=settings.API_TIMEOUT)
        return cls._client
    @classmethod
    async def close_client(cls):
        if cls._client: await cls._client.aclose(); cls._client = None
    
    def __init__(self):
        self.client = self.get_client()
        self.router = ModelRouter()
    
    async def analyze(self, file_url: str, user_id: int) -> dict:
        tmp_path = None; file_size = 0
        try:
            async with self.client.stream("GET", file_url) as response:
                if response.status_code != 200: return {"error": "فشل تحميل الملف"}
                with tempfile.NamedTemporaryFile(delete=False) as tmp:
                    async for chunk in response.aiter_bytes(chunk_size=8192): tmp.write(chunk)
                    tmp_path = tmp.name; file_size = tmp.tell()
            ext = os.path.splitext(file_url)[1].lower()
            content = "نوع الملف غير مدعوم"
            if ext in ['.pdf','.docx','.txt']: content = await self._extract_text(tmp_path, ext)
            elif ext in ['.jpg','.jpeg','.png','.gif']: content = await self._analyze_image(tmp_path)
            elif ext in ['.mp3','.wav','.ogg']: content = await self._transcribe_audio(tmp_path)
            summary = await self.router.ask(f"لخص هذا المحتوى: {content[:3000]}", "لخص النص")
            return {"content": content[:5000], "summary": summary, "type": ext, "size": file_size}
        except Exception as e: logger.error(f"File analysis error: {e}"); return {"error": str(e)}
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try: os.remove(tmp_path)
                except: pass
            await self.client.aclose()
    
    async def _extract_text(self, file_path: str, ext: str) -> str:
        try:
            if ext == '.pdf':
                import PyPDF2
                with open(file_path, 'rb') as f:
                    reader = PyPDF2.PdfReader(f)
                    return "\n".join([p.extract_text() for p in reader.pages])
            elif ext == '.docx':
                from docx import Document
                doc = Document(file_path)
                return "\n".join([p.text for p in doc.paragraphs])
            elif ext == '.txt':
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    return f.read(100000)
        except Exception as e: logger.error(f"Extract error: {e}"); return ""
    
    async def _analyze_image(self, file_path: str) -> str:
        try:
            def do_ocr():
                import pytesseract
                from PIL import Image
                return pytesseract.image_to_string(Image.open(file_path))
            return f"[نص مستخرج من الصورة]\n{await asyncio.to_thread(do_ocr)}"
        except Exception as e: return f"⚠️ تحليل الصورة فشل: {e}"
    
    async def _transcribe_audio(self, file_path: str) -> str:
        try:
            from groq import Groq
            client = Groq(api_key=settings.GROQ_API_KEY)
            with open(file_path, "rb") as f:
                return client.audio.transcriptions.create(file=f, model="whisper-large-v3", response_format="text")
        except Exception as e: return f"⚠️ تحويل الصوت فشل: {e}"