# 🧪 Laboratory Management System (LMS) – Desktop (Offline-First)

A professional **offline-first Laboratory Management System** built with **Flutter Desktop**, designed for small to mid-sized diagnostic laboratories.

The system follows a real-world lab workflow:

Patient Registration  
→ Test Selection & Billing  
→ Sample Collection  
→ Result Entry  
→ Report Generation  
→ Local Storage + Cloud Sync  

This application focuses on reliability, speed, and clean medical data handling.

---

## ✨ Key Features

### 🧍 Patient Management
- Register patients
- Search patients
- View visit history
- Doctor reference tracking
- Printable patient slips

---

### 🧪 Test Master Catalog (Admin)
Hierarchical structure:

Category  
→ Subcategory  
→ Tests  

Supports:

- Panel tests (CBC, Lipid Profile, etc.)
- Normal ranges
- Units
- Sample types
- Pricing

Admin can add, edit, or disable tests.

---

### 💰 Billing System
- Auto calculation (Total / Discount / Paid / Due)
- Receipt generation
- Test-wise billing

---

### 🧴 Sample Tracking

Each test flows through:

Pending  
Collected  
Processing  
Completed  

---

### 🧬 Result Entry
- Technician input
- Automatic HIGH / LOW detection
- Visual abnormal highlighting

---

### 📄 PDF Report Generator

Professional medical reports including:

- Lab logo
- Patient information
- Test values
- Normal ranges
- Abnormal highlights
- Doctor signature

Exportable and printable.

---

### 📊 Dashboard KPIs
- Today’s patients
- Pending reports
- Completed reports
- Revenue
- Total tests

---

### 🔄 Offline-First Architecture

All actions are saved locally first.

When internet becomes available:
- Background sync pushes data to Firebase

System remains fully functional without internet.

---

## 🧠 User Roles

- Admin  
- Receptionist  
- Lab Technician  

Role-based UI access.

---

## 🛠 Tech Stack (100% Free)

| Layer | Technology |
|------|-----------|
| Desktop UI | Flutter (Windows) |
| State Management | Riverpod |
| Local Database | SQLite (Drift) |
| Cloud Sync | Firebase Firestore |
| Authentication | Firebase Email/Password |
| PDF Reports | Dart pdf |
| Charts | fl_chart |
| Fonts | Google Fonts |
| Icons | Material + HeroIcons |

---

## 🏗 Architecture

Feature-based modular structure:

lib/
features/
auth/
dashboard/
patients/
tests_master/
billing/
samples/
results/
reports/
settings/
core/
database/
sync/
widgets/
models/
main.dart


Each feature contains:

- screen  
- controller  
- repository  
- model  

Clean separation of concerns.

---

## 🗄 Database Design

Local SQLite + Firebase Firestore mirror.

Collections / Tables:


users
patients
test_categories
tests_master
orders
order_tests
results
reports
settings


Each record contains:

labId
sync_status
createdAt
updatedAt

---

## 🔄 Sync Strategy

Local-first writes.

Background service syncs unsent records.

sync_status:
0 = pending
1 = synced


Conflict resolution:
Latest timestamp wins.

---

## 🎨 UI Design System

Medical-grade minimal design:

- White base
- Dark navy primary
- Electric blue accents
- Glassmorphism cards
- Rounded corners
- Soft shadows

Desktop optimized:

- Left sidebar navigation
- Top app bar
- Content panels

Focused on speed and clarity.

---

## 🚀 Getting Started

### Enable Flutter Desktop

```bash
flutter config --enable-windows-desktop
