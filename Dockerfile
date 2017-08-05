FROM python:2.7-alpine

ENV REDIS_SENTINEL=redis-sentinel
ENV REDIS_MASTER=mymaster

# install git and various python library dependencies with alpine tools
RUN set -x && \
    apk --no-cache add postgresql-dev g++ gcc git jpeg-dev libffi-dev libjpeg libxml2-dev libxslt-dev linux-headers musl-dev openssl zlib zlib-dev

RUN set -x && \
    apk --no-cache add nginx

# This is needed to build uwsgi
RUN set -x && \
    apk --no-cache add build-base python-dev

# This is needed for uwsgi routing support
RUN set -x && \
    apk --no-cache add pcre pcre-dev


# This is from here: https://github.com/unbit/uwsgi/pull/1210
RUN export UWSGI_PROFILE=core

# install python dependencies with pip
# install pybossa from git
# add unprivileged user for running the service
ENV LIBRARY_PATH=/lib:/usr/lib
RUN set -x && \
    git clone https://github.com/jacksongs/pybossa /opt/pybossa && \
    cd /opt/pybossa && \
    pip install -U pip setuptools && \
    pip install -r /opt/pybossa/requirements.txt

# ADD THE THEME
RUN set -x && \
    cd /opt/pybossa/pybossa/themes/burn && \
    git pull origin master

RUN rm -rf /opt/pybossa/.git/ && \
    addgroup pybossa  && \
    adduser -D -G pybossa -s /bin/sh -h /opt/pybossa pybossa && \
    passwd -u pybossa

# Supervisor to manage everything
RUN apk --no-cache add supervisor

# This is needed for rc-service (service manage)
RUN set -x && \
    apk --no-cache add openrc

# variables in these files are modified with sed from /entrypoint.sh
ADD alembic.ini /opt/pybossa/
ADD settings_local.py /opt/pybossa/

# For ssl certs
RUN pip install certbot-nginx
RUN certbot certonly --standalone --email jacksongs@gmail.com -d burntheregister.com

ADD entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]

ADD nginx.conf /etc/nginx/nginx.conf
RUN cp /opt/pybossa/contrib/supervisor/supervisord.conf.template /etc/supervisord.conf

RUN chown pybossa /opt/pybossa/uploads

# run with unprivileged user
# USER pybossa
WORKDIR /opt/pybossa
EXPOSE 80

# Background worker is also necessary and should be run from another copy of this container
#   python app_context_rqworker.py scheduled_jobs super high medium low email maintenance
CMD ["/usr/bin/supervisord"]
