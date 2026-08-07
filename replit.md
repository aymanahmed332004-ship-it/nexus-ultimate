# NEXUS-ULTIMATE v4.1

A full-stack multi-agent AI platform built with Python/FastAPI.

## Stack

- **Backend**: FastAPI + SQLAlchemy + PostgreSQL + Redis + Celery + ChromaDB
- **Web frontend**: React (`frontend/web/`)
- **Mobile frontend**: Flutter (`frontend/mobile/`)
- **Desktop frontend**: Electron (`frontend/desktop/`)

## Entry point

```bash
uvicorn app:app --reload
```

## Required environment variables

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | PostgreSQL connection string |
| `REDIS_URL` | Redis connection string |
| `SECRET_KEY` | JWT signing secret |
| `GROQ_API_KEY` | Groq LLM API |
| `OPENROUTER_KEY` | OpenRouter LLM API |
| `ASSEMBLYAI_KEY` | Audio transcription |
| `CLOUDFLARE_KEY` | Cloudflare Workers AI |
| `TAVILY_API_KEY` | Web search |

See ` .env.example` for all variables.

## User preferences
