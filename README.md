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
ADD COLUMN IF NOT EXISTS `parkingcitizenid` VARCHAR(50) DEFAULT NULL;
