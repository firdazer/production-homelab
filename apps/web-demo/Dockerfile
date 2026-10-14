FROM nginxinc/nginx-unprivileged:1.28-alpine

USER root
RUN apk upgrade --no-cache
USER 101

COPY --chown=101:101 index.html /usr/share/nginx/html/index.html

EXPOSE 8080
