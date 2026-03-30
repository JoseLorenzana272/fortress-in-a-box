FROM nginx:alpine

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]