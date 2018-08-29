FROM mysql:5.7

COPY ./clef-initdb.sql /docker-entrypoint-initdb.d

CMD [ "mysqld" ]