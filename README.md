# Storage Inspector — iOS-приложение для просмотра хранилища

Нативное приложение на SwiftUI (iPhone, iOS 16+), сделанное в стиле системного
экрана «iPhone Storage» и Feather: тёмная тема, крупные скруглённые карточки,
сегментированная полоса занятого места, список приложений с размерами, экран
деталей приложения с кнопками **View Files / Offload App / Delete App** и
плавающий капсульный таб-бар с двумя вкладками: **Storage** и **Settings**.

## Что действительно измеряется, а что демо

| Данные | Источник | Реально? |
|---|---|---|
| Объём устройства, занято, свободно | `volumeTotalCapacityKey` / `volumeAvailableCapacityForImportantUsageKey` | Да |
| Размер самого приложения (bundle) | обход `Bundle.main.bundleURL` | Да |
| Documents & Data приложения | обход контейнера (без `.app`) | Да |
| Файлы, папки и их размеры в «View Files» | `FileManager` + `URLResourceValues` | Да |
| Размеры **других** приложений (Telegram, TikTok, …) | `Models/DemoCatalog.swift` | Нет, демо |

Важное ограничение iOS: приложение работает в песочнице и **не может** узнать,
сколько места занимают другие приложения (даже имея на это разрешения — такого
публичного API нет). Поэтому список приложений — демонстрационный набор данных,
он включается/выключается в Settings. Всё остальное (ёмкость диска, свои размеры,
файловый браузер) считается по-настоящему.

## Экраны

1. **Storage**
   - крупный заголовок, карточка «iPhone Storage» с полосой: Applications / Media / System Data / Available;
   - карточка «This app» с реальным размером и кнопкой **View Files**;
   - блок «Applications» с сортировкой `Size ⇅` / `Name` и счётчиком;
   - список приложений: иконка, название, «Last used: …», размер, шеврон;
   - закреплённое снизу поле поиска «Applications» над таб-баром.
2. **App detail** (как страница Telegram в настройках iOS)
   - `App Size`, `Documents & Data`, `Total`;
   - кнопка **View Files** → файловый браузер песочницы;
   - **Offload App** (превью, помечено текстом) и **Delete App** (удаляет только запись из демо-списка).
3. **File browser**
   - реальный размер папки, количество элементов, путь `~/Documents`;
   - переход по папкам, удаление файлов (долгое нажатие → Delete), кнопка
     «Add Sample Files» для пустой папки.
4. **Settings**
   - карточка поддержки (сердце, три пункта, кнопка **Share App** — системный ShareLink);
   - переключатель демо-данных, выбор единиц (Auto / GB / MB), Refresh, Restore demo list;
   - карточка About: описание, Send Feedback (mailto), версия.

## Структура проекта

```
StorageInspector/
├── StorageInspector.xcodeproj/
│   ├── project.pbxproj                 # проект (Xcode 14+ формат, objectVersion 56)
│   └── xcshareddata/xcschemes/StorageInspector.xcscheme
├── StorageInspector/
│   ├── App/StorageInspectorApp.swift   # @main, создаёт StorageStore
│   ├── App/RootView.swift              # вкладки + плавающий таб-бар
│   ├── Design/Theme.swift              # палитра, cardStyle
│   ├── Design/Components.swift         # ScreenTitle, AppIconView, InfoRow, ActionButton, SearchField
│   ├── Design/StorageBar.swift         # сегментированная полоса, DetailTopBar, EmptyStateCard
│   ├── Models/StorageModels.swift      # AppItem, DeviceCapacity, SandboxEntry, SizeSortMode
│   ├── Models/DemoCatalog.swift        # демо-набор приложений
│   ├── Services/DeviceStorage.swift    # реальная ёмкость диска
│   ├── Services/SandboxFiles.swift     # размеры, обход папок, демо-файлы
│   ├── Services/StorageStore.swift     # ObservableObject-состояние
│   ├── Support/Formatters.swift        # единицы измерения, ключи @AppStorage
│   ├── Features/Storage/*.swift        # Storage, детали, файловый браузер
│   ├── Features/Settings/*.swift       # настройки и About
│   └── Resources/Assets.xcassets       # AppIcon (1024×1024) + AccentColor
├── tools/make-icon.ps1                 # перегенерация иконки (Windows/PowerShell)
├── tools/check-pbxproj.ps1             # проверка project.pbxproj
├── tools/check-swift.ps1               # проверка баланса скобок в Swift-файлах
├── tools/build-ipa.sh                  # сборка .ipa на macOS (для Feather)
├── tools/ExportOptions.plist           # шаблон для xcodebuild -exportArchive
├── .github/workflows/build-ipa.yml     # сборка .ipa в облаке GitHub Actions
└── .gitignore
```

## Как собрать (нужен macOS + Xcode)

Windows не умеет собирать iOS-приложения: `xcodebuild`, iOS SDK и подпись кода
существуют только на macOS. Варианты:

1. **Mac / MacBook** (или macOS в VM на Apple Silicon).
2. **Облако**: GitHub Actions (`runs-on: macos-14`), Codemagic, Bitrise,
   MacinCloud, MacStadium — там `.ipa` собирается на их macOS-раннерах.
3. **Xcode Cloud** (нужна подписка Apple Developer).

### Вариант без Mac: `.ipa` соберёт GitHub Actions

В проекте уже лежит готовый workflow `.github/workflows/build-ipa.yml` — он
собирает **неподписанный** `StorageInspector-unsigned.ipa` на macOS-раннере.

1. Залейте папку `StorageInspector` в репозиторий GitHub. Публичный репозиторий —
   macOS-минуты бесплатны; приватный тратит минуты вашего тарифа
   (~10 минут на сборку).
2. Вкладка **Actions** → **Build unsigned IPA** → **Run workflow**.
   В поле **bundle_id** сразу впишите id, разрешённый вашим профилем (если
   профиль wildcard — оставьте `com.example.storageinspector`).
   Без кнопки то же самое произойдёт при push в `main` / `master`.
3. Через 3–5 минут внизу страницы запуска появится артефакт
   **StorageInspector-unsigned-ipa** — скачайте `.zip` и распакуйте: внутри
   `StorageInspector-unsigned.ipa`.
4. Подписать и установить его можно прямо на iPhone через **Feather**
   (см. следующий пункт) — сертификат нужен именно на этом шаге.

Неподписанный `.ipa` — это нормально и ожидаемо: Feather / Esign / Sideloadly
подписывают его локально вашим сертификатом и профилем.

Workflow специально готовит сборку под Feather:

- подставляет `bundle_id` (`PRODUCT_BUNDLE_IDENTIFIER`) — один и тот же код
  работает под любым App ID;
- генерирует «рыхлые» иконки `AppIcon60x60@2x/@3x` в корне `.app` и прописывает
  `CFBundleIcons` (у неподписанных сборок Feather и домашний экран иначе
  показывают пустую иконку);
- вычищает `_CodeSignature` и `embedded.mobileprovision`, чтобы не осталось
  чужой подписи;
- кладёт всё в `Payload/` и пакует в `.ipa`.

Если доступен любой Mac (хотя бы на час), то же самое — одной командой:

```bash
./tools/build-ipa.sh com.example.storageinspector   # аргумент — bundle id
# → build/ipa/StorageInspector-unsigned.ipa
```

Если файл потерял бит выполнения (Windows/git), запускайте `bash tools/build-ipa.sh`.

### Подпись и установка через Feather (сертификат уже есть)

1. Feather → **Settings → Certificates → Import**: `certificate.p12` + пароль.
2. Там же **Import Provisioning Profile**: файл `.mobileprovision`.
3. App ID в профиле должен совпадать с bundle id приложения либо быть wildcard
   (`TEAMID.*`). Наш bundle id — `com.example.storageinspector`; если профиль
   wildcard, ничего менять не нужно, иначе в Feather при подписи нажмите
   **Change Bundle ID** и впишите id, разрешённый профилем.
4. Feather → **+** → выбрать `StorageInspector-unsigned.ipa` → **Sign** →
   **Install**. Потом на iPhone: Настройки → Основные → VPN и управление
   устройством → «Доверять» сертификату.
5. Ошибки «Unable to Install» / «Invalid Provisioning Profile» почти всегда значат:
   не совпал App ID, в ad-hoc профиле нет UDID этого iPhone, или профиль просрочен.

Бесплатный Apple ID тоже подходит, но подпись живёт 7 дней — Feather умеет
переподписывать автоматически.

### Шаги в Xcode

```bash
# 1. открыть проект
open StorageInspector.xcodeproj
```

2. Выбрать таргет `StorageInspector` → вкладка **Signing & Capabilities**:
   - поставить галочку **Automatically manage signing**;
   - выбрать свой **Team** (бесплатный Apple ID тоже подходит);
   - при необходимости поменять **Bundle Identifier**
     (сейчас `com.example.storageinspector` — его нужно заменить на свой,
     иначе подпись не пройдёт).
3. Подключить iPhone кабелем, выбрать его в списке устройств, нажать **Run (⌘R)**.
   На iPhone: Настройки → Основные → VPN и управление устройством → «Доверять»
   профилю разработчика.
4. Минимальная версия iOS — 16.0, ориентация только портретная, тема тёмная.

### Собрать `.ipa` из терминала

```bash
# архив
xcodebuild -project StorageInspector.xcodeproj \
           -scheme StorageInspector \
           -configuration Release \
           -destination 'generic/platform=iOS' \
           -archivePath build/StorageInspector.xcarchive \
           archive

# экспорт в .ipa (заменить YOUR_TEAM_ID в tools/ExportOptions.plist)
xcodebuild -exportArchive \
           -archivePath build/StorageInspector.xcarchive \
           -exportOptionsPlist tools/ExportOptions.plist \
           -exportPath build/ipa
```

В `build/ipa/` появится `StorageInspector.ipa`. Метод экспорта в
`tools/ExportOptions.plist`: `development` — установка на свои устройства,
`ad-hoc` — на зарегистрированные UDID, `app-store` — App Store / TestFlight.

### Установка `.ipa` без Mac на телефоне

- **Feather** — подпись готовым сертификатом и установка прямо на iPhone
  (`.p12` + `.mobileprovision`), см. раздел выше;
- **AltStore / SideStore** — установка через бесплатный Apple ID, приложение
  живёт 7 дней и требует обновления подписи;
- **Sideloadly / 3uTools** (Windows) — заливают готовый `.ipa` на iPhone;
- **TestFlight** — если загрузить сборку в App Store Connect (нужен платный
  аккаунт, но 100 внешних тестеров без UDID).

## Что легко поменять

| Что | Где |
|---|---|
| Название на домашнем экране | `project.pbxproj` → `INFOPLIST_KEY_CFBundleDisplayName` |
| Bundle ID | `project.pbxproj` → `PRODUCT_BUNDLE_IDENTIFIER` (в обеих конфигурациях) |
| Акцентный цвет | `Design/Theme.swift` → `Theme.accent` и `Assets.xcassets/AccentColor` |
| Список приложений | `Models/DemoCatalog.swift` |
| Иконка | `powershell -File tools/make-icon.ps1`, затем пересобрать |

Иконка `AppIcon-1024.png` сгенерирована скриптом `tools/make-icon.ps1`
(1024×1024, без альфы) — можно заменить своим файлом с тем же именем.

## Локальные проверки (работают и на Windows)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-pbxproj.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-swift.ps1
```

`check-pbxproj.ps1` проверяет баланс скобок в `project.pbxproj` и то, что все
24-символьные UUID, на которые есть ссылки, объявлены. `check-swift.ps1`
проверяет баланс скобок в каждом `.swift` и отсутствие макроса `#Preview`
(чтобы проект открывался и в Xcode 14, и в Xcode 15+).

## Ограничения, о которых стоит помнить

- Размеры чужих приложений недоступны в принципе (sandbox): показывать их можно
  только как демо-данные или после джейлбрейка приватными API — такое приложение
  не пройдёт App Store.
- `Offload App` / `Delete App` для чужих приложений — только интерфейс: система
  не даёт стороннему приложению удалять другие приложения. Удаление в приложении
  убирает запись из списка.
- «Media / System Data» в карточке — расчётная разбивка остатка
  (`used − applications`), а не системные категории iOS.

