FROM mcristinagrosu/bigstep_java

USER root

RUN apk add --no-cache wget tar

RUN cd /opt && wget http://mirror.evowise.com/apache/zookeeper/zookeeper-3.5.2-alpha/zookeeper-3.5.2-alpha.tar.gz
RUN tar xzvf zookeeper-3.5.2-alpha.tar.gz
RUN rm -rf zookeeper-3.5.2-alpha.tar.gz
RUN cd zookeeper-3.5.2-alpha/

RUN cp ./conf/zoo_sample.cfg ./conf/zoo.cfg
RUN echo "standaloneEnabled=false" >> ./conf/zoo.cfg
RUN echo "dynamicConfigFile=/tmp/zookeeper/conf/zoo.cfg.dynamic" >> ./conf/zoo.cfg

ADD zk-init.sh ./bin
ENTRYPOINT ["./bin/zk-init.sh"]
