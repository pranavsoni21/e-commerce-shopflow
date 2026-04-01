import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.database import Base, get_db

SQLALCHEMY_TEST_URL = "sqlite:///./test_product.db"
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

def test_create_product():
    response = client.post("/api/v1/products", json={
        "name": "Test Laptop",
        "description": "A great laptop",
        "price": 999.99,
        "stock": 50,
        "category": "electronics",
        "sku": "LAPTOP-001"
    })
    assert response.status_code == 201
    assert response.json()["sku"] == "LAPTOP-001"

def test_list_products():
    response = client.get("/api/v1/products")
    assert response.status_code == 200
    assert isinstance(response.json(), list)

def test_get_product_not_found():
    response = client.get("/api/v1/products/99999")
    assert response.status_code == 404
