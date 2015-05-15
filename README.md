#Tag

Tag makes failing over between nodes easy. One node is the master and when it goes offline another node is promoted to the new master. When the original master comes back online, it is promoted again to master.

Bam. Easy.

Node monitoring is done similar to how serf works, every node pings a limited set of other nodes in the cluster. The nodes have a certain amount of time that they need to reply before being marked as suspicious. If a quorum of nodes can agree that a node is suspicious, the enture cluster will mark the node as being down. Once the node comes back online and a quorum can agree that it is pobably not dead, then the cluster will mark it as being alive again.

The minimun number of nodes for running a Tag cluster is 3. Any lower and failover is impossible.

Here are some examples of how to configure Tag for specific tasks:
- [virtual ip failover](tree/master/examples/ip-failover.json)

Copyright (c) 2015 Pagoda Box, Inc.