# Реверс OLX.ua — навчальний розбір

Повний навчальний реверс-інжиніринг OLX.ua v5.20.5 (`ua.slando`): від APK до читабельного коду і назад до робочого APK. Матеріал побудований як курс — по фазах, кожна з практичним результатом.

> **Призначення:** навчання реверс-інжинірингу Android. Весь розбір read-only; перезбірка підписується власним ключем і призначена лише для локального вивчення на своєму пристрої.

## Фази

| # | Документ | Що всередині |
|---|---|---|
| 1 | [01-recon.md](01-recon.md) | Ідентифікація, масштаб коду, рівень обфускації, аналіз захистів |
| 2 | [02-two-trees.md](02-two-trees.md) | smali vs java: навіщо два дерева, як читати smali, підстановка бібліотек |
| 3 | [03-deobfuscation.md](03-deobfuscation.md) | Відновлення імен з Kotlin-метаданих, мапи, ручна техніка |
| 4 | [04-roundtrip.md](04-roundtrip.md) | rebuild → sign → install, доказ правок, v1 vs v2/v3 |
| 5 | [05-architecture.md](05-architecture.md) | Карта: MVVM, DI-граф, мережа, фічі, де що шукати |
| 6 | [06-deep-dive-feature-flags.md](06-deep-dive-feature-flags.md) | Наскрізний розбір фічі: StartupConfig + Laquesis, від сервера до smali |
| + | [smali-cheatsheet.md](smali-cheatsheet.md) | Довідник smali для правок |

## Артефакти

| Файл | Що це |
|---|---|
| [rebuild.sh](rebuild.sh) | скрипт повного циклу збірки |
| [mappings/olx-classes-full.txt](mappings/olx-classes-full.txt) | 4 285 OLX-класів: обфускована → відновлена назва (редагований) |
| [mappings/olx-classes-recovered.txt](mappings/olx-classes-recovered.txt) | 1 737 класів з «гарними» іменами |

Робочі дерева (великі, поза git, у `scratchpad/apk_work/`):
- `decoded/` — smali + ресурси (для `apktool b`)
- `src/` — читабельна Java (jadx)
- `src_deobf/` — Java з відновленими іменами
- `olx-names.jobf` — повна мапа імен (88k записів)
- `*.apk` — перезібрані/підписані артефакти

## Ключові висновки

1. **Обфускація ≠ шифрування.** R8 видаляє імена, не ховає. Оригіналу не повернути — даєш свої.
2. **Таргет майже без захисту:** немає pinning, root-детекту, самоперевірки підпису → round-trip тривіальний.
3. **56% класів відновлено автоматично** з Kotlin-метаданих; усі іменовані класи OLX мають назви, решта — анонімні лямбди.
4. **Реальний код OLX — ~8 900 класів** із 37 800; решта — відомі бібліотеки.
5. **Підпис — природна межа:** своя збірка ставиться лише окремо, не підміняє магазинну.

## Інструменти

apktool 2.9.3 · jadx 1.5.0 · keytool/jarsigner (JDK) · (локально для v2: zipalign + apksigner з Android SDK)

## Відтворити з нуля

```bash
# декод
java -jar apktool.jar d olx.apk -o decoded
java -cp jadx-all.jar jadx.cli.JadxCLI olx.apk -d src

# деобфускація
java -cp jadx-all.jar jadx.cli.JadxCLI olx.apk -d src_deobf \
  --deobf --deobf-use-sourcename --deobf-cfg-file olx-names.jobf

# збірка назад
./rebuild.sh
```
