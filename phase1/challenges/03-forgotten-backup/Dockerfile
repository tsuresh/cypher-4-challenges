FROM nginx:1.27-alpine
# Pearl Telecom self-care site. An old DB backup was left in a guessable path.
COPY site/ /usr/share/nginx/html/
COPY docker-entrypoint.sh /docker-entrypoint.d/40-write-backup.sh
RUN chmod +x /docker-entrypoint.d/40-write-backup.sh
EXPOSE 80
