# web/server.py
import asyncio
import logging
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles
from jinja2 import Environment, FileSystemLoader
from core import logic as core

APP_LOGGER_NAME = "arttic_lab"
logger = logging.getLogger(APP_LOGGER_NAME)

app = FastAPI()

app.mount("/static", StaticFiles(directory="web/static"), name="static")
app.mount("/outputs", StaticFiles(directory="outputs"), name="outputs")

env = Environment(loader=FileSystemLoader("web/templates"))
index_template = env.get_template("index.html")


@app.get("/", response_class=HTMLResponse)
async def read_root():
    return index_template.render()


@app.get("/api/config")
async def get_initial_config():
    return core.get_config()


class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.active_connections:
            await connection.send_json(message)


manager = ConnectionManager()


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_json()
            action = data.get("action")
            payload = data.get("payload", {})

            async def progress_callback(progress, desc):
                await websocket.send_json(
                    {
                        "type": "progress_update",
                        "data": {"progress": progress, "description": desc},
                    }
                )

            try:
                if action == "load_model":
                    result = await asyncio.to_thread(
                        core.load_model, **payload, progress_callback=progress_callback
                    )
                    await websocket.send_json({"type": "model_loaded", "data": result})

                elif action == "generate_image":
                    result = await asyncio.to_thread(
                        core.generate_image,
                        **payload,
                        progress_callback=progress_callback,
                    )
                    await websocket.send_json(
                        {"type": "generation_complete", "data": result}
                    )
                    await manager.broadcast(
                        {
                            "type": "gallery_updated",
                            "data": {"images": core.get_output_images()},
                        }
                    )

                elif action == "unload_model":
                    result = await asyncio.to_thread(core.unload_model)
                    await websocket.send_json(
                        {"type": "model_unloaded", "data": result}
                    )

                elif action == "delete_image":
                    filename = payload.get("filename")
                    result = await asyncio.to_thread(core.delete_image, filename)
                    await websocket.send_json({"type": "image_deleted", "data": result})
                    await manager.broadcast(
                        {
                            "type": "gallery_updated",
                            "data": {"images": core.get_output_images()},
                        }
                    )

                else:
                    logger.warning(f"Unknown WebSocket action received: {action}")

            except Exception as e:
                logger.error(f"Error processing action '{action}': {e}", exc_info=True)
                await websocket.send_json(
                    {"type": "error", "data": {"message": str(e)}}
                )

    except WebSocketDisconnect:
        logger.info("Client disconnected.")
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"An unexpected error occurred in WebSocket: {e}", exc_info=True)
        manager.disconnect(websocket)
