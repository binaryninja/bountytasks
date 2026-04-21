import asyncio

from fastapi import Request
from lightning.app import LightningFlow, LightningApp
from fastapi.responses import HTMLResponse
from lightning.app.core.api import LightningUvicornServer
import lightning.app.core.api as lightning_api


def _patched_run(self, sockets=None):
    setup_event_loop = getattr(self.config, "setup_event_loop", None)
    if callable(setup_event_loop):
        try:
            setup_event_loop()
        except AttributeError as ex:
            if "get_loop_factory" not in str(ex):
                raise

    async def _serve() -> None:
        serve_task = asyncio.create_task(self.serve(sockets=sockets))
        if self.has_started_queue:
            asyncio.create_task(self.check_is_started(self.has_started_queue))
        await serve_task

    asyncio.run(_serve())


LightningUvicornServer.run = _patched_run


async def _patched_frontend_route(request: Request, full_path: str):
    return HTMLResponse("<!doctype html><html><body>Lightning</body></html>")


lightning_api.frontend_route = _patched_frontend_route

class SimpleFlow(LightningFlow):
    def run(self):
        pass

app = LightningApp(SimpleFlow())
