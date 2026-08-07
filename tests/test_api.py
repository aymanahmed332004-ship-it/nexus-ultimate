import pytest
from httpx import AsyncClient
from app import app

@pytest.mark.asyncio
async def test_home():
    async with AsyncClient(app=app, base_url="http://test") as client:
        r = await client.get("/")
        assert r.status_code == 200
        assert "NEXUS-ULTIMATE" in r.json()["status"]

@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(app=app, base_url="http://test") as client:
        r = await client.get("/health")
        assert r.status_code == 200
        assert r.json()["status"] == "OK"