from app import app
import uvicorn

if __name__ == "__main__":
    uvicorn.run("app:app", host="0.0.0.0", port=3565, loop="asyncio", http="h11", reload=True, timeout_keep_alive=120, timeout_graceful_shutdown=5)
    