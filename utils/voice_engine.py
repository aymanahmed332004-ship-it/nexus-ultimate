import edge_tts, base64, tempfile, os, asyncio
from config import settings
from logger import logger

class VoiceEngine:
    VOICES = {"ar":"ar-EG-SalmaNeural","en":"en-US-JennyNeural","fr":"fr-FR-DeniseNeural","es":"es-ES-ElviraNeural","de":"de-DE-KatjaNeural","it":"it-IT-ElsaNeural","ru":"ru-RU-DariyaNeural","pt":"pt-BR-FranciscaNeural"}
    async def generate_speech(self, text: str, language: str = "ar") -> str:
        try:
            voice = self.VOICES.get(language, "ar-EG-SalmaNeural")
            async with asyncio.timeout(settings.TTS_TIMEOUT):
                with tempfile.NamedTemporaryFile(delete=False, suffix='.mp3') as tmp:
                    output_file = tmp.name
                await edge_tts.Communicate(text, voice).save(output_file)
                with open(output_file, 'rb') as f:
                    audio_base64 = base64.b64encode(f.read()).decode('utf-8')
                os.remove(output_file)
                return audio_base64
        except asyncio.TimeoutError: logger.error(f"TTS timeout"); return ""
        except Exception as e: logger.error(f"TTS error: {e}"); return ""