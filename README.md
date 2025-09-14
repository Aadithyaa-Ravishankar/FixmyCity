# Flutter Login App with Supabase

A Flutter application that implements phone number and email authentication using Supabase with OTP verification.

## Features

- **Dual Authentication**: Login with either phone number or email address
- **OTP Verification**: Secure one-time password verification via SMS or email
- **Modern UI**: Clean and intuitive user interface
- **Supabase Integration**: Backend authentication powered by Supabase
- **Auto-login**: Persistent authentication state management

## Setup Instructions

### 1. Install Dependencies

Run the following command to install all required dependencies:

```bash
flutter pub get
```

### 2. Supabase Configuration

The app is already configured with your Supabase credentials:
- **Project URL**: `https://cmsjmmtkdqjamsphsulv.supabase.co`
- **API Key**: Already configured in `lib/main.dart`

### 3. Supabase Setup

Make sure your Supabase project has the following settings:

1. **Enable Phone Authentication**:
   - Go to Authentication > Settings in your Supabase dashboard
   - Enable "Enable phone confirmations"
   - Configure your SMS provider (Twilio, etc.)

2. **Enable Email Authentication**:
   - Email confirmations should be enabled by default
   - Configure your email provider if needed

### 4. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart                    # App entry point and Supabase initialization
├── services/
│   └── auth_service.dart       # Authentication service with Supabase methods
└── screens/
    ├── login_screen.dart       # Login page with phone/email input
    ├── otp_verification_screen.dart  # OTP verification page
    └── home_screen.dart        # Home page after successful login
```

## Key Dependencies

- `supabase_flutter`: Supabase SDK for Flutter
- `intl_phone_field`: International phone number input field
- `pin_code_fields`: OTP input field with beautiful UI

## Authentication Flow

1. **Login Screen**: User chooses between phone or email login
2. **OTP Sending**: System sends verification code to chosen method
3. **OTP Verification**: User enters 6-digit code for verification
4. **Home Screen**: Successful authentication leads to home page
5. **Auto-login**: App remembers authentication state

## Usage

1. Launch the app
2. Choose between "Phone" or "Email" login
3. Enter your phone number or email address
4. Tap "Send Verification Code"
5. Enter the 6-digit code received
6. Tap "Verify Code" to complete login
7. Access the home screen upon successful verification

## Features

- **Responsive Design**: Works on different screen sizes
- **Error Handling**: Comprehensive error messages
- **Loading States**: Visual feedback during API calls
- **Resend OTP**: Option to resend verification code
- **Sign Out**: Secure logout functionality
- **User Info Display**: Shows authenticated user details

## Troubleshooting

- Ensure your Supabase project has phone/email authentication enabled
- Check your SMS/email provider configuration in Supabase
- Verify your API keys are correct
- Make sure you have internet connectivity for API calls



