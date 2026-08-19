FROM nginx:1.27-alpine
RUN apk add --no-cache git
COPY site/ /seed/
COPY default.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /docker-entrypoint.d/40-build-repo.sh
RUN chmod +x /docker-entrypoint.d/40-build-repo.sh
EXPOSE 80
