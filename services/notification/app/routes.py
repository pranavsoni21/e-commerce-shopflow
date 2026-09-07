from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Optional
import boto3
import os
import logging

router = APIRouter()
logger = logging.getLogger(__name__)

AWS_REGION = os.getenv("AWS_REGION", "ap-south-1")
SES_SENDER = os.getenv("SES_SENDER_EMAIL", "psoniradhe177@gmail.com")
# In production, user emails come from user-svc lookup.
# Simulated here for simplicity.
MOCK_USER_EMAILS = {
    1: "pranavsoni181@gmail.com",
    2: "psoniradhe177@gmail.com",
}


class NotificationRequest(BaseModel):
    user_id: int
    type: str   # order_created | order_shipped | order_delivered | promo
    message: str
    subject: Optional[str] = None

class NotificationResponse(BaseModel):
    success: bool
    message_id: Optional[str] = None
    detail: str


def send_email_via_ses(to_email: str, subject: str, body: str):
    """Send email using AWS SES. Falls back to logging in dev."""
    try:
        client = boto3.client("ses", region_name=AWS_REGION)
        response = client.send_email(
            Source=SES_SENDER,
            Destination={"ToAddresses": [to_email]},
            Message={
                "Subject": {"Data": subject},
                "Body": {"Text": {"Data": body}},
            },
        )
        return response["MessageId"]
    except Exception as e:
        logger.error(f"SES send failed: {str(e)}")
        raise


@router.post("/notify", response_model=NotificationResponse)
async def send_notification(
    payload: NotificationRequest,
    background_tasks: BackgroundTasks
):
    user_email = MOCK_USER_EMAILS.get(payload.user_id)
    if not user_email:
        # Don't hard fail — user might not have email on file
        logger.warning(f"No email found for user_id={payload.user_id}")
        return NotificationResponse(
            success=False,
            detail=f"No email registered for user {payload.user_id}"
        )

    subject_map = {
        "order_created": "Your ShopFlow order has been placed!",
        "order_shipped": "Your ShopFlow order is on its way!",
        "order_delivered": "Your ShopFlow order has been delivered!",
        "promo": "Special offer from ShopFlow",
    }
    subject = payload.subject or subject_map.get(payload.type, "ShopFlow Notification")

    # Send in background so we don't block the order service waiting for SES
    background_tasks.add_task(send_email_via_ses, user_email, subject, payload.message)

    return NotificationResponse(success=True, detail="Notification queued")


@router.get("/notify/health")
def notify_health():
    return {"status": "ok", "ses_sender": SES_SENDER}
