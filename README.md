# Food App - Flutter Client

A beautiful, premium, and feature-rich Flutter mobile application for the **Food App**, featuring secure user authentication, real-time BMI reports, community progress feed sharing, and AI-powered food image analysis.

---

## 🚀 Key Features

* **User Authentication & Session Management**:
  * Secure Register and Login screens.
  * State management handled via `Provider` (`UserProvider`) keeping JWT tokens active.
  * Auto-login capability using persistent storage.
  * Password reset workflow screens.

* **Dynamic Dashboard & BMI tracker**:
  * Custom animated calorie ring progress tracker.
  * Dynamic calculation of BMI (Body Mass Index), weight status, and estimated daily calorie budgets.
  * Dashboard summaries representing daily nutrition details.

* **AI Food recognition & Nutrition Scanning**:
  * Upload or capture food pictures using the device camera (`image_picker`).
  * Process images via the backend's Gemini AI engine.
  * Detailed macronutrient breakdown: Calories, Protein, Carbs, Fats, Sugars, healthy ingredients list, and health verdict.

* **Community Feed & Direct Messages**:
  * Social sharing section to post "Before & After" diet/exercise transformation metrics and images.
  * Interactive likes and comments on community posts.
  * Messaging window (`DMScreen`) for coach/peer advice and direct interaction.

* **User Profile Customization**:
  * Interactive edit profile interface to update weight, height, age, blood group, and health conditions, triggering automated BMI updates.

---

## 🛠️ Tech Stack

* **UI Framework**: Flutter & Dart (SDK `>=3.3.1 <4.0.0`)
* **State Management**: `provider` (dependency injection & user state management)
* **Networking**: `dio` (configured with automated interceptors for JWT token attachment and token refresh on `401 Unauthorized` responses)
* **Local Storage**: `shared_preferences` (persists tokens and user details)
* **Environment Configuration**: `flutter_dotenv` (loads dynamic environment variables)
* **Design & Typography**: Google Fonts (Outfit), Custom HSL color palettes, and glassmorphism-inspired components

---

## ⚙️ Setup & Installation

### 1. Prerequisites
Make sure you have Flutter installed. Follow the [Flutter SDK installation guide](https://docs.flutter.dev/get-started/install) for your OS.

### 2. Configure Environment Variables
Create a `.env` file in the root directory (already registered in `pubspec.yaml` assets) and configure your API URL:

```env
DEV_BASE_URL=http://127.0.0.1:3000/api/
PROD_BASE_URL=https://your-backend-api.onrender.com/api/
```

### 3. Run the App Locally

```bash
# Fetch dependencies
flutter pub get

# Run on connected device or emulator
flutter run
```

---

## 📁 Project Structure

```text
lib/
├── models/         # JSON serializable data models (UserModel, FoodAnalysisModel)
├── providers/      # ChangeNotifier providers for state management (UserProvider)
├── screens/        # Screen UI components (Dashboard, Feed, Auth, Profile)
├── services/       # Network calls & Dio interceptors (ApiService, ApiExceptions)
├── utils/          # Constants, configuration, & helper classes (ApiEndpoints, DialogHelper)
└── main.dart       # Application entry point & route configurations
```
