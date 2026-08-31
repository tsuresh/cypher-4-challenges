# h01 Token Relay — semi-blind SSRF webhook validator. MUST run on the finals GCE
# VM (metadata reachable) under the `webhook-runner` SA that starts the impersonation
# chain webhook-runner -> relay -> vault-reader.
FROM python:3.12-slim
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/app.py .
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
EXPOSE 8000
ENTRYPOINT ["/docker-entrypoint.sh"]
