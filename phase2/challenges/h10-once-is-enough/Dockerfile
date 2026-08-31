# h10 Once Is Enough — AES-GCM fixed-nonce oracle (shared, per-team unique flag).
# Single worker so KEY + NONCE stay constant for the process (nonce reuse is the vuln).
FROM python:3.12-slim
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/gcm.py app/app.py ./
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
EXPOSE 8000
ENTRYPOINT ["/docker-entrypoint.sh"]
