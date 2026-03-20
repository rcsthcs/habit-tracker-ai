import logging
import smtplib
from email.message import EmailMessage

from app.config import get_settings

logger = logging.getLogger(__name__)


def _smtp_configured() -> bool:
    settings = get_settings()
    return bool(
        settings.SMTP_HOST
        and settings.SMTP_PORT
        and settings.SMTP_FROM_EMAIL
    )


async def send_verification_email(email: str, username: str, token: str) -> bool:
    settings = get_settings()
    if not _smtp_configured():
        logger.warning("SMTP not configured; verification email to %s skipped", email)
        return False

    verify_url = f"{settings.BACKEND_PUBLIC_URL.rstrip('/')}/api/auth/verify-email?token={token}"

    msg = EmailMessage()
    msg["Subject"] = "Подтверждение почты — Habit Tracker AI"
    msg["From"] = f"{settings.SMTP_FROM_NAME} <{settings.SMTP_FROM_EMAIL}>"
    msg["To"] = email
    msg.set_content(
        (
            f"Привет, {username}!\n\n"
            f"Подтверди почту, перейдя по ссылке:\n{verify_url}\n\n"
            "Если это были не вы, просто проигнорируйте письмо."
        )
    )

    try:
        if settings.SMTP_USE_TLS:
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=20) as smtp:
                smtp.starttls()
                if settings.SMTP_USER:
                    smtp.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                smtp.send_message(msg)
        else:
            with smtplib.SMTP_SSL(settings.SMTP_HOST, settings.SMTP_PORT, timeout=20) as smtp:
                if settings.SMTP_USER:
                    smtp.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                smtp.send_message(msg)

        return True
    except Exception as exc:
        logger.error("Failed to send verification email to %s: %s", email, exc)
        return False