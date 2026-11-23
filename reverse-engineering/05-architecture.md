# Фаза 5 — Карта архітектури OLX.ua

Мапа, щоб орієнтуватись у коді й швидко знаходити потрібну фічу.

## Загальна картина

Класичний модульний **MVVM + Clean Architecture** на Kotlin:

```
UI (Activity/Fragment)  →  ViewModel  →  UseCase  →  Repository  →  ApiService (Retrofit)
         ↑                     ↑            ↑            ↑
      databinding         LiveData/Flow   бізнес-     мережа + Room-кеш
                                          логіка
```

Числа по коду OLX:

| Шар | К-сть | Шар | К-сть |
|---|---|---|---|
| Activity | 126 | ViewModel | 68 |
| Fragment | 182 | UseCase | 111 |
| Retrofit API | 21 | Koin-модулі | 28 |

## Точка входу та startup

```
StartupActivity (LAUNCHER, pl.tablica2.app.startup)
   │
   ├─ TablicaApplication.onCreate()  — ініціалізація Koin, Firebase, NewRelic
   │
   ├─ GET application/startup-configuration
   │     → StartupConfigResponse { Data, Features, Versions, User }
   │     → ConfigurationPreference (кеш конфіга)
   │     → AppUpdateConfiguration (примусове оновлення)
   │
   └─ proceedWithMainActivity()  — корутина, перехід на головний екран
```

`StartupConfigResponse` — серверний конфіг, що вмикає/вимикає фічі (feature flags) на старті. Ключовий клас для розуміння, що саме активне.

## Мережевий шар

- **Стек:** OkHttp + Retrofit + Jackson/kotlinx.serialization.
- **DI:** `NetworkModuleKt` (будує OkHttpClient, інтерсептори, Retrofit).
- **Автентифікація:** `OAuthService` + `oauth`-пакет (токени, refresh).
- **Легасі-API:** `I2Service` / `i2api`, `RestApiService` — історичні шари OLX.
- **SSL pinning відсутній** → трафік можна дивитись через проксі (Charles/mitmproxy) без обходу.

### API-сервіси за фічами

| Сервіс | Домен |
|---|---|
| `RestApiService`, `I2Service` | ядро (оголошення, користувач) |
| `AdsRestService`, `MyAdsRestService` | оголошення, мої оголошення |
| `ChatApiService`, `NewChatService` | чат (+ websocket) |
| `ProfileApiService`, `MyOlxApiService` | профіль, «Мій OLX» |
| `UaPayService`, `DeliveryService` | OLX Доставка / UA Pay (safedeal) |
| `MonetizationApi`, `ShopsService` | платні послуги, магазини |
| `KhonorService` | репутація продавця (khonor) |
| `SettingsApiService`, `SettingsI2Service` | налаштування |
| `OAuthService` | автентифікація |
| `PushApi` | push-сповіщення |
| `LaquesisApi` | A/B-тести |
| `CMTService` | категорії/метадані |

## Інфраструктура (хости)

| Хост | Призначення |
|---|---|
| `www.olx.ua` | основний бекенд |
| `*.olxcdn.com` (categories, khonor, laquesis, ninja) | CDN: категорії, репутація, A/B, конфіги |
| `discovery-autocomplete.eu-sharedservices.olxcdn.com` | автодоповнення пошуку |
| `baxter-cdn.*.olxssa.com` | Baxter — рекламна платформа |
| `tracking.olx-st.com` | трекінг подій |

## DI-граф (Koin, 28 модулів)

```
MainModuleKt (кореневий)
├── NetworkModuleKt        мережа, Retrofit, OkHttp
├── DataSourceModuleKt     джерела даних, Room
├── UseCaseModuleKt        бізнес-логіка
├── ViewModelModuleKt      ViewModels
├── UtilModuleKt           утиліти
│
├── Фічі:
│   ├── LoginModuleKt / (oauth)       автентифікація
│   ├── HomeModuleKt                  головний екран
│   ├── SearchModuleKt                пошук
│   ├── AdsModuleKt / MyAdsModuleKt   оголошення
│   ├── ChatModuleKt                  чат
│   ├── PostingModuleKt               подача оголошення
│   ├── MyOlxModuleKt                 кабінет
│   ├── MonetizationModuleKt          платні послуги
│   ├── ShopsModuleKt                 магазини
│   ├── LocationModuleKt              локація/карти
│   ├── PushModuleKt / (fcm)          сповіщення
│   ├── SettingsModuleKt              налаштування
│   ├── CMTModuleKt                   категорії
│   │
│   └── Репутація продавця:
│       ├── SellerReputationModuleKt
│       ├── KhonorModuleKt            бекенд khonor
│       ├── RatingModuleKt            оцінки
│       ├── FeedbackModuleKt          відгуки
│       ├── BadgesModuleKt            бейджі
│       └── CollectPaymentDeliveryModuleKt
│
└── Інше: FeedTheDogModuleKt (anti-idle), FundsExplanationModuleKt
```

## Пакети-фічі `pl.tablica2.*`

```
app/           application/   config/        data/
delivery/      domain/        features/      filtering/
fragments/     helpers/       logic/         profile/
notifications/ routing/       sellerreputation/  settings/
services/      tracker/ tracker2/  widgets/   fcm/  abtests/  bugtracker/
```

Плюс окремі модулі:
- `pl.olx.*` — adview (екран оголошення), search, location, myolx, push.
- `com.olxgroup.*` — chat (повний стек з websocket), laquesis (A/B-платформа), monetization, shops.
- `com.olx.*` — common (спільне ядро), captcha, ui (дизайн-система), sellerreputation.

## Фічі A/B: Laquesis

`com.olxgroup.laquesis` — власна платформа експериментів OLX. Керує тим, які фічі увімкнені для конкретного користувача (разом зі `StartupConfigResponse.Features`). Якщо вивчаєш якусь поведінку, що «то є, то нема» — дивись сюди і на feature flags.

## Куди дивитись для конкретної фічі

| Цікавить | Починай з |
|---|---|
| Логін/токени | `pl.tablica2.profile.login`, `oauth`, `OAuthService` |
| Чат | `com.olxgroup.chat` (+ `websocket/`) |
| Пошук | `pl.olx.data.search`, `SearchModuleKt` |
| Екран оголошення | `pl.olx.adview` |
| Подача оголошення | `pl.tablica2.di.PostingModuleKt`, `posting` |
| Платежі/доставка | `pl.tablica2.features.safedeal`, `UaPayService` |
| Репутація | `com.olx.sellerreputation`, `KhonorService` |
| Feature flags | `StartupConfigResponse`, `com.olxgroup.laquesis` |
| Captcha | `com.olx.common.captcha` |
