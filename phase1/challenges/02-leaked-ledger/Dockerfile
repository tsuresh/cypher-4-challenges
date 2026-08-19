FROM nginx:1.27-alpine
# Highland Leaf's ledger site. A .env with real secrets was left in web root.
COPY site/ /usr/share/nginx/html/
COPY default.conf /etc/nginx/conf.d/default.conf
COPY docker-entrypoint.sh /docker-entrypoint.d/40-write-env.sh
RUN chmod +x /docker-entrypoint.d/40-write-env.sh
EXPOSE 80
