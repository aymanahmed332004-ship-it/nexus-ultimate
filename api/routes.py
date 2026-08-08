from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, AsyncGenerator
import json, asyncio, os, aiofiles
from api.dependencies import get_current_user
from agents.manager import AgentManager
from memory.manager import MemoryManager
from utils.model_router import ModelRouter
from utils.voice_engine import VoiceEngine
from utils.file_analyzer import FileAnalyzer
from utils.search_engine import SearchEngine
from utils.intent_router import IntentRouter
from utils.image_gen import ImageGenerator
from core.security import Security
from models.user import User
from database import get_db
from sqlalchemy.orm import Session
from logger import logger

router = APIRouter()

class LoginRequest(BaseModel): username: str; password: str
class AskRequest(BaseModel): query: str; language: Optional[str] = "auto"; deep_thinking: Optional[bool] = False
class VoiceRequest(BaseModel): text: str; language: Optional[str] = "ar"
class SearchRequest(BaseModel): query: str; sources: Optional[list] = ["web"]
class RefreshTokenRequest(BaseModel): token: str

@router.get("/")
async def home():
    return {"status": "✅ NEXUS-ULTIMATE v4.1 is running!", "features": ["Multi-Agent", "RAG Memory", "Voice TTS", "File Analysis", "Streaming", "JWT Auth", "Rate Limiting", "Intent Classification", "Multi-Source Search", "Image Generation"]}

@router.post("/auth/login")
async def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == request.username).first()
    if not user or not Security.verify_password(request.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return {"access_token": Security.create_token(user.id, "access"), "refresh_token": Security.create_token(user.id, "refresh"), "user_id": user.id}

@router.post("/auth/refresh")
async def refresh(request: RefreshTokenRequest):
    try: return {"access_token": Security.refresh_token(request.token)}
    except Exception as e: raise HTTPException(status_code=401, detail=str(e))

@router.post("/ask")
async def ask(request: AskRequest, current_user: User = Depends(get_current_user)):
    try:
        if request.language == "auto":
            intent_router = IntentRouter()
            request.language = await intent_router.detect_language(request.query, current_user.id)
        memory = MemoryManager(current_user.id)
        context = await memory.get_context(request.query)
        agent = await AgentManager.get_agent(request.query, current_user.id)
        response = await agent.process(request.query, context, request.language, current_user.id)
        await memory.add_message("user", request.query)
        await memory.add_message("assistant", response)
        return {"response": response, "detected_language": request.language, "agent_used": agent.name}
    except Exception as e: raise HTTPException(status_code=500, detail=str(e))

@router.post("/ask/stream")
async def ask_stream(request: AskRequest, current_user: User = Depends(get_current_user)):
    async def generate() -> AsyncGenerator:
        try:
            memory = MemoryManager(current_user.id)
            context = await memory.get_context(request.query)
            agent = await AgentManager.get_agent(request.query, current_user.id)
            async for chunk in agent.process_stream(request.query, context, request.language, current_user.id):
                yield f"data: {json.dumps({'content': chunk})}\n\n"
            await memory.add_message("user", request.query)
            await memory.add_message("assistant", "Streaming complete")
        except asyncio.CancelledError:
            yield f"data: {json.dumps({'error': 'Stream cancelled'})}\n\n"
        except Exception as e:
            logger.error(f"Stream error: {e}")
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
        finally: yield "data: [DONE]\n\n"
    return StreamingResponse(generate(), media_type="text/event-stream")

@router.post("/text_to_speech")
async def text_to_speech(request: VoiceRequest, current_user: User = Depends(get_current_user)):
    try:
        voice = VoiceEngine()
        audio_base64 = await voice.generate_speech(request.text, request.language)
        return {"audio": audio_base64}
    except Exception as e: raise HTTPException(status_code=500, detail=str(e))

@router.post("/upload_file")
async def upload_file(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    try:
        file_location = f"/tmp/upload_{current_user.id}_{file.filename}"
        async with aiofiles.open(file_location, 'wb') as f:
            content = await file.read()
            await f.write(content)
        
        analyzer = FileAnalyzer()
        result = await analyzer.analyze_local(file_location, current_user.id)
        
        if os.path.exists(file_location): 
            os.remove(file_location)
        return result
    except Exception as e:
        logger.error(f"File upload error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/generate_image")
async def generate_image(
    prompt: str = Form(...),
    current_user: User = Depends(get_current_user)
):
    try:
        generator = ImageGenerator()
        image_url = await generator.generate(prompt)
        return {"image_url": image_url}
    except Exception as e:
        logger.error(f"Image gen error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/search")
async def search(request: SearchRequest, current_user: User = Depends(get_current_user)):
    try:
        engine = SearchEngine()
        return {"results": await engine.search(request.query, sources=request.sources)}
    except Exception as e: raise HTTPException(status_code=500, detail=str(e))

@router.get("/memory")
async def get_memory(current_user: User = Depends(get_current_user)):
    try:
        memory = MemoryManager(current_user.id)
        return {"context": await memory.get_context("")}
    except Exception as e: raise HTTPException(status_code=500, detail=str(e))