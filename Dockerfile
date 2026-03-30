FROM nginx:alpine
RUN apk update && apk upgrade

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]