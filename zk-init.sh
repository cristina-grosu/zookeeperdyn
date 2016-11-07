#!/bin/sh

# Determine the local ip
ifconfig | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b" >> output
local_ip=$(head -n1 output)
rm output

# Determine the local ZK index
myindex=$(echo $local_ip | sed -e 's/\.//g')

# Wait for containers to be up and running
sleep 10

nslookup $HOSTNAME
nslookup $HOSTNAME >> zk.cluster

# Configure Zookeeper
no_instances=$(($(wc -l < zk.cluster) - 2))

while [ $no_instances -le $NO ] ; do
	rm -rf zk.cluster
	nslookup $HOSTNAME
	nslookup $HOSTNAME >> zk.cluster
	no_instances=$(($no_instances + 1))
done

while read line; do
	ip=$(echo $line | grep -oE "\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")
	echo "$ip" >> zk.cluster.tmp
done < 'zk.cluster'
rm zk.cluster

sort -n zk.cluster.tmp > zk.cluster.tmp.sort
mv zk.cluster.tmp.sort zk.cluster.tmp

touch $ZK_HOME/conf/zoo.cfg.dynamic		
chmod -R 777 $ZK_HOME

# Run each Zookeeper node as standalone Zookeeper
echo "server.$myindex=$local_ip:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$myindex
ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start &

# Check the configuration of the rest of the servers
while read line; do
	# If this is not my ip
	if [ "$line" != "$local_ip" ] && [ "$line" != "" ]; then
		# Retrieve the information of the ZK cluster represented by the current server and check if the local_ip is already configured
		echo "`$ZK_HOME/bin/zkCli.sh -server $line:2181 get /zookeeper/config |grep ^server`" >> cluster.config
		echo "my index is $myindex and the configuration of $line is "
		cluster.config
		grep "$local_ip" cluster.config > result
		#rm cluster.config
		
		# If the local_ip is not present in the configuration
		if [ "$result" != "$local_ip" ]; then
			$ZK_HOME/bin/zkServer.sh stop
			echo "`$ZK_HOME/bin/zkCli.sh -server $line:2181 get /zookeeper/config |grep ^server`" >> $ZK_HOME/conf/zoo.cfg.dynamic
  			echo "server.$myindex=$local_ip:2888:3888:observer;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
    			cp $ZK_HOME/conf/zoo.cfg.dynamic $ZK_HOME/conf/zoo.cfg.dynamic.org
			echo "Eu sunt $myindex"
			echo "zoo.cfg.dynamic"
			$ZK_HOME/conf/zoo.cfg.dynamic
			echo "ZK is $line and I am $local_ip" 
  			$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$myindex
  			ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start
  			$ZK_HOME/bin/zkCli.sh -server $line:2181 reconfig -add "server.$myindex=$local_ip:2888:3888:participant;2181"
  			$ZK_HOME/bin/zkServer.sh stop
  			ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground
		fi
		rm result
	fi 
done < 'zk.cluster.tmp'

rm zk.cluster.tmp
