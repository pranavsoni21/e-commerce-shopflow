import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.database import Base, get_db

SQLALCHEMY_TEST_URL = "sqlite:///./test_order.db"
engine = create_engine(SQLALCHEMY_TEST_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base.metadata.create_all(bind=engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200

def test_create_order():
    response = client.post("/api/v1/orders", json={
        "user_id": 1,
        "shipping_address": "123 Main St, Indore, MP",
        "items": [
            {"product_id": 1, "quantity": 2, "unit_price": 999.99},
            {"product_id": 2, "quantity": 1, "unit_price": 49.99}
        ]
    })
    assert response.status_code == 201
    data = response.json()
    assert data["user_id"] == 1
    assert data["total_amount"] == pytest.approx(2049.97)
    assert data["status"] == "pending"

def test_get_order():
    create = client.post("/api/v1/orders", json={
        "user_id": 2,
        "shipping_address": "456 Park Ave",
        "items": [{"product_id": 3, "quantity": 1, "unit_price": 199.99}]
    })
    order_id = create.json()["id"]
    response = client.get(f"/api/v1/orders/{order_id}")
    assert response.status_code == 200
    assert response.json()["id"] == order_id

def test_get_order_not_found():
    response = client.get("/api/v1/orders/99999")
    assert response.status_code == 404

def test_get_user_orders():
    response = client.get("/api/v1/orders/user/1")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_update_order_status():
    create = client.post("/api/v1/orders", json={
        "user_id": 3,
        "shipping_address": "789 Oak St",
        "items": [{"product_id": 4, "quantity": 1, "unit_price": 59.99}]
    })
    order_id = create.json()["id"]
    response = client.patch(f"/api/v1/orders/{order_id}/status", json={"status": "confirmed"})
    assert response.status_code == 200
    assert response.json()["status"] == "confirmed"
