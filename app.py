from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uuid
from api.routes import router
from core.rate_limit import RateLimiter
from core.logging import setup_logging
from config import settings
from database import Base, engine
from logger import logger

Base.metadata.create_all(bind=engine)
rate_limiter = RateLimiter(redis_url=settings.REDIS_URL, max_requests=settings.RATE_LIMIT_MAX, window=settings.RATE_LIMIT_WINDOW)
setup_logging()

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 NEXUS-ULTIMATE v4.1 starting...")
    yield
    logger.info("🛑 Shutting down...")
    from utils.intent_router import IntentRouter
    from utils.model_router import ModelRouter
    from utils.search_engine import SearchEngine
    from utils.file_analyzer import FileAnalyzer
    await IntentRouter.close_client()
    await ModelRouter.close_client()
    await SearchEngine.close_client()
    await FileAnalyzer.close_client()

app = FastAPI(title="NEXUS-ULTIMATE API", version="4.1.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_credentials=False, allow_methods=["GET","POST","PUT","DELETE"], allow_headers=["Authorization","Content-Type","X-Request-ID"])
app.include_router(router)

@app.middleware("http")
async def add_request_id(request, call_next):
    request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
    logger.info(f"📨 Request {request_id} | {request.method} {request.url.path}")
    response = await call_next(request)
    response.headers["X-Request-ID"] = request_id
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    return response

@app.get("/health")
async def health(): return {"status": "OK", "version": "4.1.0"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app:app", host="0.0.0.0", port=8000, reload=True)