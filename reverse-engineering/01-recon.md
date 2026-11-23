# Фаза 1 — Recon (розвідка)

Навчальний реверс OLX.ua. Мета фази: зрозуміти, з чим маємо справу, перш ніж щось чіпати.

## Ідентифікація

| Поле | Значення |
|---|---|
| Застосунок | OLX.ua (класифайди, OLX Group) |
| Package | `ua.slando` (історична назва — бренд Slando до ребрендингу) |
| versionName / versionCode | 5.20.5 / 3581 |
| minSdk / targetSdk | 22 / 30 |
| Розмір APK | ~16 МБ |
| Application-клас | `pl.tablica2.application.TablicaApplication` |
| Launcher Activity | `pl.tablica2.app.startup.activity.StartupActivity` |

> `tablica` — польською «дошка оголошень», внутрішній кодовий нейм. Усе ядро застосунку живе під `pl.tablica2.*`.

## Будова APK

- **Код:** 5 основних dex (`classes.dex`–`classes5.dex`) + `assets/audience_network.dex` (рекламний SDK Meta, вантажиться окремо).
- **Нативного коду немає** — жодного `.so`. Чистий Kotlin/Java. Це сильно спрощує реверс (немає чого дизасемблювати в ARM).
- **Пакера немає** — dex лежать відкрито, не зашифровані й не підвантажуються з рантайму.

## Масштаб коду

Після декомпіляції: **37 811 .smali-файлів**. Але реальний код OLX — це лише:

| Пакет | Файлів | Що це |
|---|---|---|
| `pl/tablica2` | 5 054 | ядро застосунку (activities, fragments, логіка) |
| `com/olxgroup` | 2 444 | чат, laquesis (A/B), спільні модулі |
| `pl/olx` | 887 | adview, пошук, локація, oauth |
| `com/olx` | 479 | common, captcha, ui, репутація |
| **Разом OLX** | **~8 864** | **← ціль деобфускації** |

Решта ~29 000 файлів — чужі open-source бібліотеки (okhttp, retrofit, kotlin, androidx, dagger/hilt, Facebook SDK, Firebase, Play Services, Jackson, BouncyCastle, NewRelic). Їх не деобфусковують — підставляють готові вихідники.

## Рівень обфускації

- **Лише ~17% класів OLX** мають короткі обфусковані імена (`a`, `b`, `c`…).
- **83% уже читабельні**: `DeliveryCategoriesHelper`, `FileCache`, `PhoneNumberHelper`, `SearchParameterFieldConverter`, `ParameterFieldMapFilter`…

**Урок:** обфускація ≠ шифрування. R8 **видаляє** оригінальні імена, не ховає їх — повернути оригінал неможливо, можна лише дати свої. OLX навмисно лишили більшість імен класів (щоб стектрейси в Crashlytics читались), тому велика частина роботи вже зроблена за нас.

## Захисти — майже відсутні

| Захист | Статус |
|---|---|
| SSL cert pinning | ❌ немає (в коді OLX `CertificatePinner` не використовується) |
| Root / emulator detection | ❌ немає в коді OLX |
| Самоперевірка підпису APK | ❌ немає → **перезбірка з іншим ключем пройде чисто** |
| Play Integrity / SafetyNet attestation | ❌ немає атестації пристрою |
| reCAPTCHA (SafetyNet) | ✅ є, але лише анти-бот на логіні/реєстрації (`com/olx/common/captcha`), серверний — на rebuild/install не впливає |
| `networkSecurityConfig` | ❌ немає; `usesCleartextTraffic=true` |

**Висновок:** чистий, «податливий» навчальний таргет. Немає нічого, що завадить циклу decode → edit → rebuild → sign → install.

## Технологічний стек

DI: Dagger/Hilt · Мережа: OkHttp + Retrofit + Jackson · БД: Room · Реактивність: Kotlin Coroutines · Навігація: Jetpack Navigation · Аналітика: Firebase + NewRelic · Реклама: Facebook Audience Network + Google Ads · Карти: Google Maps · A/B: Laquesis (власна платформа OLX).
