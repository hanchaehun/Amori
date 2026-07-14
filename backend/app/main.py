import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin

from app.config import settings
from app.db.session import engine
from app.models.database import Base
from app.middleware.error_handler import error_handler_middleware
from app.services.auto_sim import auto_sim_scheduler


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    if not firebase_admin._apps:
        firebase_admin.initialize_app(options={"projectId": settings.firebase_project_id})
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    # 에이전트 자동 소개팅 스케줄러 (하루 랜덤 N회) — AUTO_SIM_ENABLED=true 일 때만
    scheduler_task = (
        asyncio.create_task(auto_sim_scheduler()) if settings.auto_sim_enabled else None
    )
    yield
    # Shutdown
    if scheduler_task is not None:
        scheduler_task.cancel()
    await engine.dispose()


app = FastAPI(title="AMORI BFF API", version="0.1.1", lifespan=lifespan)

app.middleware("http")(error_handler_middleware)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.routers.health import router as health_router
from app.routers.users import router as users_router
from app.routers.persona import router as persona_router
from app.routers.matches import router as matches_router
from app.routers.simulation import router as simulation_router
from app.routers.report import router as report_router
from app.routers.meet import router as meet_router
from app.routers.feedback import router as feedback_router

app.include_router(health_router, tags=["health"])
app.include_router(users_router, prefix="/users", tags=["users"])
app.include_router(persona_router, prefix="/persona", tags=["persona"])
app.include_router(matches_router, prefix="/matches", tags=["matches"])
app.include_router(simulation_router, prefix="/simulation", tags=["simulation"])
app.include_router(report_router, prefix="/report", tags=["report"])
app.include_router(meet_router, prefix="/meet", tags=["meet"])
app.include_router(feedback_router, prefix="/feedback", tags=["feedback"])
