import logging
import logging.config
from importlib.resources import files  # nosemgrep

import ouranos


def default_logging() -> None:
    """Initiates logging setting based on default settings"""
    config_file_default_logging = files(ouranos) / "conf_default" / "logging.ini"
    logging.config.fileConfig(
        str(config_file_default_logging), disable_existing_loggers=False
    )


def fastapi_logging() -> None:
    default_logging()
    logging.getLogger("httpcore").setLevel(logging.INFO)
    logging.getLogger("urllib3").setLevel(logging.INFO)
