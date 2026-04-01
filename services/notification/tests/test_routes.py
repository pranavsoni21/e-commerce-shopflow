from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["service"] == "notification-svc"

def test_notify_known_user():
    response = client.post("/api/v1/notify", json={
        "user_id": 1,
        "type": "order_created",
        "message": "Your order #42 has been placed."
    })
    assert response.status_code == 200
    assert response.json()["success"] == True

def test_notify_unknown_user():
    response = client.post("/api/v1/notify", json={
        "user_id": 9999,
        "type": "order_created",
        "message": "Test message"
    })
    assert response.status_code == 200
    assert response.json()["success"] == False

def test_notify_health():
    response = client.get("/api/v1/notify/health")
    assert response.status_code == 200
