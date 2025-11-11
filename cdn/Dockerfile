FROM nginx:alpine

# Copy game files and images
COPY juegos /usr/share/nginx/html/juegos
COPY img /usr/share/nginx/html/img

# Copy nginx configuration
COPY cdn.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
