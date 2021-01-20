FROM osgeo/gdal:ubuntu-full-3.1.0 as build-stage-1

RUN apt-get update \
    && apt-get install -y gcc make g++ python3-pip \
    && pip3 install --upgrade pip \
    && pip3 install --prefix=/usr/local "pycld2==0.41"


FROM osgeo/gdal:ubuntu-full-3.1.0
ARG VERSION

LABEL language="python"
LABEL framework="flask"
LABEL usage="normalize microservice for rasters and vectors"

RUN apt-get update \
    && apt-get install -y --no-install-recommends sqlite python3-pip

ENV VERSION="${VERSION}"
ENV PYTHON_VERSION="3.8"
ENV PYTHONPATH="/usr/local/lib/python${PYTHON_VERSION}/site-packages"

RUN groupadd flask \
    && useradd -m -d /var/local/normalize -g flask flask

COPY --from=build-stage-1 /usr/local/ /usr/local/

RUN pip3 install --upgrade pip

RUN mkdir /usr/local/normalize/
COPY setup.py requirements.txt requirements-production.txt /usr/local/normalize/
COPY normalize /usr/local/normalize/normalize

RUN cd /usr/local/normalize && pip3 install --prefix=/usr/local -r requirements.txt -r requirements-production.txt
RUN cd /usr/local/normalize && python setup.py install --prefix=/usr/local

COPY wsgi.py docker-command.sh /usr/local/bin/
RUN chmod a+x /usr/local/bin/wsgi.py /usr/local/bin/docker-command.sh

WORKDIR /var/local/normalize
RUN mkdir ./logs \
    && chown flask:flask ./logs
COPY --chown=flask logging.conf .

ENV FLASK_ENV="production" \
    FLASK_DEBUG="false" \
    LOGGING_ROOT_LEVEL="" \
    INSTANCE_PATH="/var/local/normalize/data/" \
    OUTPUT_DIR="/var/local/normalize/output/" \
    SECRET_KEY_FILE="/var/local/normalize/secret_key" \
    TLS_CERTIFICATE="" \
    TLS_KEY=""

USER flask
CMD ["/usr/local/bin/docker-command.sh"]

EXPOSE 5000
EXPOSE 5443