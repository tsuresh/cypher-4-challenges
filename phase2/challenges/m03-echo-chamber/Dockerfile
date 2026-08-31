# m03 Echo Chamber — AES-ECB oracle (per-team instance).
# IMPORTANT: a single worker so the process-wide random key is stable across
# requests (byte-at-a-time relies on one consistent key).
FROM python:3.12-slim
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/app.py .
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
EXPOSE 8000
ENTRYPOINT ["/docker-entrypoint.sh"]
