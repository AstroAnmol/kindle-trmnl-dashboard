import pytest
from httpx import AsyncClient, ASGITransport
from server.main import app

@pytest.mark.asyncio
async def test_setup_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/api/setup")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == 200
        assert "Connected to self-hosted TRMNL" in data["message"]

@pytest.mark.asyncio
async def test_telemetry_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        payload = {
            "device_id": "00:11:22:33:44:55",
            "battery_percent": 92,
            "battery_voltage": 4.05,
            "signal_strength": -58
        }
        response = await client.post("/api/log", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == 200
        assert data["current_state"]["battery_percent"] == 92
        assert data["current_state"]["wifi_bars"] == 3

@pytest.mark.asyncio
async def test_data_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/api/data")
        assert response.status_code == 200
        data = response.json()
        assert "weather" in data
        assert "calendar" in data
        assert "tasks" in data
        assert "telemetry" in data
        assert "now_time" in data

@pytest.mark.asyncio
async def test_display_endpoint():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        headers = {"ID": "00:11:22:33:44:55"}
        response = await client.get("/api/display", headers=headers)
        assert response.status_code == 200
        assert "Refresh-Rate" in response.headers
        assert "Image-Format" in response.headers
        assert len(response.content) > 100
        assert response.headers["Image-Format"] in ["png", "bmp"]