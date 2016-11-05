FROM mcristinagrosu/bigstep_java

USER root

RUN apk add --no-cache wget tar

RUN cd /opt && wget http://mirror.evowise.com/apache/zookeeper/zookeeper-3.5.2-alpha/zookeeper-3.5.2-alpha.tar.gz
RUN tar xzvf /opt/zookeeper-3.5.2-alpha.tar.gz
RUN rm -rf /opt/zookeeper-3.5.2-alpha.tar.gz
RUN cd /opt/zookeeper-3.5.2-alpha

ENV ZK_HOME /opt/zookeeper-3.5.2-alpha/

RUN cp $ZK_HOME/conf/zoo_sample.cfg $ZK_HOME/conf/zoo.cfg
RUN echo "standaloneEnabled=false" >> $ZK_HOME/conf/zoo.cfg
RUN echo "dynamicConfigFile=/opt/zookeeper-3.5.2-alpha/conf/zoo.cfg.dynamic" >> $ZK_HOME/conf/zoo.cfg

ADD zk-init.sh $ZK_HOME/bin
ENTRYPOINT ["$ZK_HOME/bin/zk-init.sh"]
