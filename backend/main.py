import os
import time
import socket
import hashlib
from typing import List
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, status, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import psycopg2
from psycopg2.extras import RealDictCursor
from prometheus_fastapi_instrumentator import Instrumentator

DB_HOST = os.getenv("DB_HOST", "postgres-service")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "k8sdb")
DB_USER = os.getenv("DB_USER", "k8suser")
DB_PASSWORD = os.getenv("DB_PASSWORD", "k8spassword")
POD_NAME = os.getenv("POD_NAME", socket.gethostname())


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        connect_timeout=3
    )


def init_db():
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE IF NOT EXISTS tasks (
                id SERIAL PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
        """)
        conn.commit()
        cur.close()
        conn.close()
    except Exception:
        pass


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="K8s Demo API",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

Instrumentator().instrument(app).expose(app)


class TaskCreate(BaseModel):
    title: str


class Task(BaseModel):
    id: int
    title: str
    created_at: str


@app.get("/healthz", status_code=status.HTTP_200_OK)
def liveness_probe():
    return {"status": "healthy", "pod": POD_NAME}


@app.get("/ready")
def readiness_probe(response: Response):
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT 1;")
        cur.close()
        conn.close()
        return {"status": "ready", "database": "connected", "pod": POD_NAME}
    except Exception as e:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "not_ready", "database": "disconnected", "error": str(e), "pod": POD_NAME}


@app.get("/api/info")
def system_info():
    return {
        "pod_name": POD_NAME,
        "database_host": DB_HOST,
        "database_name": DB_NAME
    }


@app.get("/api/tasks")
def get_tasks():
    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute("SELECT id, title, created_at FROM tasks ORDER BY id DESC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()

        for row in rows:
            if row.get("created_at"):
                row["created_at"] = row["created_at"].isoformat()
        return rows
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error: {str(e)}"
        )


@app.post("/api/tasks", status_code=status.HTTP_201_CREATED)
def create_task(task: TaskCreate):
    if not task.title.strip():
        raise HTTPException(status_code=400, detail="Task title cannot be empty")

    try:
        conn = get_db_connection()
        cur = conn.cursor(cursor_factory=RealDictCursor)
        cur.execute(
            "INSERT INTO tasks (title) VALUES (%s) RETURNING id, title, created_at;",
            (task.title.strip(),)
        )
        new_task = cur.fetchone()
        conn.commit()
        cur.close()
        conn.close()

        if new_task.get("created_at"):
            new_task["created_at"] = new_task["created_at"].isoformat()
        return new_task
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database error: {str(e)}"
        )


@app.get("/api/cpu-burn")
def cpu_burn(duration_seconds: float = 2.0):
    duration = min(max(duration_seconds, 0.1), 10.0)
    start_time = time.time()
    iterations = 0

    while time.time() - start_time < duration:
        _ = hashlib.sha256(f"load-test-{iterations}".encode()).hexdigest()
        iterations += 1

    return {
        "status": "completed",
        "pod": POD_NAME,
        "duration_seconds": duration,
        "iterations": iterations
    }
