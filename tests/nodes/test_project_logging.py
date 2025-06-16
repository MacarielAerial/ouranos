

logger = logging.getLogger(__name__)


def test_default_logging() -> None:
    default_logging()

    logger.info("Logging module test message")
