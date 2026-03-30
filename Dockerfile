FROM nginxinc/nginx-unprivileged:alpine

# Upgrade zlib to patch CVE-2026-22184 (arbitrary code execution via buffer overflow)
USER root
RUN apk upgrade --no-cache zlib
USER nginx

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]