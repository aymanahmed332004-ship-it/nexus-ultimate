
---

### 7. `config.py`

```python
import os
from dotenv import load_dotenv
load_dotenv()
class Settings:
    GROQ_API_KEY = os.getenv("GROQ_API_KEY")
    OPENROUTER_KEY = os.getenv("OPENROUTER_KEY")
    ASSEMBLYAI_KEY = os.getenv("ASSEMBLYAI_KEY")
    CLOUDFLARE_KEY = os.getenv("CLOUDFLARE_KEY")
    TAVILY_API_KEY = os.getenv("TAVILY_API_KEY")
    DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://nexus:nexus123@postgres/nexus")
    REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379")
    SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here")
    JWT_EXPIRY_DAYS = int(os.getenv("JWT_EXPIRY_DAYS", 7))
    FREE_DAILY_LIMIT = 30
    BASIC_DAILY_LIMIT = 500
    PREMIUM_DAILY_LIMIT = 10000
    MEMORY_LIMIT = int(os.getenv("MEMORY_LIMIT", 1000))
    RATE_LIMIT_MAX = int(os.getenv("RATE_LIMIT_MAX", 30))
    RATE_LIMIT_WINDOW = int(os.getenv("RATE_LIMIT_WINDOW", 60))
    ALLOWED_ORIGINS = os.getenv("ALLOWED_ORIGINS", "http://localhost:3000,http://localhost:8000")
    @property
    def cors_origins(self):
        if self.ALLOWED_ORIGINS == "*": return ["*"]
        return [o.strip() for o in self.ALLOWED_ORIGINS.split(",")]
    TTS_TIMEOUT = 30
    OCR_TIMEOUT = 60
    API_TIMEOUT = 60
    DEBUG = os.getenv("DEBUG", "False").lower() == "true"
settings = Settings()