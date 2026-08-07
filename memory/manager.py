from memory.vector_store import VectorStore
from models.message import Message
from database import get_db
from logger import logger
import hashlib, tiktoken
from config import settings

class MemoryManager:
    def __init__(self, user_id: int):
        self.user_id = user_id
        self.vector_store = VectorStore(user_id)
        self.limit = settings.MEMORY_LIMIT
        self.encoder = tiktoken.get_encoding("cl100k_base")
    
    def _count_tokens(self, text: str) -> int:
        try: return len(self.encoder.encode(text))
        except: return len(text) // 4
    
    def _truncate_context(self, context: str, max_tokens: int = 4000) -> str:
        tokens = self._count_tokens(context)
        if tokens <= max_tokens: return context
        words = context.split()
        result = []; current = 0
        for word in words:
            w_tokens = self._count_tokens(word)
            if current + w_tokens > max_tokens: break
            result.append(word); current += w_tokens
        return " ".join(result) + "\n\n... (تم اختصار السياق)"
    
    async def add_message(self, role: str, content: str):
        db = next(get_db())
        try:
            msg = Message(user_id=self.user_id, role=role, content=content)
            db.add(msg); db.commit()
            doc_id = f"{role}_{hashlib.md5(content.encode()).hexdigest()[:8]}"
            await self.vector_store.add_document(doc_id, content, {"role": role})
            await self._clean_old_messages()
        finally: db.close()
    
    async def _clean_old_messages(self):
        db = next(get_db())
        try:
            count = db.query(Message).filter(Message.user_id == self.user_id).count()
            if count > self.limit:
                oldest = db.query(Message).filter(Message.user_id == self.user_id).order_by(Message.timestamp.asc()).limit(count - self.limit).all()
                for msg in oldest:
                    doc_id = f"{msg.role}_{hashlib.md5(msg.content.encode()).hexdigest()[:8]}"
                    await self.vector_store.delete_document(doc_id)
                    db.delete(msg)
                db.commit()
        finally: db.close()
    
    async def get_context(self, query: str, limit: int = 10, max_tokens: int = 4000) -> str:
        results = await self.vector_store.search(query, n_results=limit)
        if results:
            context = "\n".join([f"• {r}" for r in results[:5]])
        else:
            db = next(get_db())
            try:
                messages = db.query(Message).filter(Message.user_id == self.user_id).order_by(Message.timestamp.desc()).limit(10).all()
                context = "\n".join([f"{m.role}: {m.content}" for m in messages[::-1]])
            finally: db.close()
        return self._truncate_context(context, max_tokens)
    
    async def add_document(self, content: str, metadata: dict = None):
        chunks = [content[i:i+500] for i in range(0, len(content), 500)]
        for i, chunk in enumerate(chunks):
            doc_id = f"doc_{hashlib.md5(chunk.encode()).hexdigest()[:8]}_{i}"
            await self.vector_store.add_document(doc_id, chunk, metadata or {})