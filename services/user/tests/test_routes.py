import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.database import Base, get_db

# Use SQLite for tests (no real DB needed in CI)
SQLALCHEMY_TEST_URL = "sqlite:///./test.db"
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
    assert response.json()["status"] == "healthy"

def test_register_user():
    response = client.post("/api/v1/register", json={
        "email": "test@shopflow.com",
        "password": "securepass123",
        "full_name": "Test User"
    })
    assert response.status_code == 201
    assert response.json()["email"] == "test@shopflow.com"

def test_register_duplicate_email():
    client.post("/api/v1/register", json={
        "email": "dup@shopflow.com",
        "password": "pass123",
        "full_name": "Dup User"
    })
    response = client.post("/api/v1/register", json={
        "email": "dup@shopflow.com",
        "password": "pass123",
        "full_name": "Dup User"
    })
    assert response.status_code == 400

def test_login():
    client.post("/api/v1/register", json={
        "email": "login@shopflow.com",
        "password": "mypassword",
        "full_name": "Login User"
    })
    response = client.post("/api/v1/login", data={
        "username": "login@shopflow.com",
        "password": "mypassword"
    })
    assert response.status_code == 200
    assert "access_token" in response.json()

def test_get_me():
    client.post("/api/v1/register", json={
        "email": "me@shopflow.com",
        "password": "mypassword",
        "full_name": "Me User"
    })
    login = client.post("/api/v1/login", data={
        "username": "me@shopflow.com",
        "password": "mypassword"
    })
    token = login.json()["access_token"]
    response = client.get("/api/v1/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["email"] == "me@shopflow.com"
