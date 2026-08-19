FROM python:3.12-slim
WORKDIR /app
RUN pip install --no-cache-dir flask==3.0.3 requests==2.32.3 gunicorn==22.0.0
COPY app.py .
EXPOSE 8000
# Single worker is fine; the SSRF is the whole point, not throughput.
CMD ["gunicorn", "-b", "0.0.0.0:8000", "-w", "2", "--timeout", "30", "app:app"]
