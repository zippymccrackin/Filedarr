from quart import Blueprint, render_template
import os

dashboard_bp = Blueprint("dashboard", __name__)

@dashboard_bp.route("/")
async def dashboard():
    return await render_template("dashboard.html")