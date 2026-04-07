The first and most basic soldier shop is displayed in a neutral area in the game's 3d space, it is not on each player's shop. The player needs to walk over to it.

Once opened, the shop displays what soldiers are available for purchase. Basic, early game soldiers are almost always available for purchase and in high quantities. Once the player starts to progress through the game, soldiers become fleeting. They may not be available to purchase all the time, or they may only be available in low quantities.

This codebase accomplishes this by having a stocking loop running on the server. Every 3(or changed) minutes, the server randomly generates(based off of each soldier's rarity/randomness factor) a stock to be displayed in the store. Server sends this stock to the client to update it's shop.

This creates a unique rush for player's to buy soldiers.