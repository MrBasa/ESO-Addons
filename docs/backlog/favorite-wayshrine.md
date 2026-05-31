# Building a "Favorite Wayshrines" Addon

The ESO API fully supports interacting with and teleporting to specific wayshrine nodes. Here is the architectural blueprint for how you could build a custom addon to favorite and travel to specific wayshrines.

### 1. The Core API Functions You Need
The engine handles fast travel through a system of "Nodes" (integer IDs assigned to every wayshrine). You will use these three primary functions:
*   `GetNumFastTravelNodes()`: Returns the total number of wayshrines in the game.
*   `GetFastTravelNodeInfo(nodeIndex)`: Returns a massive amount of data about a specific node, including its `name`, `zoneId`, `poiType`, and whether it is currently discovered/usable.
*   `FastTravelToNode(nodeIndex)`: The actual command that triggers the teleport. If used while interacting with a physical wayshrine, it is free. If used out in the wild, it charges the standard gold fee.

### 2. How to Implement the "Favorite" Action
When a player opens the map and clicks on a wayshrine icon, the vanilla UI generates a tooltip and a prompt (e.g., "Press E to Travel"). 
*   You would hook into the map pin system (specifically the `ZO_MapPin` callbacks) to detect when a wayshrine pin is selected.
*   You could then append a custom keybind prompt at the bottom of the screen (e.g., "Press F to Favorite") using the game's `KEYBIND_STRIP` API.
*   When pressed, your script grabs that pin's `nodeIndex` and saves it to your addon's `ZO_SavedVars`.

### 3. Displaying the Favorites Menu
You would need to build a custom UI window or append a new tab to the existing right-hand Map panel (where the current "Locations" tab sits).
*   Your custom tab would iterate through your `ZO_SavedVars` and generate a clean text list of your favorited wayshrines.
*   You attach a simple click-handler to these text labels so that when clicked, it fires `FastTravelToNode(savedNodeIndex)`.

### 4. The Developer "Gotcha": Node Index Shifting
The easiest way to build this is to just save the `nodeIndex` integers. However, when ZeniMax releases major expansions, they sometimes insert new wayshrines into the middle of the database, causing existing node indexes to shift. 
*   **Best Practice:** When a user favorites a wayshrine, save its `name` and parent `zoneId`. When the player logs in, your addon should quietly loop through all nodes using `GetFastTravelNodeInfo()`, find the current matching `nodeIndex` for those names, and cache *that* for the session's teleports.
