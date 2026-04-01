from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
import httpx
import os

from app.database import get_db
from app.models import Order, OrderItem, OrderStatus

router = APIRouter()

NOTIFICATION_SVC_URL = os.getenv("NOTIFICATION_SVC_URL", "http://notification-svc:8000")


# --- Schemas ---
class OrderItemIn(BaseModel):
    product_id: int
    quantity: int
    unit_price: float

class OrderCreate(BaseModel):
    user_id: int
    shipping_address: str
    items: List[OrderItemIn]

class OrderItemOut(BaseModel):
    id: int
    product_id: int
    quantity: int
    unit_price: float

    class Config:
        from_attributes = True

class OrderOut(BaseModel):
    id: int
    user_id: int
    status: OrderStatus
    total_amount: float
    shipping_address: str
    items: List[OrderItemOut]

    class Config:
        from_attributes = True

class StatusUpdate(BaseModel):
    status: OrderStatus


# --- Routes ---
@router.post("/orders", response_model=OrderOut, status_code=201)
async def create_order(payload: OrderCreate, db: Session = Depends(get_db)):
    total = sum(item.quantity * item.unit_price for item in payload.items)
    order = Order(
        user_id=payload.user_id,
        shipping_address=payload.shipping_address,
        total_amount=total,
    )
    db.add(order)
    db.flush()

    for item in payload.items:
        db.add(OrderItem(
            order_id=order.id,
            product_id=item.product_id,
            quantity=item.quantity,
            unit_price=item.unit_price,
        ))

    db.commit()
    db.refresh(order)

    # Fire-and-forget notification (don't fail order if notif svc is down)
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            await client.post(f"{NOTIFICATION_SVC_URL}/api/v1/notify", json={
                "user_id": payload.user_id,
                "type": "order_created",
                "message": f"Your order #{order.id} has been placed successfully."
            })
    except Exception:
        pass  # Log in production, don't fail the request

    return order

@router.get("/orders/{order_id}", response_model=OrderOut)
def get_order(order_id: int, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    return order

@router.get("/orders/user/{user_id}", response_model=List[OrderOut])
def get_user_orders(user_id: int, db: Session = Depends(get_db)):
    return db.query(Order).filter(Order.user_id == user_id).all()

@router.patch("/orders/{order_id}/status", response_model=OrderOut)
def update_order_status(order_id: int, payload: StatusUpdate, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Order not found")
    order.status = payload.status
    db.commit()
    db.refresh(order)
    return order
