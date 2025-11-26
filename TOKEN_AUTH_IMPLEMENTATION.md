# Token-Based Authentication for Subscription Management

## ✅ What's Been Implemented (Backend)

### 1. Token Generation System
**File**: `functions/subscriptionTokenService.js`

- Generates secure 64-character random tokens
- Stores tokens in Firestore `subscriptionTokens` collection
- Token expiration: 72 hours (configurable)
- One-time use tokens (marked as used after validation)
- Automatic cleanup of expired tokens

### 2. Updated Trial Warning Emails
**Modified**: `functions/trialManagementFunctions.js` & `functions/emailService.js`

- Trial expiration emails now generate secure tokens
- Email links include token: `https://chronoworks-dcfd6.web.app/subscription-plans?token=ABC123...`
- Token is unique per company and user
- Falls back to regular URL if token generation fails

### 3. Token Validation & Authentication Function
**Function**: `validateAndAuthenticateToken`

- Validates subscription tokens from email links
- Creates Firebase custom auth tokens for automatic login
- Returns: customToken, companyId, userId
- Handles expired/used/invalid tokens with proper errors

### 4. Deployed Functions
All 27 functions deployed including:
- `validateAndAuthenticateToken` (NEW)
- `checkTrialExpirations` (UPDATED with token generation)
- All email service functions (UPDATED with token URLs)

---

## ⏳ What Still Needs to Be Done (Frontend - Flutter Web)

### Step 1: Detect Token in URL
When the Flutter web app loads, check for `?token=` parameter:

```dart
// In main.dart or subscription_plans_page.dart
@override
void initState() {
  super.initState();
  _checkForToken();
}

Future<void> _checkForToken() async {
  // Get URL parameters
  final uri = Uri.base;
  final token = uri.queryParameters['token'];

  if (token != null && token.isNotEmpty) {
    await _authenticateWithToken(token);
  }
}
```

### Step 2: Call Backend to Validate Token
```dart
Future<void> _authenticateWithToken(String token) async {
  try {
    // Call Cloud Function
    final callable = FirebaseFunctions.instance.httpsCallable(
      'validateAndAuthenticateToken'
    );

    final result = await callable.call({'token': token});
    final data = result.data;

    if (data['success'] == true) {
      final customToken = data['customToken'];
      final companyId = data['companyId'];

      // Sign in with custom token
      await FirebaseAuth.instance.signInWithCustomToken(customToken);

      // Navigate to subscription page (already there)
      // The page will load subscription data for the authenticated user

      // Optional: Remove token from URL to prevent reuse
      window.history.replaceState({}, '', '/subscription-plans');
    }
  } catch (e) {
    // Show error: Invalid or expired link
    _showTokenError(e.toString());
  }
}
```

### Step 3: Handle Token Errors
```dart
void _showTokenError(String error) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Invalid Link'),
      content: Text(
        'This subscription management link has expired or is invalid. '
        'Please contact support or log in to manage your subscription.'
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            // Redirect to login
          },
          child: Text('Log In'),
        ),
      ],
    ),
  );
}
```

### Step 4: Update Firestore Security Rules
Add rules for `subscriptionTokens` collection:

```javascript
// In firestore.rules
match /subscriptionTokens/{tokenId} {
  // Only Cloud Functions can write tokens
  allow read, write: if false;
}
```

---

## 🧪 Testing the Implementation

### Test 1: Send Test Email with Token
```bash
cd C:\Users\chris\ChronoWorks\scripts
node test_sendgrid.js
```

Check email for tokenized URL like:
```
https://chronoworks-dcfd6.web.app/subscription-plans?token=a1b2c3d4...
```

### Test 2: Click Email Link
1. Click "View Subscription Plans" button in email
2. Should open web app at `/subscription-plans?token=...`
3. (Once Flutter code is added) Should auto-login and show subscription page

### Test 3: Try to Reuse Token
1. Click email link again
2. Should show "Invalid or expired token" error
3. Tokens are one-time use only

---

## 📊 How It Works (Flow Diagram)

```
1. BACKEND: Trial expiring in 3 days
   ↓
2. Generate secure random token
   ↓
3. Store in Firestore: subscriptionTokens/{id}
   {
     token: "abc123...",
     companyId: "xyz",
     userId: "user123",
     expiresAt: timestamp,
     used: false
   }
   ↓
4. Send email with link:
   https://chronoworks-dcfd6.web.app/subscription-plans?token=abc123...
   ↓
5. USER: Clicks link
   ↓
6. FRONTEND: Detects token in URL
   ↓
7. Call validateAndAuthenticateToken({token: "abc123..."})
   ↓
8. BACKEND: Validates token, marks as used, creates Firebase custom token
   ↓
9. FRONTEND: Signs in with custom token
   ↓
10. User is authenticated and can manage subscription
```

---

## 🔒 Security Features

- **64-character random tokens** (crypto.randomBytes)
- **One-time use** (marked as used after validation)
- **72-hour expiration** (configurable)
- **Stored securely in Firestore** (not in URL permanently)
- **Firebase custom auth tokens** (official Firebase auth method)
- **Company ID validation** (ensures user can only access their company)

---

## 📝 Next Steps

1. **Implement Flutter web token handling** (see Step 1-3 above)
2. **Update Firestore rules** (see Step 4 above)
3. **Test end-to-end flow** (send email → click link → auto-login → manage subscription)
4. **Optional**: Add token cleanup scheduled function to delete expired tokens
5. **Optional**: Add analytics to track token usage

---

## 🐛 Troubleshooting

### Email doesn't include token
- Check Firebase Functions logs for token generation errors
- Ensure company has `ownerId` field in Firestore

### Token validation fails
- Check if token expired (72 hours)
- Check if token was already used
- Verify Firestore has `subscriptionTokens` collection

### Authentication fails
- Ensure user exists in Firebase Auth
- Check userId matches in Firestore company document
- Verify custom token is being used correctly in Flutter

---

**Status**: Backend Complete ✅ | Frontend Pending ⏳
**Created**: 2025-11-19
