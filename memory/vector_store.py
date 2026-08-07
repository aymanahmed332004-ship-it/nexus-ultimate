import chromadb
from chromadb.config import Settings
from logger import logger
import os, asyncio

class VectorStore:
    _locks = {}
    def __init__(self, user_id: int):
        self.user_id = user_id
        if user_id not in VectorStore._locks:
            VectorStore._locks[user_id] = asyncio.Lock()
        self.lock = VectorStore._locks[user_id]
        persist_dir = f"./chroma_db/user_{user_id}"
        os.makedirs(persist_dir, exist_ok=True)
        self.client = chromadb.PersistentClient(path=persist_dir, settings=Settings(anonymized_telemetry=False))
        self.collection = self.client.get_or_create_collection(f"user_{user_id}")
    
    async def add_document(self, doc_id: str, content: str, metadata: dict = None):
        async with self.lock:
            try: self.collection.add(documents=[content], ids=[doc_id], metadatas=[metadata or {}])
            except Exception as e: logger.error(f"Vector add error: {e}")
    
    async def search(self, query: str, n_results: int = 10) -> list:
        async with self.lock:
            try:
                results = self.collection.query(query_texts=[query], n_results=n_results)
                return results['documents'][0] if results['documents'] else []
            except Exception as e: logger.error(f"Vector search error: {e}"); return []
    
    async def delete_document(self, doc_id: str):
        async with self.lock:
            try: self.collection.delete(ids=[doc_id])
            except Exception as e: logger.error(f"Vector delete error: {e}")