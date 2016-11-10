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
if [ $NO == 1 ]; then
	echo "server.$myindex=$local_ip:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
	$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$myindex
	echo "I am starting zookeeper"
	ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground
	echo "It was started"
else
	echo "server.$myindex=$local_ip:2888:3888;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
	
	$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$myindex
	echo "I am starting zookeeper"
	ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start 
	echo "It was started in non standalone"
	jps
fi
# Check the configuration of the rest of the servers
while read line; do
	# If this is not my ip
	if [ "$line" != "$local_ip" ] && [ "$line" != "" ]; then
		# Retrieve the information of the ZK cluster represented by the current server and check if the local_ip is already configured
		echo "`$ZK_HOME/bin/zkCli.sh -server $local_ip:2181 sync /zookeeper`" >> sync.config
		cat sync.config
		echo "`$ZK_HOME/bin/zkCli.sh -server $local_ip:2181 config /zookeeper | grep ^server`" >> cluster.config
		echo "my index is $myindex and the configuration of $line is "
		cat cluster.config
		grep "$line" cluster.config > result
		echo "the result of the comparison is $result"
		#rm cluster.config
		
		# If the local_ip is not present in the configuration
		if [ "$result" != "$local_ip" ]; then
			#$ZK_HOME/bin/zkServer.sh stop
			#echo "Zookeeper is stopped"
			#echo "`$ZK_HOME/bin/zkCli.sh -server $line:2181 get /zookeeper/config |grep ^server`" >> $ZK_HOME/conf/zoo.cfg.dynamic
			echo "`$ZK_HOME/bin/zkCli.sh -server $local_ip:2181 config /zookeeper |grep ^server`" >> cluster.dynamic
			cat cluster.dynamic
			echo "I am getting the configuration of another server"
			#echo "server.$myindex=$local_ip:2888:3888:observer;2181" >> $ZK_HOME/conf/zoo.cfg.dynamic
    			#cp $ZK_HOME/conf/zoo.cfg.dynamic $ZK_HOME/conf/zoo.cfg.dynamic.org
			echo "Eu sunt $myindex"
			echo "The updated dynamic configuration of the zoo.cfg.dynamic file is the next one"
			#cat $ZK_HOME/conf/zoo.cfg.dynamic
			#$ZK_HOME/bin/zkServer.sh stop
			#echo "Zookeeper is stopped"
			echo "ZK is $line and I am $local_ip"
			echo "the current server is reinitialized"
  			$ZK_HOME/bin/zkServer-initialize.sh --force --myid=$myindex
			echo "the current server is started"
  			#ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start
			index=$(echo $line | sed -e 's/\.//g')
  			$ZK_HOME/bin/zkCli.sh -server $local_ip:2181 reconfig -add "server.$index=$line:2888:3888:participant;2181"
  			#$ZK_HOME/bin/zkServer.sh stop
  			#ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start
		fi
		rm result
	fi 
done < 'zk.cluster.tmp'

#$ZK_HOME/bin/zkServer.sh stop
#ZOO_LOG_DIR=/var/log ZOO_LOG4J_PROP='INFO,CONSOLE,ROLLINGFILE' $ZK_HOME/bin/zkServer.sh start-foreground

rm zk.cluster.tmp
