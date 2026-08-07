# NEXUS-ULTIMATE v4.1

منصة ذكاء اصطناعي متكاملة مع:
- Multi-Agent System (Coding, Search, Design)
- RAG Memory with Vector Store
- Voice TTS (edge-tts)
- File Analysis (PDF, DOCX, Images, Audio)
- Streaming Responses (SSE)
- JWT Authentication (with Refresh)
- Redis Rate Limiting
- Intent Classification
- Multi-Source Search (DuckDuckGo + Tavily)

## النشر على Render

1. ارفع الكود على GitHub
2. اربط حساب Render بـ GitHub
3. استخدم ملف `render.yaml` للنشر
4. أضف المتغيرات البيئية المطلوبة

## التشغيل المحلي

```bash
pip install -r requirements.txt
uvicorn app:app --reload