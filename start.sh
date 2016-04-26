#!/bin/bash
if [[ -z "${ZK_ID}" || -z "${ZK_SERVERS}" ]]; then
       echo "Please set ZK_ID and ZK_SERVERS environment variables first."
       exit 1
fi
echo "${ZK_SERVERS}" | tr ' ' '\n' | tee -a /etc/zookeeper/conf/zoo.cfg
echo "${ZK_ID}" | tee /var/lib/zookeeper/myid
/usr/share/zookeeper/bin/zkServer.sh start-foreground
1
2
3
4
5
6
7
8
#!/bin/bash
if [[ -z "${ZK_ID}" || -z "${ZK_SERVERS}" ]]; then
       echo "Please set ZK_ID and ZK_SERVERS environment variables first."
       exit 1
fi
echo "${ZK_SERVERS}" | tr ' ' '\n' | tee -a /etc/zookeeper/conf/zoo.cfg
echo "${ZK_ID}" | tee /var/lib/zookeeper/myid
/usr/share/zookeeper/bin/zkServer.sh start-foreground
