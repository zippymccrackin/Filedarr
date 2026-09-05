from multiprocessing import freeze_support
from app import create_app
import uvicorn

if __name__ == "__main__":
    freeze_support()
    uvicorn.run(create_app(), host="0.0.0.0", port=3565,
                loop="asyncio", http="h11", timeout_graceful_shutdown=5)
