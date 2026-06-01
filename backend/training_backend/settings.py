import os
from pathlib import Path

import dj_database_url


BASE_DIR = Path(__file__).resolve().parent.parent
try:
    from dotenv import load_dotenv
except ImportError:
    load_dotenv = None

ENV_FILE = BASE_DIR / ".env"

if load_dotenv is not None:
    load_dotenv(ENV_FILE)
elif ENV_FILE.exists():
    for line in ENV_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip().strip('"').strip("'"))

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "dev-only-change-me")
DEBUG = os.environ.get("DJANGO_DEBUG", "true").lower() == "true"
default_allowed_hosts = "localhost,127.0.0.1,.onrender.com"
render_external_hostname = os.environ.get("RENDER_EXTERNAL_HOSTNAME")
if render_external_hostname:
    default_allowed_hosts = f"{default_allowed_hosts},{render_external_hostname}"

ALLOWED_HOSTS = [
    host.strip()
    for host in os.environ.get(
        "DJANGO_ALLOWED_HOSTS",
        default_allowed_hosts,
    ).split(",")
    if host.strip()
]

INSTALLED_APPS = [
    "django.contrib.contenttypes",
    "django.contrib.staticfiles",
    "training",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "training_backend.urls"
WSGI_APPLICATION = "training_backend.wsgi.application"

DATABASES = {
    "default": dj_database_url.config(
        default=f"sqlite:///{BASE_DIR / 'db.sqlite3'}",
        conn_max_age=600,
        conn_health_checks=True,
    )
}

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
