#How the replicated Key Value store is implemented

There are two types of nodes in a Tag cluster, a Leader and Followers. There are only 3 Leaders and the rest of the nodes are Followers. Leader and Followers are chosen using the `max[3]:choose_one_or_all` topology composition as part of the Tag sub-system.

##Leaders

The Leader nodes are the central point of replication for all follower nodes, when a write is committed on a Leader node, it is sent out to all Followers that have connected to it, and also to all Leaders that the Leader has connected to. Leader nodes subscribe directly to all other Leader nodes and have a syncronized copy of all the data in the cluster.

##Followers

When connecting up to a Leader node, a follower node will send a timestamp of the last operation comitted for each collection of data that it needs locally. the Leader node will compare this timestamp against its log of what has been committed for the colllection and will either send a partial update, or a full update depending on which is needed to get the follower back in sync.

##How data is partitioned between nodes.

So that all the data is not stored on every node in a Tag cluster, Follower nodes only sync the collections that they are using locally. For example, in a cluster a Follower only starts the DNS system, the only collections of data that will be synced when the Follower connects to a Leader will be 'nodes' and 'dns'. Other collections that are not in use on the Follower are not synced down.