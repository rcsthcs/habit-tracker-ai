"""
Habit App — AI-powered Habit Tracker Backend
Main FastAPI application entry point.
"""
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.db.database import init_db
from app.api.routes import auth, habits, analytics, chat, recommendations, notifications, admin
from app.notifications.scheduler import create_scheduler
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

scheduler = create_scheduler()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    logger.info("🚀 Starting Habit App Backend...")
    await init_db()
    logger.info("✅ Database initialized")
    scheduler.start()
    logger.info("⏰ Notification scheduler started")
    yield
    scheduler.shutdown()
    logger.info("👋 Shutting down...")


app = FastAPI(
    title="Habit App API",
    description="AI-powered habit tracking backend with ML recommendations and NLP chatbot",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS — allow Flutter app to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to your domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register routes
app.include_router(auth.router, prefix="/api")
app.include_router(habits.router, prefix="/api")
app.include_router(analytics.router, prefix="/api")
app.include_router(chat.router, prefix="/api")
app.include_router(recommendations.router, prefix="/api")
app.include_router(notifications.router, prefix="/api")
app.include_router(admin.router, prefix="/api")


@app.get("/")
async def root():
    return {
        "app": "Habit Tracker AI",
        "version": "1.0.0",
        "docs": "/docs",
        "status": "running",
    }


@app.get("/health")
async def health():
    return {"status": "ok"}

