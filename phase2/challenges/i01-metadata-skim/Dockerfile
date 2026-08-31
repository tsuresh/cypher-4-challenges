# i01 Metadata Skim — SSRF previewer. MUST run on the finals GCE VM so the real
# metadata server (169.254.169.254) is reachable, with a service account scoped to
# exactly one flag resource.
FROM python:3.12-slim
WORKDIR /app
COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app/app.py .
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
EXPOSE 8000
ENTRYPOINT ["/docker-entrypoint.sh"]
