# nx-parking  
**Advanced Parking System for FiveM (QBCore)**  
*Developed by NXRRY*

---

## 📌 Description  
nx-parking is an intelligent parking system that allows players to **park their vehicle anywhere** (not limited to garages). The system saves the vehicle’s condition (fuel, engine, body health) and last known location in the database. Parked vehicles are hidden and can be retrieved at any time via a menu, or through depot NPCs.  

The system also supports **job-restricted parking zones** and **police impound** with fines and duration. Players can retrieve impounded vehicles from depots or contact officers.

---

## ✨ Key Features  
- ✅ Park anywhere (outside restricted zones)  
- ✅ Saves vehicle condition (fuel, engine, body, location)  
- ✅ Parking zones with job restrictions  
- ✅ Vehicle status check (distance, condition, location)  
- ✅ Police impound system with reasons, fines, and duration  
- ✅ Send vehicle to public depot  
- ✅ Retrieve vehicles from depot/impound via NPC  
- ✅ Set GPS to parked vehicle location  
- ✅ Radial menu support (qb-radialmenu)  
- ✅ Target interaction (qb-target)  
- ✅ Multiple notification systems (ox, qb, chat)  
- ✅ Automatic version check  

---

## 🔧 Dependencies  
- [QBCore](https://github.com/qbcore-framework)  
- [ox_lib](https://github.com/overextended/ox_lib)  
- [PolyZone](https://github.com/mkafrin/PolyZone)  
- [qb-target](https://github.com/qbcore-framework/qb-target)  
- [LegacyFuel](https://github.com/InZidiuZ/LegacyFuel) (or any compatible fuel system)  
- [qb-radialmenu](https://github.com/qbcore-framework/qb-radialmenu) (optional but recommended)  

---

## 📥 Installation  

### 1. Download and Place Files  
- Download the script from GitHub  
- Place the `nx-parking` folder in your server's `resources` directory  

### 2. Database Setup  
Run the following SQL queries in your server database.  
(Ensure the `player_vehicles` table exists; if not, create it as per QBcore standards.)

```sql
-- Add required columns to player_vehicles (if not present)
ALTER TABLE `player_vehicles` 
ADD COLUMN `state` INT DEFAULT 0, -- 0 = active, 1 = parked, 2 = impounded
ADD COLUMN `depotprice` INT DEFAULT 0,
ADD COLUMN `parking` LONGTEXT DEFAULT NULL,
ADD COLUMN `coords` LONGTEXT DEFAULT NULL,
ADD COLUMN `rotation` LONGTEXT DEFAULT NULL,
ADD COLUMN `fuel` FLOAT DEFAULT 100,
ADD COLUMN `engine` FLOAT DEFAULT 1000,
ADD COLUMN `body` FLOAT DEFAULT 1000;

-- Create impound_data table for impound history
CREATE TABLE IF NOT EXISTS `impound_data` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `plate` VARCHAR(10) NOT NULL,
  `vehicle_model` VARCHAR(50),
  `charge_name` VARCHAR(100),
  `fee` INT DEFAULT 0,
  `impound_time` INT DEFAULT 0,
  `officer_name` VARCHAR(100),
  `release_time` TIMESTAMP NULL,
  `timestamp` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_plate` (`plate`),
  UNIQUE KEY `unique_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 3. Add to server.cfg  
```
ensure nx-parking
```

---

## ⚙️ Configuration (config.lua)  

The main configuration options in `config.lua`:

| Variable | Description |
|----------|-------------|
| `Config.Debug` | Enable/disable debug logging |
| `Config.EnableParkCommand` | Enable `/park` command |
| `Config.notifyType` | Notification style: `'ox'`, `'qb'`, or `'chat'` |
| `Config.DefaultSpawnCoords` | Default spawn coordinates if no vehicle data |
| `Config.Depot` | List of depot locations (NPC, spawn points) |
| `Config.SpawnimpoundCoords` | Spawn coordinates when police release vehicle |
| `Config.ParkingZones` | Parking zones with job restrictions |
| `Config.ImpoundReasons` | Impound reasons with fines and duration |
| `Config.Strings` | All UI strings (customizable) |

### Example: Adding a Depot
```lua
Config.Depot = {
    {
        name = "Legion Depot",
        coords = vector4(408.63, -1623.13, 29.29, 228.48),
        spawnPoint = { vector4(...), ... },
        marker = { ... },
        blip = { ... }
    }
}
```

### Example: Adding a Parking Zone
```lua
Config.ParkingZones = {
    {
        name = "police_station_1",
        title = "Police Station Parking",
        points = { vector2(410.82, -1031.62), ... },
        minZ = 20.0, maxZ = 40.0,
        allowJobs = { ['police'] = true, ['ambulance'] = true }
    }
}
```

### Customizing Strings  
All text displayed to players is located in `Config.Strings`. You can modify them to match your server's language or preference.

---

## 🎮 Usage  

### For Regular Players  
- **Park Vehicle**: Drive to desired spot, then use Radial Menu > "Park Vehicle" or type `/park` (must be stationary and driver).  
- **View Vehicle List**: Radial Menu > "My Parked Vehicles" or use `/vehicles` command if available.  
- **Retrieve Vehicle**: Approach a parked vehicle (target appears) or go to a Depot/Impound NPC and select the vehicle.  
- **Check Vehicle Status**: Approach vehicle → Target > "Check Vehicle Status".  
- **Retrieve from Depot**: Go to Depot NPC → "View Pending Vehicles".  

### For Police / Officers  
- **Impound Vehicle**: Approach target vehicle → Target > "🛡️ Law Enforcement Menu" → choose action (Impound/Depot) and reason.  
- **Check Impound Records**: Go to "Impound Officer" NPC → "Search Impound Records" → select nearby citizen.  
- **Release Vehicle**: When impound time expires, can release vehicle to owner via the check menu.  

---

## ⌨️ Commands  
- `/park` – Park the current vehicle (if enabled)  

---

## 🗂️ Database Structure (Additional Columns)  

### Table `player_vehicles` (extended)
| Column | Type | Description |
|--------|------|-------------|
| `state` | INT | 0=active, 1=parked, 2=impounded |
| `depotprice` | INT | Fee required before retrieval |
| `parking` | JSON | Parking info (timestamp, location) |
| `coords` | JSON | Last known coordinates |
| `rotation` | JSON | Vehicle rotation |
| `fuel` | FLOAT | Fuel level |
| `engine` | FLOAT | Engine health |
| `body` | FLOAT | Body health |

### Table `impound_data`
| Column | Type | Description |
|--------|------|-------------|
| `plate` | VARCHAR | License plate |
| `vehicle_model` | VARCHAR | Vehicle model name |
| `charge_name` | VARCHAR | Impound reason |
| `fee` | INT | Fine amount |
| `impound_time` | INT | Impound duration (minutes) |
| `officer_name` | VARCHAR | Name of the officer |
| `release_time` | TIMESTAMP | Time when vehicle can be released |
| `timestamp` | TIMESTAMP | Record creation time |

---

## 📸 Screenshots  
![Screenshot](images/showcase.jpg)  

---

## 🤝 Credits  
- Developer: **NXRRY**  
- Thanks to QBCore team and Overextended for their libraries.  

---

## 🔗 Links  
- GitHub: [https://github.com/NXRRY/nx-parking](https://github.com/NXRRY/nx-parking)  
- Discord: *Coming soon*  

---

## ⚠️ Notes  
- This script is designed to work with **QBCore** only.  
- If you encounter issues or have suggestions, please open an issue on GitHub.  

---

**© 2025 NXRRY. All rights reserved.**
