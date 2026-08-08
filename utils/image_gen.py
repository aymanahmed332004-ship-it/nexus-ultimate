import os
import json
import base64
import httpx
from config import settings
from logger import logger
import google.genai as genai

class ImageGenerator:
    def __init__(self):
        self.api_key = settings.GEMINI_API_KEY
        if not self.api_key:
            raise ValueError("❌ GEMINI_API_KEY not found in Secrets")
        self.client = genai.Client(api_key=self.api_key)

    async def generate(self, prompt: str) -> str:
        try:
            response = self.client.models.generate_content(
                model="gemini-2.0-flash-exp-image-generation",
                contents=prompt,
                config=genai.types.GenerateContentConfig(
                    response_modalities=['Text', 'Image']
                )
            )

            for part in response.candidates[0].content.parts:
                if part.text is not None:
                    logger.info(f"Gemini description: {part.text}")
                elif part.inline_data is not None:
                    image_data = part.inline_data.data
                    with open("generated_image.png", "wb") as f:
                        f.write(image_data)
                    logger.info("✅ Image generated successfully")
                    return "Image generated locally as generated_image.png"

            return "No image was generated"
        except Exception as e:
            logger.error(f"Gemini generation error: {e}")
            return f"Error: {str(e)}"