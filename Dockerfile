FROM ubuntu:trusty

USER root

RUN apt-get update && apt-get dist-upgrade -y
RUN apt-get install -y zookeeper
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN sed -i 's/ROLLINGFILE/CONSOLE/' /etc/zookeeper/conf/environment

ADD start.sh /usr/local/bin/
RUN chmod 777 /usr/local/bin/start.sh

ENTRYPOINT ["/usr/local/bin/start.sh"]
