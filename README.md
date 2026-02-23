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


## 🚀 Update Logs & Patch Notes

### [v0.1.0] - Initial Base System
> *ระบบเริ่มต้น: การจัดการข้อมูลพื้นฐานและการจัดเก็บ*

- **Vehicle Persistence:** เพิ่มระบบบันทึกข้อมูลรถเข้า Database `player_vehicles` เมื่อทำการจอด
- **Meta Data Tracking:** รองรับการเก็บข้อมูล Engine Health, Body Health, และ Fuel Level
- **Spatial Data:** ระบบบันทึกพิกัดแบบละเอียดประกอบด้วย `x, y, z` และองศาของรถ (`rotation`)
- **State Management:** เพิ่มสถานะ `state` สำหรับตรวจสอบว่ารถถูกจอดอยู่ในระบบ (Stored) หรือไม่

---

### [v0.1.1] - Security & Stability Patch
> *การเพิ่มความปลอดภัย ป้องกันการเสกรถ และแก้ไขปัญหา Network ID*

- **Enhanced Security:** - เพิ่มระบบ **Server-Side Ownership Check** ตรวจสอบความเป็นเจ้าของผ่าน `citizenid` และ `plate` ทุกครั้งที่มีการบันทึกข้อมูล
    - เพิ่มการตรวจสอบระยะห่าง (**Distance Check**) ทั้งฝั่ง Client และ Server (รัศมี 20-25 เมตร) เพื่อป้องกันการเจาะระบบเพื่อเบิกรถระยะไกล
- **Network ID Synchronization:**
    - แก้ไข Warning `no object by ID 0` โดยการใช้ Loop ตรวจสอบสถานะ Network จนกว่ารถจะถูกลงทะเบียนในระบบสำเร็จก่อนส่งข้อมูลไป Server
- **Precision Spawning:**
    - ปรับปรุง Logic การสร้างรถให้ทำที่ฝั่ง Client (Client-Side Spawning) เพื่อความแม่นยำของ **Vehicle Mods** และ **Colors** 100%
    - เพิ่มระบบ **Entity Sync Waiting** เพื่อรอให้รถมีตัวตนในโลกของ Client ก่อนทำการใส่ของแต่งรถ
- **Visual & Logic Polish:**
    - เพิ่มเอฟเฟกต์ **Fade-In (Alpha 0-255)** เพื่อความสวยงามขณะเบิกรถ
    - ปรับปรุงระบบ **Duplicate Check** ตรวจสอบทะเบียนรถบนแผนที่ก่อนอนุญาตให้เบิก เพื่อป้องกันการเสกรถซ้อน
    - บูรณาการระบบกุญแจ (`vehiclekeys`) และระบบน้ำมัน (`qb-fuel`) ให้ทำงานร่วมกันอย่างสมบูรณ์

---
