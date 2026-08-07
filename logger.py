import logging, sys
from logging.handlers import RotatingFileHandler
def setup_logger(name="NEXUS", level=logging.INFO):
    logger = logging.getLogger(name)
    logger.setLevel(level)
    if logger.hasHandlers(): return logger
    fmt = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(fmt)
    logger.addHandler(ch)
    fh = RotatingFileHandler(f"{name.lower()}.log", maxBytes=10_485_760, backupCount=5)
    fh.setFormatter(fmt)
    logger.addHandler(fh)
    return logger
logger = setup_logger()