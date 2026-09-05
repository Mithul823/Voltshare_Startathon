# VoltShare — Hackathon MVP Specification

Version: 1.0
Status: Ready for Implementation
Project Type: AI-Powered Peer-to-Peer Solar Energy Sharing Platform
Primary Platform: Flutter Mobile + Flutter Web
Backend: Supabase + FastAPI
Target: Two-Day Hackathon MVP

---

# 1. Project Overview

## 1.1 Project Name

**VoltShare**

## 1.2 Tagline

**Powering Communities Through Intelligent Energy Sharing**

## 1.3 Product Vision

VoltShare is an AI-powered, community-driven energy platform that allows households to generate, monitor, store, buy, sell, and share renewable energy.

The application connects solar energy producers and nearby consumers through a smart peer-to-peer marketplace.

VoltShare uses artificial intelligence to help users:

* Optimize energy usage
* Select the best time to buy or sell energy
* Manage battery storage
* Receive dynamic price recommendations
* Detect equipment anomalies
* Track sustainability impact
* Share energy during emergency situations

---

# 2. Problem Statement

Traditional electricity systems are centralized.

Even when households generate excess solar energy, they may not be able to sell it directly to nearby consumers.

This creates several problems:

* Excess solar energy may be wasted.
* Consumers continue paying high electricity prices.
* Solar producers receive limited financial benefit.
* Communities remain highly dependent on the central grid.
* Energy decisions are not optimized using real-time data.
* Emergency energy distribution is difficult.
* Consumers lack visibility into carbon savings and sustainability impact.

---

# 3. Proposed Solution

VoltShare provides a digital energy-sharing ecosystem where users can:

* Monitor solar production
* Monitor household consumption
* View smart-meter readings
* Store excess energy in batteries
* Sell excess solar energy
* Purchase energy from nearby producers
* Receive AI-powered recommendations
* Track wallet balance and transactions
* View environmental impact
* Participate in emergency energy sharing

---

# 4. Core Product Pillars

## 4.1 AI-First Energy Optimization

VoltShare uses AI and rule-based intelligence to provide:

* Energy-generation forecasts
* Energy-consumption forecasts
* Best selling-time recommendations
* Best buying-time recommendations
* Battery charge and discharge suggestions
* Dynamic price recommendations
* Anomaly detection
* Predictive maintenance alerts

## 4.2 Community-Driven Clean Energy

The platform allows users within the same community to exchange locally generated renewable energy.

This reduces dependency on the central electricity grid.

## 4.3 Lower Electricity Costs

Consumers can purchase locally generated solar energy at prices lower than traditional grid electricity rates.

Producers can earn money by selling excess solar energy.

## 4.4 Smart Peer-to-Peer Trading

The marketplace supports:

* Manual energy listing discovery
* AI-assisted producer matching
* Dynamic pricing
* Producer reliability scores
* Location-aware recommendations

## 4.5 Sustainability Impact

The platform tracks:

* Renewable energy generated
* Renewable energy consumed
* CO₂ emissions avoided
* Community sustainability score
* Clean-energy achievements

---

# 5. User Roles

VoltShare uses a single user account with dynamic roles.

A user may initially register as a consumer and later become a producer or prosumer.

## 5.1 Consumer

A consumer can:

* View nearby energy listings
* Purchase renewable energy
* Monitor electricity usage
* View smart-meter data
* Track expenses
* View sustainability impact
* Receive AI recommendations

## 5.2 Producer

A producer can:

* Register solar assets
* Monitor solar generation
* Manage battery storage
* Create energy listings
* Set prices within platform limits
* Track earnings
* View reputation score
* Receive AI selling recommendations

## 5.3 Prosumer

A prosumer can both buy and sell energy.

## 5.4 Technician

A technician can:

* View assigned maintenance tasks
* Inspect solar equipment
* Update maintenance status
* Submit inspection reports
* Resolve equipment alerts

## 5.5 Grid Operator

A grid operator can:

* Monitor community energy flow
* View grid status
* Monitor emergency events
* Approve emergency allocations
* View system load information

## 5.6 Admin

An administrator can:

* Manage users
* Verify producers
* Manage marketplace limits
* Monitor transactions
* Review emergency events
* View analytics
* Manage platform configuration

## 5.7 AI Monitoring System

The AI monitoring system performs:

* Forecasting
* Anomaly detection
* Price recommendations
* Matching
* Battery optimization
* Emergency allocation recommendations
* Sustainability calculations

---

# 6. Platform Scope

## 6.1 Flutter Mobile App

Used by:

* Consumers
* Producers
* Prosumers
* Technicians

## 6.2 Flutter Web Dashboard

Used by:

* Admin
* Grid Operator

---

# 7. MVP Scope

The hackathon MVP must focus on a working end-to-end demonstration.

## 7.1 Real Features

The following features should be implemented using real backend functionality:

* Flutter navigation
* Supabase authentication
* User profile storage
* Role-based access
* Marketplace listings
* Wallet records
* Transaction records
* Notifications stored in the database
* Realtime listing updates
* Gemini-powered recommendation explanations

## 7.2 Simulated Features

The following features may use realistic simulated data:

* Smart-meter readings
* Solar generation
* Energy consumption
* Battery percentage
* Battery health
* Grid status
* Emergency event detection
* Energy transfer
* Payment processing
* Forecast values
* Dynamic price values
* Anomaly detection output
* Equipment failure prediction

## 7.3 Future Features

The following must not block the MVP:

* Real smart-meter integration
* Real inverter integration
* Real KSEB integration
* Real electricity transfer
* Production payment processing
* Advanced machine-learning models
* Government disaster-response integration
* Blockchain energy contracts

---

# 8. Technology Stack

## 8.1 Frontend

* Flutter
* Dart
* Material 3
* Riverpod
* GoRouter
* FL Chart

## 8.2 Backend

* Supabase
* FastAPI
* Python

## 8.3 Database

* Supabase PostgreSQL

## 8.4 Authentication

* Supabase Auth

## 8.5 Storage

* Supabase Storage

## 8.6 Realtime

* Supabase Realtime

## 8.7 AI

* Google Gemini API
* Rule-based decision engine
* Lightweight machine-learning models where practical
* Simulated forecasting fallback

## 8.8 Maps

* Google Maps Flutter

For the first MVP version, a static community map or mock map may be used.

## 8.9 Payments

* Simulated wallet transaction for MVP
* Razorpay sandbox may be added later

## 8.10 Notifications

* Supabase notification records for MVP
* Firebase Cloud Messaging may be added later

---

# 9. High-Level Architecture

```text
Flutter Mobile App
        |
        |---- Supabase Auth
        |
        |---- Supabase PostgreSQL
        |
        |---- Supabase Storage
        |
        |---- Supabase Realtime
        |
        |---- FastAPI AI Service
                    |
                    |---- Gemini API
                    |
                    |---- Rule Engine
                    |
                    |---- Forecasting Logic
```

---

# 10. Flutter Architecture

Use a feature-first Flutter architecture.

```text
frontend/
├── lib/
│   ├── app/
│   │   ├── app.dart
│   │   ├── router.dart
│   │   └── theme.dart
│   │
│   ├── core/
│   │   ├── constants/
│   │   ├── errors/
│   │   ├── services/
│   │   ├── utils/
│   │   └── widgets/
│   │
│   ├── features/
│   │   ├── authentication/
│   │   ├── dashboard/
│   │   ├── marketplace/
│   │   ├── battery/
│   │   ├── smart_meter/
│   │   ├── wallet/
│   │   ├── transactions/
│   │   ├── sustainability/
│   │   ├── maintenance/
│   │   ├── emergency/
│   │   ├── profile/
│   │   ├── notifications/
│   │   ├── admin/
│   │   └── grid_operator/
│   │
│   └── main.dart
│
├── assets/
└── pubspec.yaml
```

Each feature should contain:

```text
feature_name/
├── data/
├── domain/
└── presentation/
```

Use Riverpod for state management.

Use GoRouter for navigation.

---

# 11. Main Navigation

After login, users should reach the dashboard.

The primary mobile navigation includes:

* Dashboard
* Marketplace
* Wallet
* Analytics
* Profile

Additional screens are accessible from the dashboard or profile menu:

* Solar Assets
* Battery
* Smart Meter
* Transactions
* Maintenance
* Notifications
* Emergency Mode
* Settings

---

# 12. Authentication

## 12.1 Registration Fields

The registration process should collect:

### Basic Information

* Full name
* Email
* Phone number
* Password
* Confirm password

### Address

* House name or number
* Street
* City
* District
* State
* Postal code
* Latitude
* Longitude

### Identity Verification

* Identity document type
* Identity document number
* Identity document upload
* Verification status

### Solar Information

Optional during initial consumer registration.

* Has solar installation
* Solar panel capacity
* Installation date
* Inverter model
* Battery available
* Battery capacity

### Banking and Payment

* Account holder name
* Bank name
* Account number
* IFSC code
* UPI ID

For MVP, banking data may use mock values.

## 12.2 User Roles

Supported roles:

```text
consumer
producer
prosumer
technician
grid_operator
admin
```

## 12.3 Authentication Requirements

* Email and password registration
* Email and password login
* Logout
* Persistent user session
* Protected routes
* Role-based routing
* Clear authentication errors

---

# 13. Dashboard

The dashboard should display cards or widgets for:

* Solar generation
* Energy consumption
* Smart-meter reading
* Battery level
* Wallet balance
* Savings compared with grid electricity
* Available energy to sell
* AI recommendation
* Carbon savings
* Sustainability score
* Notifications
* Community energy statistics
* Local energy network map

## 13.1 Dashboard Mock Data Example

```json
{
  "solar_generation_today": 32.5,
  "energy_consumption_today": 18.2,
  "energy_available_to_sell": 8.5,
  "battery_percentage": 82,
  "battery_health": 94,
  "wallet_balance": 845.50,
  "grid_savings": 214.00,
  "co2_reduced_kg": 18.6,
  "sustainability_score": 86
}
```

---

# 14. Solar Asset Management

A user may register one or more solar assets.

Required fields:

* Asset name
* Panel capacity in kW
* Panel count
* Installation date
* Inverter model
* Status
* Current generation
* Last maintenance date
* Verification status

Possible statuses:

```text
active
inactive
maintenance_required
offline
```

---

# 15. Smart Meter Module

The smart-meter screen displays:

* Current power reading
* Today's total consumption
* Today's solar production
* Imported energy
* Exported energy
* Voltage
* Current
* Meter status
* Last updated time

For the MVP, values may update every few seconds using simulated data.

---

# 16. Battery Management

The battery module displays:

* Battery percentage
* Stored energy
* Battery capacity
* Battery health
* Charging status
* Discharging status
* Estimated backup duration
* Emergency reserve
* Scheduled charging
* Scheduled selling

## 16.1 Battery Modes

```text
automatic
store_energy
sell_energy
emergency_reserve
```

## 16.2 AI Battery Recommendations

Examples:

* Store energy until peak demand.
* Sell 4 kWh after 6 PM.
* Keep 25% emergency reserve.
* Battery health has decreased below 80%.
* Avoid discharge during low-price hours.

---

# 17. Marketplace

VoltShare uses a hybrid marketplace.

Users can:

* Browse listings manually
* Filter listings
* View seller reputation
* Purchase energy
* Use AI-assisted matching

## 17.1 Energy Listing Fields

Each listing should display:

* Producer name
* Producer rating
* Reliability score
* Verification status
* Available energy
* Price per kWh
* Distance
* Listing status
* Valid-until time
* Estimated availability

## 17.2 Listing Filters

* Lowest price
* Shortest distance
* Highest reliability
* Largest energy availability
* Verified producers only

## 17.3 AI Matching

The `Find Best Energy` feature should recommend a listing based on:

* Price
* Distance
* Energy availability
* Producer reliability
* Recent transaction success
* Grid conditions
* Risk score

## 17.4 Marketplace Listing Status

```text
active
partially_filled
completed
expired
cancelled
```

---

# 18. Pricing Model

VoltShare uses hybrid pricing.

The platform defines:

* Minimum price per kWh
* Maximum price per kWh

The producer selects a price within this range.

The AI may suggest an optimal price.

## 18.1 Price Recommendation Inputs

* Local supply
* Local demand
* Time of day
* Energy availability
* Historical transactions
* Battery status
* Weather conditions
* Grid load

## 18.2 Example Recommendation

```json
{
  "minimum_price": 4.0,
  "maximum_price": 7.0,
  "producer_price": 5.2,
  "recommended_price": 5.8,
  "reason": "Demand is expected to increase during evening peak hours."
}
```

---

# 19. Wallet

The wallet screen should display:

* Current balance
* Pending balance
* Total earnings
* Total spending
* Withdraw button
* Add money button
* Transaction history

## 19.1 Wallet Transaction Types

```text
energy_purchase
energy_sale
wallet_credit
wallet_debit
withdrawal
refund
emergency_allocation
```

---

# 20. Energy Purchase Flow

```text
Consumer selects listing
        ↓
Consumer selects energy quantity
        ↓
Application calculates total amount
        ↓
Consumer confirms purchase
        ↓
Wallet balance is checked
        ↓
Mock payment or wallet debit occurs
        ↓
Transaction record is created
        ↓
Listing availability is reduced
        ↓
Producer wallet is credited
        ↓
Sustainability metrics are updated
        ↓
Both users receive notifications
```

---

# 21. AI Architecture

VoltShare uses hybrid AI.

## 21.1 Forecasting Engine

Produces:

* Predicted solar generation
* Predicted household consumption
* Predicted demand
* Predicted market price
* Best selling time
* Best buying time

For MVP, use rule-based or simulated forecasting.

## 21.2 Rule Engine

The rule engine handles:

* Battery recommendations
* Price-range enforcement
* Emergency reserve rules
* Marketplace matching
* Sustainability score
* Maintenance alerts

## 21.3 Gemini Energy Assistant

Gemini should not calculate critical numeric forecasts independently.

FastAPI should generate or retrieve structured forecast values.

Gemini should convert those values into clear advice.

## 21.4 Gemini Input Example

```json
{
  "predicted_generation": 38.5,
  "predicted_consumption": 26.0,
  "battery_percentage": 82,
  "available_energy": 7.5,
  "recommended_sell_time": "6:00 PM",
  "recommended_price": 5.8,
  "weather": "Sunny",
  "market_demand": "High"
}
```

## 21.5 Gemini Output Example

```text
Your battery is already 82% charged, and local energy demand is expected to increase after 6 PM. Keep at least 25% battery capacity as emergency reserve and consider selling approximately 7 kWh during the evening peak period.
```

---

# 22. AI Features

The MVP should demonstrate:

* Solar-generation forecast
* Consumption forecast
* Best selling-time recommendation
* Best buying-time recommendation
* Dynamic price suggestion
* Battery optimization
* Equipment anomaly warning
* Predictive maintenance warning
* Producer-consumer matching
* Sustainability advice
* Gemini natural-language explanation

---

# 23. Predictive Maintenance

The system should detect or simulate:

* Sudden drop in solar production
* Battery degradation
* Smart-meter inconsistency
* Inverter malfunction
* Communication failure

## 23.1 Maintenance Alert Example

```json
{
  "asset": "Rooftop Solar Unit",
  "severity": "medium",
  "issue": "Generation is 28% below the expected value.",
  "recommendation": "Inspect panel cleanliness and inverter status."
}
```

---

# 24. Sustainability System

The sustainability module displays:

* Total renewable energy generated
* Renewable energy purchased
* Renewable energy sold
* CO₂ emissions avoided
* Equivalent trees
* Community contribution
* Sustainability score

## 24.1 Achievements

### Green Energy Champion

Awarded when users reach major renewable-energy contribution targets.

### CO₂ Reduction Milestones

Suggested milestones:

* 10 kg CO₂ avoided
* 50 kg CO₂ avoided
* 100 kg CO₂ avoided
* 500 kg CO₂ avoided

### Sustainability Score

Score range:

```text
0 to 100
```

Possible calculation inputs:

* Renewable energy generated
* Renewable energy shared
* Renewable energy purchased
* CO₂ avoided
* Battery optimization
* Efficient consumption
* Community participation

---

# 25. Producer Reputation System

Each producer should have:

* Rating
* Reliability score
* Completed transactions
* Cancelled transactions
* Successful delivery percentage
* Verification badge
* Community reviews

## 25.1 Example Reputation Data

```json
{
  "rating": 4.8,
  "reliability_score": 96,
  "successful_transactions": 128,
  "cancelled_transactions": 2,
  "verified": true
}
```

---

# 26. Emergency Energy Sharing

This is the flagship feature.

## 26.1 Emergency Scenario

A community power outage is simulated.

The platform should:

1. Detect or activate an emergency event.
2. Identify critical consumers.
3. Identify nearby producers with available energy.
4. Check producer battery reserve.
5. Recommend energy allocations.
6. Allow admin or grid operator approval.
7. Display emergency distribution status.
8. Update community resilience metrics.

## 26.2 Critical Consumer Types

```text
hospital
elderly_home
emergency_shelter
medical_device_user
public_service
residential
```

## 26.3 Emergency Allocation Criteria

* Priority level
* Distance
* Available energy
* Battery reserve
* Producer reliability
* Consumer requirement
* Grid status

## 26.4 Emergency Workflow

```text
Emergency detected
        ↓
Critical consumers identified
        ↓
Nearby producers identified
        ↓
Available energy calculated
        ↓
AI allocation generated
        ↓
Grid operator or admin approves
        ↓
Simulated allocation completed
        ↓
Emergency dashboard updated
```

---

# 27. Notifications

Supported notification types:

* Energy sold
* Energy purchased
* Payment received
* Wallet debited
* Battery fully charged
* Low battery
* High market demand
* Price recommendation
* Maintenance alert
* Emergency detected
* Emergency allocation approved
* Achievement unlocked

---

# 28. Maintenance Module

Technicians should be able to:

* View assigned jobs
* View customer and asset details
* Update job status
* Add inspection notes
* Upload inspection images
* Mark a job complete

Maintenance statuses:

```text
open
assigned
in_progress
completed
cancelled
```

---

# 29. Admin Dashboard

The admin web dashboard should display:

* Total users
* Total producers
* Total consumers
* Active listings
* Total energy traded
* Total transaction value
* Community CO₂ reduction
* Active maintenance alerts
* Active emergency events

Admin screens:

* Dashboard
* Users
* Producer verification
* Marketplace monitoring
* Transactions
* Emergency control
* Maintenance
* Reports
* Settings

---

# 30. Grid Operator Dashboard

The grid operator dashboard should display:

* Current community demand
* Current community supply
* Grid import
* Grid export
* Active producers
* Active consumers
* Emergency status
* Community energy map
* Energy allocation recommendations

---

# 31. Supabase Database Schema

## 31.1 profiles

```text
id uuid primary key
email text
full_name text
phone text
role text
avatar_url text
address text
city text
district text
state text
postal_code text
latitude numeric
longitude numeric
kyc_status text
is_verified boolean
created_at timestamptz
updated_at timestamptz
```

## 31.2 solar_assets

```text
id uuid primary key
user_id uuid references profiles
asset_name text
capacity_kw numeric
panel_count integer
installation_date date
inverter_model text
status text
current_generation_kw numeric
last_maintenance_date date
is_verified boolean
created_at timestamptz
```

## 31.3 smart_meters

```text
id uuid primary key
user_id uuid references profiles
meter_number text
current_reading numeric
today_consumption_kwh numeric
today_generation_kwh numeric
imported_energy_kwh numeric
exported_energy_kwh numeric
voltage numeric
current_amp numeric
status text
last_updated timestamptz
```

## 31.4 batteries

```text
id uuid primary key
user_id uuid references profiles
capacity_kwh numeric
stored_energy_kwh numeric
percentage numeric
health_percentage numeric
status text
mode text
emergency_reserve_percentage numeric
estimated_backup_hours numeric
updated_at timestamptz
```

## 31.5 marketplace_listings

```text
id uuid primary key
producer_id uuid references profiles
available_energy_kwh numeric
price_per_kwh numeric
minimum_purchase_kwh numeric
status text
latitude numeric
longitude numeric
valid_until timestamptz
created_at timestamptz
updated_at timestamptz
```

## 31.6 energy_transactions

```text
id uuid primary key
listing_id uuid references marketplace_listings
buyer_id uuid references profiles
seller_id uuid references profiles
energy_kwh numeric
price_per_kwh numeric
total_amount numeric
status text
transaction_type text
created_at timestamptz
completed_at timestamptz
```

## 31.7 wallets

```text
id uuid primary key
user_id uuid references profiles
balance numeric
pending_balance numeric
total_earnings numeric
total_spending numeric
updated_at timestamptz
```

## 31.8 wallet_transactions

```text
id uuid primary key
wallet_id uuid references wallets
user_id uuid references profiles
type text
amount numeric
description text
reference_id uuid
created_at timestamptz
```

## 31.9 forecasts

```text
id uuid primary key
user_id uuid references profiles
forecast_date date
predicted_generation_kwh numeric
predicted_consumption_kwh numeric
predicted_demand text
predicted_price numeric
best_sell_time text
best_buy_time text
confidence numeric
created_at timestamptz
```

## 31.10 ai_recommendations

```text
id uuid primary key
user_id uuid references profiles
recommendation_type text
title text
message text
priority text
is_read boolean
created_at timestamptz
```

## 31.11 maintenance_requests

```text
id uuid primary key
user_id uuid references profiles
technician_id uuid references profiles
solar_asset_id uuid references solar_assets
title text
description text
severity text
status text
inspection_notes text
created_at timestamptz
updated_at timestamptz
completed_at timestamptz
```

## 31.12 notifications

```text
id uuid primary key
user_id uuid references profiles
type text
title text
message text
is_read boolean
created_at timestamptz
```

## 31.13 sustainability_metrics

```text
id uuid primary key
user_id uuid references profiles
renewable_generated_kwh numeric
renewable_purchased_kwh numeric
renewable_sold_kwh numeric
co2_reduced_kg numeric
trees_equivalent numeric
sustainability_score numeric
updated_at timestamptz
```

## 31.14 achievements

```text
id uuid primary key
user_id uuid references profiles
achievement_type text
title text
description text
progress numeric
is_unlocked boolean
unlocked_at timestamptz
```

## 31.15 emergency_events

```text
id uuid primary key
title text
description text
location text
latitude numeric
longitude numeric
severity text
status text
detected_at timestamptz
resolved_at timestamptz
created_by uuid references profiles
```

## 31.16 emergency_allocations

```text
id uuid primary key
emergency_event_id uuid references emergency_events
producer_id uuid references profiles
consumer_id uuid references profiles
allocated_energy_kwh numeric
priority_level integer
status text
approved_by uuid references profiles
created_at timestamptz
approved_at timestamptz
```

---

# 32. FastAPI Structure

```text
backend/
├── app/
│   ├── main.py
│   ├── config.py
│   ├── dependencies.py
│   │
│   ├── api/
│   │   ├── forecast.py
│   │   ├── recommendations.py
│   │   ├── marketplace.py
│   │   ├── battery.py
│   │   ├── sustainability.py
│   │   ├── anomalies.py
│   │   └── emergency.py
│   │
│   ├── services/
│   │   ├── gemini_service.py
│   │   ├── forecast_service.py
│   │   ├── recommendation_service.py
│   │   ├── pricing_service.py
│   │   ├── matching_service.py
│   │   ├── battery_service.py
│   │   ├── sustainability_service.py
│   │   └── emergency_service.py
│   │
│   ├── schemas/
│   ├── models/
│   └── utils/
│
├── requirements.txt
└── .env.example
```

---

# 33. FastAPI Endpoints

## 33.1 Health Check

```text
GET /health
```

Response:

```json
{
  "status": "ok",
  "service": "VoltShare AI API"
}
```

## 33.2 Forecast

```text
POST /api/v1/forecast
```

Request:

```json
{
  "user_id": "uuid",
  "historical_generation": [20.5, 22.1, 24.8],
  "historical_consumption": [16.0, 17.2, 18.5],
  "battery_percentage": 82,
  "weather": "sunny"
}
```

Response:

```json
{
  "predicted_generation_kwh": 38.5,
  "predicted_consumption_kwh": 26.0,
  "predicted_demand": "high",
  "best_sell_time": "18:00",
  "recommended_price": 5.8,
  "confidence": 0.91
}
```

## 33.3 AI Recommendation

```text
POST /api/v1/recommendations
```

Response should include:

```json
{
  "title": "Sell During Evening Peak",
  "recommendation": "Sell approximately 7 kWh after 6 PM.",
  "reason": "Demand and market prices are expected to increase.",
  "priority": "high"
}
```

## 33.4 Marketplace Matching

```text
POST /api/v1/marketplace/match
```

Request:

```json
{
  "consumer_id": "uuid",
  "required_energy_kwh": 5,
  "maximum_price": 6.0,
  "latitude": 9.85,
  "longitude": 76.94
}
```

Response:

```json
{
  "recommended_listing_id": "uuid",
  "match_score": 94,
  "reason": "Lowest effective price with high producer reliability."
}
```

## 33.5 Price Recommendation

```text
POST /api/v1/pricing/recommend
```

## 33.6 Battery Recommendation

```text
POST /api/v1/battery/recommend
```

## 33.7 Anomaly Detection

```text
POST /api/v1/anomalies/detect
```

## 33.8 Sustainability Score

```text
POST /api/v1/sustainability/calculate
```

## 33.9 Emergency Allocation

```text
POST /api/v1/emergency/allocate
```

---

# 34. User Interface Guidelines

## 34.1 Visual Style

The application should feel:

* Modern
* Clean
* Sustainable
* Technical
* Trustworthy
* Community-focused

## 34.2 Suggested Theme

Primary visual direction:

* Dark green
* Emerald
* Teal
* Soft white
* Neutral gray
* Energy yellow for warnings and highlights

## 34.3 Design Principles

* Use rounded cards
* Use clear data visualizations
* Avoid dense screens
* Use large energy metrics
* Use icons for quick understanding
* Use skeleton loading states
* Use empty states
* Use clear confirmation dialogs
* Make emergency screens visually distinct

## 34.4 Accessibility

* Readable font sizes
* Clear contrast
* Large touch targets
* Semantic labels
* Avoid color-only status indicators

---

# 35. Core Screens

## 35.1 Authentication

* Splash screen
* Login screen
* Registration screen
* Forgot password screen
* KYC screen

## 35.2 Main User Screens

* Dashboard
* Marketplace
* Listing details
* Create listing
* Buy energy
* Wallet
* Transactions
* Battery
* Smart meter
* Solar assets
* AI assistant
* Sustainability
* Maintenance
* Notifications
* Emergency mode
* Profile
* Settings

## 35.3 Admin Screens

* Admin dashboard
* User management
* Producer verification
* Marketplace monitor
* Transaction monitor
* Emergency control
* Maintenance monitor
* Reports
* Settings

## 35.4 Grid Operator Screens

* Grid dashboard
* Community energy map
* Demand and supply
* Emergency monitor
* Allocation approval

## 35.5 Technician Screens

* Assigned jobs
* Job details
* Inspection form
* Maintenance history

---

# 36. Demo Scenarios

## 36.1 Scenario A — Normal Energy Trading

1. Producer logs in.
2. Dashboard shows excess solar energy.
3. AI recommends a selling price and selling time.
4. Producer creates an energy listing.
5. Consumer logs in.
6. Consumer browses the marketplace.
7. Consumer uses `Find Best Energy`.
8. Consumer purchases energy.
9. Wallet balances update.
10. Transaction appears in history.
11. Sustainability score and CO₂ savings update.
12. Both users receive notifications.

## 36.2 Scenario C — Emergency Energy Sharing

1. Admin activates a simulated community power outage.
2. AI identifies critical consumers.
3. AI identifies nearby producers with available energy.
4. Emergency allocations are generated.
5. Grid operator approves the allocation.
6. The dashboard displays energy distribution.
7. Community resilience metrics update.
8. Emergency status is marked resolved.

---

# 37. Development Phases

## Phase 1 — Foundation

Tasks:

* Create Flutter project
* Configure Material 3
* Add Riverpod
* Add GoRouter
* Create theme
* Create feature-first folder structure
* Build splash screen
* Build login screen
* Build registration screen
* Build dashboard shell
* Add bottom navigation
* Use mock data only

Acceptance criteria:

* Application runs without errors.
* Navigation works.
* Login and registration UI works.
* Dashboard is visible.
* Mock energy data is displayed.
* Layout works on mobile and web.

## Phase 2 — Supabase Authentication

Tasks:

* Configure Supabase
* Implement registration
* Implement login
* Implement logout
* Implement persistent session
* Create profile records
* Add role-based routing

Acceptance criteria:

* Users can create accounts.
* Users can log in and log out.
* Session persists after restart.
* Protected screens cannot be opened without authentication.

## Phase 3 — Dashboard and Monitoring

Tasks:

* Add dashboard cards
* Add mock smart-meter updates
* Add solar-generation chart
* Add consumption chart
* Add battery status
* Add AI insight card

Acceptance criteria:

* Dashboard data updates.
* Charts render correctly.
* Battery and meter data are visible.
* AI recommendation is displayed.

## Phase 4 — Marketplace

Tasks:

* Create energy listings
* Browse listings
* Filter listings
* View listing details
* Implement `Find Best Energy`
* Implement mock purchase flow

Acceptance criteria:

* Producer can create a listing.
* Consumer can browse and purchase energy.
* Listing availability updates.
* Transaction record is created.

## Phase 5 — Wallet and Transactions

Tasks:

* Wallet balance
* Mock credit and debit
* Transaction history
* Producer earnings
* Consumer spending

Acceptance criteria:

* Purchase reduces buyer balance.
* Sale increases seller balance.
* Transactions are stored and displayed.

## Phase 6 — AI and Gemini

Tasks:

* Create FastAPI backend
* Add forecast endpoint
* Add pricing endpoint
* Add battery recommendation
* Add marketplace matching
* Add Gemini explanation service

Acceptance criteria:

* Flutter can call FastAPI.
* Structured forecast data is returned.
* Gemini converts data into clear advice.
* Rule-based fallback works if Gemini fails.

## Phase 7 — Sustainability

Tasks:

* Calculate CO₂ savings
* Calculate sustainability score
* Add Green Energy Champion
* Add CO₂ milestones
* Add sustainability dashboard

Acceptance criteria:

* Sustainability values update after transactions.
* Achievements unlock based on thresholds.

## Phase 8 — Emergency Sharing

Tasks:

* Create emergency event
* Identify producers
* Identify critical consumers
* Generate allocation
* Build admin approval flow
* Display emergency status

Acceptance criteria:

* Emergency scenario can be demonstrated from start to finish.
* Allocation results are visible.
* Admin or grid operator can approve allocation.

## Phase 9 — Final Polish

Tasks:

* Error handling
* Loading states
* Empty states
* Responsive design
* Demo data
* Demo accounts
* Final testing
* Presentation preparation

---

# 38. Demo Accounts

Create the following sample users:

```text
Producer:
producer@voltshare.demo
Role: producer

Consumer:
consumer@voltshare.demo
Role: consumer

Admin:
admin@voltshare.demo
Role: admin

Grid Operator:
grid@voltshare.demo
Role: grid_operator

Technician:
technician@voltshare.demo
Role: technician
```

Use demo passwords stored securely in development configuration.

---

# 39. Error Handling

The application should handle:

* Invalid login
* Duplicate email
* Network failure
* Supabase failure
* FastAPI failure
* Gemini failure
* Insufficient wallet balance
* Invalid energy quantity
* Expired listing
* Listing unavailable
* Unauthorized role
* Missing profile
* Missing solar asset

All errors should produce understandable messages.

---

# 40. Security Requirements

* Do not store passwords manually.
* Use Supabase Auth.
* Use environment variables.
* Never expose service-role keys in Flutter.
* Validate all FastAPI inputs.
* Add Supabase row-level security.
* Restrict admin and grid-operator routes.
* Do not store real banking information in the hackathon prototype.
* Do not expose Gemini API keys in the frontend.

---

# 41. Non-Functional Requirements

* Responsive on mobile and web
* Fast initial load
* Modular codebase
* Reusable widgets
* Clear separation of concerns
* Secure authentication
* Reliable demo behavior
* Graceful fallback for AI failures
* Consistent UI theme
* Maintainable folder structure
* Clear README and setup instructions

---

# 42. Definition of Done

The VoltShare MVP is complete when:

* Users can register and log in.
* Role-based navigation works.
* Dashboard displays energy information.
* Producer can create an energy listing.
* Consumer can purchase energy.
* Wallet and transaction records update.
* AI recommendation is displayed.
* Gemini provides natural-language advice.
* Sustainability score is visible.
* Green Energy Champion and CO₂ milestones work.
* Emergency energy sharing can be demonstrated.
* Admin and grid-operator dashboards are accessible.
* The application runs without critical errors.

---

# 43. Codex Implementation Rules

When Codex works on this project, it must follow these rules:

1. Read this entire specification before modifying code.
2. Implement one development phase at a time.
3. Do not build all features in one request.
4. Do not change unrelated files.
5. Use clean architecture and reusable components.
6. Use mock data before backend integration.
7. Keep the app runnable after every phase.
8. Run available tests and static analysis.
9. Explain every file created or modified.
10. Do not expose API keys.
11. Add placeholders where external services are unavailable.
12. Ask for approval before starting the next major phase.
13. Preserve existing working features.
14. Update documentation after each phase.
15. Prefer stable demo behavior over unnecessary complexity.

---

# 44. First Codex Task

Use this prompt after placing this file in the project root:

```text
Read spec.md completely.

We are building VoltShare as a two-day hackathon MVP.

Do not implement the entire specification.

Start with Phase 1 — Foundation only.

Requirements:

1. Inspect the current project structure.
2. Configure Flutter with:
   - Material 3
   - Riverpod
   - GoRouter
3. Create the feature-first folder structure defined in spec.md.
4. Build:
   - Splash screen
   - Login screen
   - Registration screen
   - Dashboard shell
   - Bottom navigation
5. Use realistic mock dashboard data.
6. Do not integrate Supabase, FastAPI, Gemini, maps, payments, or notifications yet.
7. Ensure the application runs without errors on Flutter mobile and Flutter web.
8. Run flutter analyze.
9. Fix all new errors introduced by the implementation.
10. After completion, list every file created or modified and explain how to run the application.

Before writing code, provide a concise implementation plan.
```
