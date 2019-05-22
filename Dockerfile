FROM centos:7
MAINTAINER quark

ADD assets /assets

RUN chmod -R 755 /assets
RUN /assets/setup.sh
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

EXPOSE 1521
EXPOSE 8080

CMD ["/assets/entrypoint.sh"]
