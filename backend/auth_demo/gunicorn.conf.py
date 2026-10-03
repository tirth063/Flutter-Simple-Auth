import os

workers = int(os.environ.get("GUNICORN_WORKERS", "2"))
threads = int(os.environ.get("GUNICORN_THREADS", "4"))
worker_class = "gthread"
bind = os.environ.get("GUNICORN_BIND", "0.0.0.0:8000")
timeout = 120
keepalive = 5
errorlog = "-"
accesslog = "-"
loglevel = os.environ.get("LOG_LEVEL", "info")
