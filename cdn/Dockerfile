FROM nginx:alpine

# Copiar archivos de juegos e imágenes
COPY juegos /usr/share/nginx/html/juegos
COPY img /usr/share/nginx/html/img

# Copiar configuración de nginx
COPY cdn.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
test
