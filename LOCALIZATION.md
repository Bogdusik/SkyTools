# Localization Configuration

## DJI SDK Language Settings

SkyTools is configured to use **English** as the primary language. This affects:

1. **App Interface** - All SkyTools UI elements are in English
2. **DJI SDK Screens** - DJI SDK authorization and consent screens will display in English (if device language is English)

### Configuration

The app's localization is set in `project.pbxproj`:

```swift
INFOPLIST_KEY_CFBundleDevelopmentRegion = en;
INFOPLIST_KEY_CFBundleLocalizations = (en);
```

### Important Notes

⚠️ **DJI SDK Language Behavior:**

- DJI SDK screens (authorization, consent, terms) are controlled by **DJI SDK itself**
- These screens will display in the **device's system language** (not app language)
- If the device is set to Russian, DJI SDK screens will show in Russian
- If the device is set to English, DJI SDK screens will show in English

### To Ensure English DJI SDK Screens

**For Testing:**
1. Set your iPhone/iPad system language to **English**
2. Settings → General → Language & Region → iPhone Language → English

**For Production:**
- Users will see DJI SDK screens in their device language
- This is expected behavior and cannot be overridden by the app
- DJI SDK respects the user's system language preference

### SkyTools App Language

✅ **SkyTools app interface is always in English**, regardless of device language.

This is intentional for:
- Consistency across all users
- Professional appearance
- Easier support and documentation

---

**Last Updated:** January 2026
