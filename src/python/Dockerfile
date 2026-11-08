FROM python:3.13-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

COPY requirements.txt .
RUN python -m pip install --no-cache-dir -r requirements.txt \
    && python -m pip check

RUN useradd --create-home --uid 10001 appuser
COPY check_environment.py main.py kaggle_score.json .

USER appuser
CMD ["python", "main.py", "--data-dir", "/data", "--output-dir", "/outputs"]
