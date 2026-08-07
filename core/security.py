import jwt
from datetime import datetime, timedelta
from passlib.context import CryptContext
from config import settings
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
class Security:
    @staticmethod
    def hash_password(password: str) -> str: return pwd_context.hash(password)
    @staticmethod
    def verify_password(plain: str, hashed: str) -> bool: return pwd_context.verify(plain, hashed)
    @staticmethod
    def create_token(user_id: int, token_type: str = "access") -> str:
        exp = timedelta(days=settings.JWT_EXPIRY_DAYS if token_type == "access" else 30)
        return jwt.encode({"user_id": user_id, "type": token_type, "exp": datetime.utcnow() + exp}, settings.SECRET_KEY, algorithm="HS256")
    @staticmethod
    def refresh_token(token: str) -> str:
        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
            if payload.get("type") != "refresh": raise Exception("Invalid token type")
            return Security.create_token(payload["user_id"], "access")
        except Exception as e: raise Exception(f"Refresh failed: {e}")
    @staticmethod
    def verify_token(token: str) -> dict:
        try: return jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        except jwt.ExpiredSignatureError: raise Exception("Token expired")
        except jwt.InvalidTokenError: raise Exception("Invalid token")