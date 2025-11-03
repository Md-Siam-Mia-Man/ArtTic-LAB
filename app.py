import argparse
import logging
import sys
import os
import signal
import torch
import warnings
from helpers.cli_manager import (
    setup_logging,
    log_system_info,
    APP_LOGGER_NAME,
    setup_web_logging,
)

warnings.filterwarnings("ignore", ".*safety_checker.*")
warnings.filterwarnings("ignore", ".*You have disabled the safety checker.*")
warnings.filterwarnings("ignore", category=UserWarning)

parser = argparse.ArgumentParser(
    description="ArtTic-LAB: A clean UI for Intel ARC GPUs."
)
parser.add_argument(
    "--disable-filters", action="store_true", help="Disable custom log filters."
)
parser.add_argument(
    "--host", type=str, default="127.0.0.1", help="Host address to bind the server to."
)
parser.add_argument("--port", type=int, default=7860, help="Port to run the server on.")
parser.add_argument(
    "--share", action="store_true", help="Create a public link using ngrok."
)

args = parser.parse_args()

setup_logging(disable_filters=args.disable_filters)
logger = logging.getLogger(APP_LOGGER_NAME)


def signal_handler(sig, frame):
    print("\n")
    logger.info("Ctrl+C detected. Shutting down ArtTic-LAB gracefully...")
    sys.exit(0)


def launch_web_ui():
    try:
        import uvicorn
        from web.server import app as fastapi_app
    except ImportError:
        logger.error("Required packages for the custom UI are not installed.")
        logger.error("Please run the installer (install.bat or install.sh) again.")
        sys.exit(1)

    if args.share:
        try:
            from pyngrok import ngrok

            public_url = ngrok.connect(args.port)
            logger.info(f"Public ArtTic-LAB URL: {public_url}")
            logger.info("This link is now accessible from anywhere.")
        except ImportError:
            logger.error("Could not create public link. `pyngrok` is not installed.")
        except Exception as e:
            logger.error(f"Ngrok error: {e}")
            logger.error(
                "Could not create public link. Ensure your ngrok authtoken is configured if required."
            )

    logger.info("Launching custom web UI...")

    if not args.disable_filters:
        setup_web_logging()
        log_level = "warning"
    else:
        log_level = "info"

    logger.info(f"Access ArtTic-LAB locally at http://{args.host}:{args.port}")
    logger.info("Press Ctrl+C in this terminal to shutdown.")

    config = uvicorn.Config(
        fastapi_app, host=args.host, port=args.port, log_level=log_level
    )
    server = uvicorn.Server(config)
    server.run()


if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    if not args.disable_filters:
        os.system("cls" if os.name == "nt" else "clear")
    os.makedirs("./outputs", exist_ok=True)

    log_system_info()
    launch_web_ui()
