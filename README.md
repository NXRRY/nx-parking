# 🚗 NXRRY Parking System (QBCore)

![Version](https://img.shields.io/badge/Version-0.1.0-blue.svg)
![Framework](https://img.shields.io/badge/Framework-QBCore-orange.svg)
![Dependency](https://img.shields.io/badge/Dependency-ox__lib-red.svg)

A high-performance **Street Parking System** for FiveM designed for realism and efficiency. This system saves the complete vehicle state to the database, ensuring vehicles remain at their parked location even after players disconnect from the server.

---

## 📺 System Showcase


<div align="center">

[![NXRRY Parking System](images/showcase.jpg)](https://streamable.com/cx1j9w)

🎬 Click the image above to watch the full Video Demonstration.


</div>

---

## 🌟 Features

* **Real-time Saving:** Instantly saves Coordinates (Coords), Rotation, Fuel levels, and Engine/Body health to the database.
* **Security System:** When parked, the system automatically locks doors, freezes position, and sets the vehicle to Invincible to prevent theft or destruction.
* **Visual Progress:** Utilizes `ox_lib` to display Progress Circles for a sleek UI and enhanced Roleplay (RP) immersion.
* **GPS Tracking:** Integrated waypoint system to guide players back to their parked vehicles if they are far away.
* **Ownership Check:** Verifies vehicle ownership via the database before allowing parking to prevent the parking of NPC or unauthorized vehicles.

---

## 🛠 Commands

| Command | Function |
| :--- | :--- |
| `/openparkingmenu` | Opens the main menu for vehicle management (Default: **F6**) |

---

## 📂 Resource Structure

* `config.lua`: Configuration for notifications (Notify) and Debug Mode.
* `fxmanifest.lua`: Defines script loading and resource dependencies.
* `client/main.lua`: Handles player-side logic, UI menus, and vehicle spawning.
* `server/main.lua`: Manages database read/write operations and Server Callbacks.

---

## 💾 Installation

### 1. SQL Setup
Execute the following command in your database (Table: `player_vehicles`):

```sql
ALTER TABLE `player_vehicles` 
ADD COLUMN IF NOT EXISTS `coords` TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS `rotation` TEXT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS `parking` LONGTEXT DEFAULT NULL,
```
## 🚀 Update Logs & Patch Notes

### [v0.1.0] - Initial Base System
> *Core System: Basic parking functionality and data persistence*

* **Vehicle Persistence:** Implemented a system to save vehicle data into the `player_vehicles` database upon parking.
* **Metadata Tracking:** Added support for tracking `engine_health`, `body_health`, and `fuel_level` to ensure vehicle state is preserved.
* **Spatial Data:** Implemented detailed coordinate logging including `x, y, z` positions and vehicle `rotation` (heading).
* **State Management:** Introduced a `state` column to monitor whether a vehicle is currently stored (1) or unparked (0).

---

### [v0.1.1] - Security & Stability Patch
> *Security Hardening: Exploit prevention and Network ID stabilization*

* **Enhanced Security:**
    * **Server-Side Ownership Validation:** Added strict verification of `citizenid` and `plate` on the server-side to prevent unauthorized players from spawning or modifying vehicles they don't own.
    * **Distance Verification:** Implemented a dual-layered **Distance Check** (20-25m radius) on both Client and Server to prevent remote-spawning exploits.
* **Network ID Synchronization:**
    * **ID 0 Warning Fix:** Resolved the `no object by ID 0` warning by implementing a synchronous loop that waits for the entity to be fully registered on the network before sending data to the server.
* **Precision Spawning & Reliability:**
    * **Client-Side Spawning:** Optimized the spawning logic to execute on the client-side, ensuring 100% accuracy for **Vehicle Mods**, **Liveries**, and **Colors**.
    * **Entity Sync Logic:** Added a "Wait for Entity" mechanism to ensure the vehicle exists in the client's world before applying properties and modifications.
* **Visual & Logic Polish:**
    * **Smooth Fade-In:** Added a professional **Alpha Transition (0-255)** effect when unparking vehicles.
    * **Duplicate Prevention:** Improved the **Plate Check** logic to scan the map for existing vehicles before spawning, preventing duplicate entities.
    * **System Integration:** Fully integrated with `qb-vehiclekeys` for automatic key assignment and `qb-fuel` for real-time fuel synchronization.

---


## 🚀 What's New in v0.2.0

### 1. 🎡 Smart Radial Menu (Contextual UI)
The system now dynamically updates your Radial Menu options based on your current state:
- **In-Vehicle:** Displays the **"Park Vehicle"** option to save your coordinates and store the car.
- **On-Foot:** Displays the **"Parked List"** option to view all your stored vehicles with a built-in GPS waypoint system to locate them.

### 2. 📋 Vehicle Diagnostic & Status Menu
Interact with parked vehicles via `qb-target` to open a premium status dashboard:
- **ox_lib Integration:** Beautiful progress bars for **Engine**, **Body**, and **Fuel**.
- **Visual Health Indicators:** Dynamic color coding (Green/Yellow/Red) based on the vehicle's condition.
- **Ownership Verification:** Secure server-side check to determine if the player is the rightful owner.
- **Formatted Currency:** Displays `depotprice` with comma separators (e.g., $1,500,000) for better readability.

### 3. 💸 Secure Unparking & Depot System
- **Mandatory Payment:** If a vehicle has an outstanding `depotprice` in the database, the player must pay before unparking.
- **Smart Logic:** Automatically checks and deducts funds from `Cash` or `Bank`.
- **Anti-Exploit:** All financial transactions and ownership checks are handled server-side to prevent client-side manipulation.

---

## 🛠️ Installation Guide

### 1. Radial Menu Setup
Open your `qb-radialmenu` client-side script (usually `client/main.lua`) and locate the `SetupSubItems` function. Insert the following code:

```lua
-- Add this to your Local Functions section
local function SetupParkingMenu()
    local ped = PlayerPedId()
    local Vehicle = GetVehiclePedIsIn(ped, false)
    local vehicleMenu = nil 

    if Vehicle ~= 0 then
        -- Inside a vehicle
        vehicleMenu = {
            id = 'park_vehicle',
            title = 'Park Vehicle',
            icon = 'square-parking',
            type = 'client',
            event = 'parking:client:parkVehicle',
            shouldClose = true
        }
    else
        -- Outside a vehicle
        vehicleMenu = {
            id = 'parked_list',
            title = 'Parked Vehicles',
            icon = 'clipboard-list',
            type = 'client',
            event = 'parking:client:openParkingList',
            shouldClose = true
        }
    end

    if vehicleMenu then
        exports['qb-radialmenu']:AddOption(vehicleMenu)
    end
end

-- Call the function inside SetupSubItems
local function SetupSubItems()
    SetupJobMenu()
    SetupVehicleMenu()
    SetupParkingMenu() -- << Add this line
end
