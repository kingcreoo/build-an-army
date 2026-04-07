Soldier combat in this game runs off of an endless RunService.Heartbeat loop. Every frame the loop checks to see what soldiers are ready-to-fire, and then fires a function for each of those ready-to-fire soldiers. More specifically, the loop checks a table with timers for each player's active soldiers. This way, when a player swaps out or clears a soldier, the timer can either be replaced or cleared, and the loop can continue without a halt. Upgrading targets operates similiary.

Each client runs a loop for non-local (other player's) soldiers, and animate's the soldier's bullet itself. The server runs a loop for every player's soldiers, and tells the local client (your own soldiers) to fire at the exact time it should.

This split system takes a lot of pressure off the server, a remote event only needs to be fired for local soldiers, rather than every soldier to every client.

And again, clients (players) can decide whether they want to animate non-local (other player's) soldiers or not, taking even more load off of the client.