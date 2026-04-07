Data management for this game was made simple with a Data module I created some years ago. Rather than store data as value instances under the player, my data module stores a table of player data inside of a grand Database table. Data can be referenced or set from this database via the Data.Get() and Data.Set(). This is a much simpler, robust, and secure system.

Data is stored with DataStore service when applicable, and when the player leaves. Data.Initialize() grabs player data when they join & discovers when players are joining for their first time, giving them a set of default data points.

PCalls are used to prevent devastating errors when managing data.