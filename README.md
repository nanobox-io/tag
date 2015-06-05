#Tag

###tldr; You shoud probably be using tag in your cluster in some way.

```bash
tag -server -config-json '{}' #start the tag server
```

Tag makes custom cluster configuration simple. Install tag on the servers that are members of your cluster, configure Tag correctly, and then your cluster should be able to survive nodes going offline, being overloaded, etc.

Tag is a gossiping member detection layer that can pass data to and run predefined scripts when nodes go offline or come online. The original reason for tag was as a replacement for the [vippy](https://github.com/postwait/vippy) project. At [Pagodabox](https://pagodabox.io) were using vippy to move virtual ip address from node to node but it was simply using too much ram. 180Mb to move a single ip between two nodes in our system. It doesn't seem like a lot, but running 100+ vippy instances on a single hypervisor was eating up 8 GB of ram. 8 GB of ram to move 100 ip addresses was not really acceptable.

So thats why Tag was created.

Tag runs on [luvit](https://luvit.io) which brings "Asynchronous I/O to [lua](http://www.lua.org)" using [luajit2](http://luajit.org) and [libuv](https://github.com/libuv/libuv).

## How does Tag work

The idea behind Tag is that you mark nodes in your cluster as being members of subgroups called systems. You can have a load balancer system, a virtual ip system, a worker system, a queue system, basically anything you can create can be a system. Those systems have scripts associated with them that are run when the cluster agrees that certain events have happened, for example a node going offline. Those scripts are passed any data that applies to the node that Tag is running on.

## Let's get real
Lets see how this works in real life. Say you now work at FooBar co., and have a cluster of [nginx](http://nginx.org) proxies for the production api which allows customers, to order widgets (go ecommerce!). Your boss assigned you to ensure that the api is available even if one of the nginx nodes is offline. There are a couple of options you could go with, but you decided to go with Tag because you had recently read about other people sucessfully using it and wanted to give it a shot.

```bash
## install lit, the npm of luvit!
curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh

## install tag
lit make pagodabox/tag && cp ./tag /usr/bin/tag
```

So you install Tag on 3 nodes in your cluster to ensure that it can make a quorum decision (n/2+1), and you start to write a config file. Lets say that the three nodes are: Primary at 10.0.0.1, Secondary at 10.0.0.2, and Tertiary at 10.0.0.3. The nginx ip failover config you wrote would look like this so far (but you already knew that):

```bash
tag -server -config-json '
{"node_name": "{{name of node goes here}}"
,"nodes_in_cluster":
  {"Primary":
    {"host": "10.0.0.1"
    ,"port": 1234}
  ,"Secondary":
    {"host":"10.0.0.2"
    ,"port": 1234}
  ,"Tertiary":
    {"host":"10.0.0.3"
    ,"port": 1234}}'
```

the command above will start a single Tag node and start it looking for the other two nodes in the cluster. If the other nodes are started the entire cluster will be online and available, but will not do anything yet. Thats not quite what you need at FooBar co., so you write a few small helper scripts so that Tag knows what to do when a node comes online.

A system consists of 6 scripts that can be run: install, load, enable, disable, add, remove. But for this simple project you use just 3 of them: load, add and remove.

```bash
!#/bin/env bash
# LOAD what ip address is currently on the machine
ifconfig eth0:0 | awk '{if($1 == "inet"){print$2}}'
```
```bash
!#/bin/env bash
# ADD an ip address to eth0:0
ifconfig eth0:0 $1 up
```
```bash
!#/bin/env bash
# REMOVE an ip address from eth0:0
ifconfig eth0:0 down
```

You install these three scripts in some sane location on the 3 nodes in the nginx cluster, lets say `/var/db/tag/scripts/ip`, and update the config so that Tag knows everything it needs to keep the FooBar co. api online for the widgeteers (the customers who purchase widgets). Here is what the updated config looks like you clever config writter:

```bash
tag -server -config-json '
{"node_name": "{{name of node goes here}}"
,"nodes_in_cluster":
  {"Primary":
    {"host": "10.0.0.1"
    ,"port": 1234
    ,"systems": {"FooBar co. NGINX": 1}}
  ,"Secondary":
    {"host":"10.0.0.2"
    ,"port": 1234
    ,"systems": {"FooBar co. NGINX": 2}}
  ,"Tertiary":
    {"host":"10.0.0.3"
    ,"port": 1234}
"systems":
  {"FooBar co. NGINX":
    {"add": "/var/db/tag/scripts/ip/add"
    ,"remove": "/var/db/tag/scripts/ip/remove"
    ,"load": "/var/db/tag/scripts/ip/load"
    ,"data": ["10.0.10.1"]
    ,"topology": "round_robin"}}}'
```

Primary and Secondary will now start the 'FooBar co. NGINX' system and decide which node should have the Virtual Ip: '10.0.10.1'. When one node goes offline, the other node will add '10.0.10.1' to its interface and things will continue to run smoothly. Now FooBar co., and more importantly you, can sleep well at night knowing that the production api for ordering widgets is being taken care of by Tag. If it does go offline the only question you will need to ask is: *"who just deployed to prod?"*

As a side note the config can also be stored in a file and then passed in like so:

```bash
tag -server -config-file /path/to/tag.config
```

Here are some examples of how to configure Tag for specific tasks:
- [virtual ip failover]()

(If you have an example you would like to contribute, open a pull request and we will merge it in.)

You can read about specific features of Tag here:
- [full list of all config options for Tag with defaults](tree/master/lib/config.lua)
- [failure detection and quorum decisions](tree/master/lib/failover/node.lua)
- [scripts available in a system and when they are run](tree/master/lib/system/)
- [how topologies work and how to create your own](tree/master/lib/system/topology)


Copyright (c) 2015 Pagoda Box, Inc.