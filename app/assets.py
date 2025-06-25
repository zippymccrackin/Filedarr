import os
from quart import Blueprint, send_from_directory

assets_bp = Blueprint("assets", __name__)

STATIC_IMAGE_PATH = os.path.join(os.getcwd(), "static", "images")

@assets_bp.route('/favicon.ico')
async def favicon():
    return await send_from_directory(STATIC_IMAGE_PATH, 'favicon.ico', mimetype='image/x-icon')

@assets_bp.route('/favicon.svg')
async def faviconsvg():
    return await send_from_directory(STATIC_IMAGE_PATH, 'favicon.svg', mimetype='image/svg+xml')

@assets_bp.route('/apple-touch-icon.png')
async def apple_touch_icon():
    return await send_from_directory(STATIC_IMAGE_PATH, 'apple-touch-icon.png', mimetype='image/png')

@assets_bp.route('/favicon-96x96.png')
async def png_icon_9696():
    return await send_from_directory(STATIC_IMAGE_PATH, 'favicon-96x96.png', mimetype='image/png')

@assets_bp.route('/favicon-32x32.png')
async def png_icon_3232():
    return await send_from_directory(STATIC_IMAGE_PATH, 'favicon-32x32.png', mimetype='image/png')

@assets_bp.route('/favicon-16x16.png')
async def png_icon_1616():
    return await send_from_directory(STATIC_IMAGE_PATH, 'favicon-16x16.png', mimetype='image/png')

@assets_bp.route('/web-app-manifest-192x192.png')
async def png_icon_192192():
    return await send_from_directory(STATIC_IMAGE_PATH, 'web-app-manifest-192x192.png', mimetype='image/png')

@assets_bp.route('/web-app-manifest-512x512.png')
async def png_icon_512512():
    return await send_from_directory(STATIC_IMAGE_PATH, 'web-app-manifest-512x512.png', mimetype='image/png')

@assets_bp.route('/site.webmanifest')
async def site_manifest():
    manifest_path = os.path.join(os.getcwd(), "static")
    return await send_from_directory(manifest_path, 'site.webmanifest', mimetype='application/manifest+json')
