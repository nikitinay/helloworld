FROM python:3.8-alpine3.11

# install supervisor
COPY supervisord-alpine.ini /etc/supervisor.d/supervisord.ini
RUN apk add --no-cache musl-dev supervisor uwsgi-python3 curl

# install nginx 
COPY install-nginx-alpine.sh /
RUN sh /install-nginx-alpine.sh

# install python requirements
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt

ENV UWSGI_PLUGIN python3

COPY uwsgi.ini /etc/uwsgi/
ENV UWSGI_INI /app/uwsgi.ini

ENV UWSGI_CHEAPER 2

ENV UWSGI_PROCESSES 16

ENV NGINX_MAX_UPLOAD 0

ENV NGINX_WORKER_PROCESSES 1

ENV LISTEN_PORT 80

ENV ALPINEPYTHON python3.8

COPY start.sh /start.sh
RUN chmod +x /start.sh

COPY uwsgi-nginx-entrypoint.sh /uwsgi-nginx-entrypoint.sh
RUN chmod +x /uwsgi-nginx-entrypoint.sh
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["sh", "/entrypoint.sh"]

# Add helloworld app
COPY ./app /app
WORKDIR /app
ENV PYTHONPATH=/app


CMD ["/start.sh"]

