from fastapi import Depends, HTTPException, status, Header
from core.security import Security
from core.rate_limit import RateLimiter
from config import settings
from database import get_db
from sqlalchemy.orm import Session
from models.user import User
rate_limiter = RateLimiter(redis_url=settings.REDIS_URL, max_requests=settings.RATE_LIMIT_MAX, window=settings.RATE_LIMIT_WINDOW)
async def get_current_user(authorization: str = Header(...), db: Session = Depends(get_db)) -> User:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid auth header", headers={"WWW-Authenticate": "Bearer"})
    token = authorization.split(" ")[1]
    try:
        payload = Security.verify_token(token)
        user_id = payload.get("user_id")
        if not user_id: raise Exception("Invalid token")
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e), headers={"WWW-Authenticate": "Bearer"})
    user = db.query(User).filter(User.id == user_id).first()
    if not user: raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    if not rate_limiter.is_allowed(user_id): raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail="Too many requests")
    return user