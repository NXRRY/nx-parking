# 🚗 NXRRY Parking System (QBCore)

![Version](https://img.shields.io/badge/Version-0.1.0-blue.svg)
![Framework](https://img.shields.io/badge/Framework-QBCore-orange.svg)
![Dependency](https://img.shields.io/badge/Dependency-ox__lib-red.svg)

A high-performance **Street Parking System** for FiveM designed for realism and efficiency. This system saves the complete vehicle state to the database, ensuring vehicles remain at their parked location even after players disconnect from the server.

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
