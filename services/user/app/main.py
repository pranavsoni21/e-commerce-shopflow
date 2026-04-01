from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routes import router
from app.database import engine, Base

Base.metadata.create_all(bind=engine)

app = FastAPI(title="ShopFlow User Service", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(router, prefix="/api/v1")

@app.get("/health")
def health():
    return {"status": "healthy", "service": "user-svc"}

@app.get("/metrics")
def metrics():
    # Placeholder - prometheus-fastapi-instrumentator handles real metrics
    return {"requests_total": 0}
