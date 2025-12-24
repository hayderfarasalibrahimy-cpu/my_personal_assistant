---
description: بناء تطبيق Flutter APK مع التفاصيل الكاملة
---

# بناء تطبيق Flutter APK

## الخطوات:

// turbo-all

1. تنظيف المشروع:
```powershell
flutter clean
```

2. جلب الحزم:
```powershell
flutter pub get
```

3. بناء APK (نسخة Release مع التفاصيل):
```powershell
flutter build apk --release --verbose
```

## ملاحظات:
- ملف APK يوجد في: `build/app/outputs/flutter-apk/app-release.apk`
- استخدم `--verbose` لعرض تفاصيل البناء
- قد يستغرق البناء بضع دقائق

## في حال حدوث أخطاء:
- تحقق من إصدار Kotlin في `android/settings.gradle`
- تأكد من تحديث Android SDK
- شغل `flutter doctor` للتحقق من البيئة
