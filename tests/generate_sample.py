import asyncio
from server.main import build_dashboard_context
from server.services.renderer import render_dashboard_image

async def run():
    ctx = await build_dashboard_context()
    img_bytes, fmt = await render_dashboard_image(ctx, force_refresh=True)
    with open("tests/sample_render.png", "wb") as f:
        f.write(img_bytes)
    print(f"Render successful! Size: {len(img_bytes)} bytes, Format: {fmt}")

if __name__ == "__main__":
    asyncio.run(run())