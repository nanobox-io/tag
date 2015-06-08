#How the replicated Key Value store is implemented

There are two types of nodes in a Tag cluster, a Leader and Followers. There is only one Leader and the rest of the nodes are Followers. Leader and Followers are chosen using the round_robin topology as part of the Tag sub-system. Data points are only stored on nodes that need the data.

##Leaders and CoLeaders

The Leader node is the central point of replication for all follower nodes, when a write is committed on the Leader node, it is sent out to all Followers that have connected to it. CoLeaders subscribe directly to the Leader node and have a complete copy of all the data stored in the Leader. They are candidates for failover if the Leader node goes offline. Leader nodes only sync to CoLeader Nodes and Follower nodes only sync with CoLeader nodes.

##Followers

When connecting up to the Leader node, a follower node will send a timestamp of the last operation comitted for each collection of data that it needs locally. the Leader node will compare this timestamp against its log of what has been committed for the colllection and will either send a partial update, or a full update depending on which is needed to get the follower back in sync. Followers are not candidates for Leader nodes as they only contain a partial dataset.

##How data is partitioned between nodes.

So that all the data is not stored on every node in a Tag cluster, Follower nodes only sync the collections that they are using locally. For example, in a cluster a Follower only starts the DNS system, the only collections of data that will be synced when the Follower connects to a CoLeader will be 'systems', nodes' and 'dns'. Other collections that are not in use on the Follower are not synced down.