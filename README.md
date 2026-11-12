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
| Размеры **других** приложений (Telegram, TikTok, …) | `LSApplicationProxy` → `staticDiskUsage` / `dynamicDiskUsage` (`Services/InstalledAppsProvider.swift`) | Да, когда iOS отвечает; иначе прочерк |
| Иконки других приложений | иконка установленного приложения (приватный API) → PNG в `Resources/AppIcons` → обложка App Store | Иконки с устройства / свои / магазина |

Публичного API для размеров чужих приложений в iOS нет: приложение работает в
песочнице. Но у `LSApplicationProxy` есть приватные геттеры `staticDiskUsage`
(бандл, то есть «App Size») и `dynamicDiskUsage` (Documents & Data) — ими и
пользуется системный экран «iPhone Storage». Sideload-сборка вызывает их через
Obj-C runtime: если iOS отвечает, в списке настоящие цифры с этого устройства;
если конкретная версия iOS возвращает 0 или геттер убрали — в строке прочерк, а
не выдуманное число. Список приложений — это реально установленные приложения;
демо-набор (`Models/DemoCatalog.swift`) остаётся только запасным вариантом для
сборок, где приватный API уже закрыт. Ёмкость диска, свои размеры и файловый
браузер считаются по-настоящему всегда.

### Иконки приложений в списке

Источники перебирает `Services/AppIconLoader.swift`, побеждает первый найденный — он и
рисуется в плитке (`Design/Components.swift` → `AppIconView`):

1. **Свой PNG в бандле** — `Resources/AppIcons/icon-<bundle-id>.png` или
   `icon-<id строки>.png`. Побеждает всегда: работает без интернета, на любой iOS и в любой
   сборке. Так подкладываются иконки, вырезанные из скриншотов (`tools/make-app-icon.ps1`,
   пример: `-CropX 40 -CropY 300 -CropSize 512`). Папка подключена как folder reference,
   поэтому новый PNG не требует правок в `project.pbxproj`.
2. **Иконка реально установленного приложения** — приватный
   `+[UIImage _applicationIconImageForBundleIdentifier:format:scale:]` поверх
   `LSApplicationWorkspace` (`Services/InstalledAppsProvider.swift`). Пробуется всегда, когда
   iOS ещё отвечает на этот вызов, — и в демо-режиме тоже: если приложение стоит на телефоне,
   плитка показывает именно его иконку с домашнего экрана, без сети.
3. **Обложка из каталога App Store** — один запрос на приложение
   `https://itunes.apple.com/lookup?bundleId=…&country=us` по `bundleID` из
   `DemoCatalog.apps`; берётся `artworkUrl512` (иначе `artworkUrl100`, переписанный на
   `512x512bb`), картинка кладётся в `Library/Caches/AppIcons/` и в следующий раз
   появляется сразу из кэша.
4. **Заглушка** — градиент с SF Symbol, если ничего не нашлось: Apple Photos, сама
   программа, вымышленные строки, офлайн.

Добавить демо-приложение с настоящей иконкой: строка в `DemoCatalog.apps` с полем
`bundleID` — остальное подхватится само. Свой PNG нужен, только если хочется конкретную
картинку (или на iOS, где приватные API уже закрыты).

### Список приложений (приватный API)

`Services/InstalledAppsProvider.swift` через Objective-C runtime достаёт
`+[LSApplicationWorkspace defaultWorkspace]` → `-allInstalledApplications` (плюс
`-installedApplications` и `-allApplications`, ответы сливаются) и превращает каждый
`LSApplicationProxy` в строку списка: имя, версия, вендор, bundle id, иконка с домашнего
экрана и размеры. Это **основной** список приложения — демо-набор показывается только там,
где приватный API уже закрыт.

Второй источник — обход папок с бандлами (`/var/containers/Bundle/Application/*/*.app`,
`/Applications`, rootless `/var/jb/...`): он добирает приложения, которые база
LaunchServices не отдаёт (скрытые установки TrollStore), и даёт измеренный размер там, где
iOS отказывается отвечать. В обычной песочнице эти папки недоступны, обход просто ничего не
находит.

- это **приватный API**: работает только в сборке, подписанной своим сертификатом
  (sideload), и Apple может закрыть его в любой версии iOS;
- размеры берутся из `-staticDiskUsage` / `-dynamicDiskUsage` того же прокси, а если геттеры
  молчат — из обхода папки бандла. Когда iOS отвечает, цифры настоящие; когда не отвечает
  ничего — прочерк «—», а не выдуманное число, и при сортировке по размеру такие строки уходят
  в конец;
- фильтруется только одно: скрытые записи Apple (`applicationType == Hidden`). Они снова
  попадают в список, если включить в Settings тумблер **Show hidden apps** — тогда видны и
  системные службы без иконки на домашнем экране;
- ни один класс и селектор не линкуется при компиляции: всё ищется через runtime и каждое
  обращение проверяется, поэтому если Apple уберёт `LSApplicationWorkspace` или приватный
  метод `UIImage`, приложение останется на демо-списке вместо падения;
- на экране Storage есть кнопка пересканирования (↻ рядом с заголовком «Installed»), а в
  Settings — строка «Installed apps» со счётчиком и кнопкой **Rescan**.

## Экраны

1. **Storage**
   - крупный заголовок, карточка «iPhone Storage» с полосой: Applications / Media / System Data / Available;
   - карточка «This app» с реальным размером и кнопкой **View Files**;
   - блок «Installed» со счётчиком, сортировкой `Size ⇅` / `Name` и кнопкой пересканирования ↻;
   - список реально установленных приложений: иконка, название, вендор, размер (или «—»), шеврон;
   - закреплённое снизу поле поиска «Applications» над таб-баром: фильтрует по названию,
     вендору и bundle id, круглый «×» справа очищает запрос и убирает клавиатуру.
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
   - строка **Installed apps** со счётчиком и кнопкой **Rescan**, тумблер **Show hidden apps**
     (скрытые системные службы Apple), выбор единиц (Auto / GB / MB),
     Refresh measurements; демо-набор и Restore demo list видны только там, где приватный API
     недоступен;
   - карточка **App Icon** — четыре цвета иконки приложения: **Orange** (по умолчанию),
     Indigo, Graphite, Crimson; переключение через `UIApplication.setAlternateIconName`;
   - карточка About: описание, Send Feedback (mailto), версия.

## Смена иконки приложения (Settings → App Icon)

В приложении четыре варианта иконки: **Orange** (основная, по умолчанию), **Indigo**,
**Graphite** и **Crimson**. Переключение — карточка «App Icon» на экране Settings.
iOS после смены показывает системный алерт «Вы изменили значок…» — это нормально,
обойти его нельзя.

Как это устроено:

1. `StorageInspector/Resources/AppIconVariants/icon-*.png` — исходники 1024×1024
   (оранжевый дополнительно лежит в `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
   и является основной иконкой бандла).
2. `tools/build-ipa.sh` и GitHub-воркфлоу при упаковке:
   - уменьшают каждый вариант до `Icon<Name>@2x.png` (120×120) и `Icon<Name>@3x.png`
     (180×180) и кладут их в корень `.app` — SpringBoard и Feather берут иконки оттуда;
   - добавляют в `Info.plist` словарь `CFBundleAlternateIcons` **внутри** `CFBundleIcons`
     (`IconIndigo` / `IconGraphite` / `IconCrimson` → `CFBundleIconFiles`); на верхнем уровне
     plist iOS его игнорирует, и `supportsAlternateIcons` остаётся `false`. Имена ключей — это
     ровно те строки, которые `AppIconStyle.alternateName` передаёт в `setAlternateIconName(_:)`.
   Без шага 2 `UIApplication.supportsAlternateIcons == false`, и карточка App Icon честно
   пишет, что выбор недоступен, вместо тихого отказа.
3. `Services/AppIconManager.swift` вызывает `UIApplication.setAlternateIconName(_:)`
   (`nil` возвращает оранжевую иконку), `Models/AppIconStyle.swift` держит соответствие
   «цвет ↔ имя альтернативной иконки ↔ градиент для превью в настройках».

Своя графика: положите PNG 1024×1024 (без альфа-канала) в
`StorageInspector/Resources/AppIconVariants/` с теми же именами
(`icon-orange.png`, `icon-indigo.png`, `icon-graphite.png`, `icon-crimson.png`) и
запустите сборку заново. Плейсхолдеры рисует `tools/make-icon.ps1`.

Папка подключена в проект как folder reference, поэтому те же файлы попадают в бандл:
карточка **App Icon** рисует в плитках именно их (`AppIconArtwork` в
`Features/Settings/AppIconCard.swift`), а не нарисованную копию. Заменили PNG — поменялись
и иконка на домашнем экране, и превью в настройках.

Важно про исходники: нужен «полный» квадрат без внешних белых полей и без заранее
скруглённых углов — маску (squircle) iOS накладывает сам. Если взять картинку с
белыми полями по краям, на домашнем экране вокруг иконки останется белая рамка.

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
│   ├── Models/AppIconStyle.swift       # цвета иконки: orange (по умолчанию), indigo, graphite, crimson
│   ├── Services/DeviceStorage.swift    # реальная ёмкость диска
│   ├── Services/SandboxFiles.swift     # размеры, обход папок, демо-файлы
│   ├── Services/StorageStore.swift     # ObservableObject-состояние
│   ├── Services/AppIconManager.swift   # обёртка над setAlternateIconName
│   ├── Services/AppIconLoader.swift     # иконки строк: PNG из бандла → иконка iOS → обложка App Store
│   ├── Services/InstalledAppsProvider.swift # приватный LSApplicationWorkspace: список и иконки
│   ├── Support/Formatters.swift        # единицы измерения, ключи @AppStorage
│   ├── Features/Storage/*.swift        # Storage, детали, файловый браузер
│   ├── Features/Settings/*.swift       # настройки и About
│   ├── Resources/Assets.xcassets       # AppIcon (1024×1024, оранжевая) + AccentColor
│   ├── Resources/AppIconVariants/      # icon-orange / icon-indigo / icon-graphite / icon-crimson.png
│   └── Resources/AppIcons/             # icon-<bundle-id>.png / icon-<id>.png — свои иконки строк (folder reference)
├── tools/make-icon.ps1                 # перегенерация иконки (Windows/PowerShell)
├── tools/make-app-icon.ps1             # вырезать иконку приложения из скриншота в Resources/AppIcons
├── tools/check-pbxproj.ps1             # проверка project.pbxproj
├── tools/check-swift.ps1               # проверка баланса скобок в Swift-файлах
├── tools/check-eol.ps1                 # проверка переводов строк (CRLF ломает bash на macOS)
├── tools/bump-version.ps1              # +1 к номеру сборки (и смена версии) одной командой
├── tools/build-ipa.sh                  # сборка .ipa на macOS (для Feather)
├── tools/ExportOptions.plist           # шаблон для xcodebuild -exportArchive
├── .github/workflows/build-ipa.yml     # сборка .ipa в облаке GitHub Actions
└── .gitignore
```

## Как собрать (нужен macOS + Xcode)

Windows не умеет собирать iOS-приложения: `xcodebuild`, iOS SDK и подпись кода
существуют только на macOS. Варианты:

1. **Mac / MacBook** (или macOS в VM на Apple Silicon).
2. **Облако**: GitHub Actions (`runs-on: macos-latest`), Codemagic, Bitrise,
   MacinCloud, MacStadium — там `.ipa` собирается на их macOS-раннерах.
3. **Xcode Cloud** (нужна подписка Apple Developer).

### Новая версия: что поменять перед сборкой

Номер версии берётся из build settings, а не из отдельного `Info.plist`
(Xcode генерирует его сам: `GENERATE_INFOPLIST_FILE = YES`):

- `MARKETING_VERSION` — то, что видно в About и в Feather (`1.1`);
- `CURRENT_PROJECT_VERSION` — номер сборки, целое число (`2`, `3`, …).

Обе строки лежат в `StorageInspector.xcodeproj/project.pbxproj` (по два раза —
Debug и Release) либо меняются в Xcode: таргет → **General** → *Identity* →
**Version** / **Build**. `Formatters.version()` в About читает ровно
`CFBundleShortVersionString`, то есть `MARKETING_VERSION`.

Руками файл править не нужно — для этого есть `tools/bump-version.ps1`
(PowerShell, работает на Windows и на macOS):

```powershell
# только номер сборки +1, версия остаётся 1.1  → 1.1 (4) становится 1.1 (5)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\bump-version.ps1

# новая версия и сборка +1 → 1.2 (5)
powershell -NoProfile -ExecutionPolicy Bypass -File tools\bump-version.ps1 -Version 1.2

# ровно 1.2 (1) — когда номер сборки нужно начать заново
powershell -NoProfile -ExecutionPolicy Bypass -File tools\bump-version.ps1 -Version 1.2 -Build 1

# посмотреть, что изменится, ничего не записывая
powershell -NoProfile -ExecutionPolicy Bypass -File tools\bump-version.ps1 -DryRun
```

Скрипт меняет обе копии настроек (Debug и Release) синхронно, пишет файл без
BOM и с LF-переводами строк и в конце сам запускает `check-pbxproj.ps1` и
`check-eol.ps1` (`-SkipChecks`, если не нужно). Если одной из настроек в проекте
не окажется ровно два раза, он ничего не запишет и завершится с кодом 1.

### Выпуск новой версии: 5 шагов

1. **Поднять номер** — `tools\bump-version.ps1` (см. выше). Без этого Feather
   покажет тот же `1.1 (4)`, и невозможно понять, встала новая сборка или старая.
2. **Проверить проект** — те же три скрипта, что гоняет Release-чеклист:
   `check-swift.ps1`, `check-pbxproj.ps1`, `check-eol.ps1` (последний — с `-Fix`,
   если правили файлы на Windows).
3. **Закоммитить и запушить в `main`.** Workflow `Build unsigned IPA` собирает
   `.ipa` и на push, так что отдельная кнопка не обязательна.
4. **Забрать артефакт** — **Actions → Build unsigned IPA** → последний запуск →
   внизу **Artifacts → StorageInspector-unsigned-ipa** (`.zip`), распаковать.
   Если запуск красный из-за «The job was not acquired by Runner of type hosted»,
   перезапустить с **Run workflow** и полем **runner** = `macos-15-intel`.
5. **Установить поверх старой копии** — Feather → **+** → выбрать
   `StorageInspector-unsigned.ipa` → **Sign** → **Install**. Данные и настройки
   (`@AppStorage`) сохраняются, версия в About и в Feather обновится.

На Mac те же шаги 1–2, а вместо 3–4 — `bash tools/build-ipa.sh <bundle-id>`,
готовый `.ipa` появится в `build/ipa/`. В артефактах всегда лежит свежий
`StorageInspector-unsigned.ipa` — имя файла не меняется, отличается версия
внутри, и Feather при установке поверх старой копии показывает новый номер.

### Вариант без Mac: `.ipa` соберёт GitHub Actions

В проекте уже лежит готовый workflow `.github/workflows/build-ipa.yml` — он
собирает **неподписанный** `StorageInspector-unsigned.ipa` на macOS-раннере.

1. Залейте папку `StorageInspector` в репозиторий GitHub. Публичный репозиторий —
   macOS-минуты бесплатны; приватный тратит минуты вашего тарифа
   (~10 минут на сборку).
2. Вкладка **Actions** → **Build unsigned IPA** → **Run workflow**.
   В поле **bundle_id** сразу впишите id, разрешённый вашим профилем (если
   профиль wildcard — оставьте `com.example.storageinspector`).
   Поле **runner** оставьте пустым (тогда берётся `macos-latest` или переменная
   `MACOS_RUNNER`), либо впишите `macos-15-intel`, если arm64-раннеры заняты.
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
- добавляет альтернативные иконки `IconIndigo@2x/@3x`, `IconGraphite@2x/@3x`,
  `IconCrimson@2x/@3x` и `CFBundleAlternateIcons` — без этого шага карточка
  **App Icon** в настройках будет неактивна;
- вычищает `_CodeSignature` и `embedded.mobileprovision`, чтобы не осталось
  чужой подписи;
- кладёт всё в `Payload/` и пакует в `.ipa`.

#### Если запуск упал с «The job was not acquired by Runner»

Это не ошибка проекта и не ошибка YAML: GitHub не выдал macOS-машину
(в аннотациях видно `Internal server error` с correlation ID и notice
«Due to capacity constraints, jobs targeting macos arm64 runners may experience
longer queue times»). Шаги сборки при этом даже не начинались.

- **важно:** `Re-run jobs` перезапускает **тот же коммит и ту же версию
  workflow**. Если поле `runner` появилось уже после упавшего запуска,
  перезапуск его не увидит — сначала закоммитьте/запушьте workflow в `main`;
- после пуша нажмите **Run workflow** и впишите в поле **runner**
  `macos-15-intel`: у Intel-образов отдельный пул машин, он часто свободен,
  когда arm64-очередь забита;
- либо задайте переменную репозитория **Settings → Secrets and variables →
  Actions → Variables → `MACOS_RUNNER = macos-15-intel`** — её подхватывают и
  запуски по push (при ручном запуске поле **runner** оставляйте пустым);
- если не проходит и это, проверьте **Settings → Billing** (не исчерпаны ли
  минуты macOS: они списываются с коэффициентом ×10) и попробуйте запустить
  позже — очередь на GitHub-hosted macOS сильно зависит от времени суток.

Значение в workflow: `runs-on: ${{ github.event.inputs.runner || vars.MACOS_RUNNER || 'macos-latest' }}`.
Плюс включён `concurrency` (`build-ipa-<ref>`, `cancel-in-progress: true`),
чтобы серия пушей не занимала очередь лишними запусками.

#### Если GitHub так и не выдаёт macOS-раннер

Бывает, что очередь не рассасывается ни на `macos-latest`, ни на
`macos-15-intel`, хотя в **Settings → Billing → Usage → Actions** ноль
израсходованных минут, а `githubstatus.com` зелёный. Тогда `.ipa` собирается на
**Codemagic** — те же шаги, тот же скрипт `tools/build-ipa.sh`, 500 бесплатных
macOS-минут в месяц:

1. <https://codemagic.io> → **Sign up with GitHub** → **Add application** →
   выбрать репозиторий `Storage-Inspector-iOS`: Codemagic сам прочитает
   `codemagic.yaml` из корня.
2. **Start new build** → workflow **ios-unsigned** → **Start new build**.
3. Через 5–10 минут в **Artifacts** появится `StorageInspector-unsigned.ipa` —
   дальше Feather, как обычно.

Bundle id задаётся переменной `BUNDLE_ID` в `codemagic.yaml` (или в
**Environment variables** проекта). Там же третий шаг печатает
`CFBundleAlternateIcons` и список иконок из собранного `.app` — сразу видно,
попали ли варианты App Icon.

**Если шаг «Build unsigned IPA» падает за 3–5 секунд** — это не компилятор, а переводы
строк: файлы правятся на Windows, и `tools/build-ipa.sh` приезжает в репозиторий с CRLF,
на чём `bash` умирает на первой же строке (`set: pipefail\r: invalid option name`).
Поэтому первым шагом и в `codemagic.yaml`, и в GitHub Actions идёт нормализация
`\r` во всех текстовых файлах. Вручную это
`perl -pi -e 's/\r\n/\n/g' tools/build-ipa.sh`.

Диагностика «а выдают ли вообще hosted-раннеры» — `.github/workflows/runner-probe.yml`
(запускается вручную, проверяет `ubuntu-latest`): зелёный probe = проблема только
в macOS-пуле, красный = аккаунту не выделяются никакие hosted-раннеры
(тогда `support.github.com` с correlation ID из аннотаций).

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
| Версия / номер сборки | `tools\bump-version.ps1` (`-Version 1.2`, `-Build N`), либо `project.pbxproj` → `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` |
| Акцентный цвет | `Design/Theme.swift` → `Theme.accent` и `Assets.xcassets/AccentColor` |
| Список приложений | `Services/InstalledAppsProvider.swift` (реальные приложения), демо-набор — `Models/DemoCatalog.swift` |
| Иконка (основная и 4 цвета) | `StorageInspector/Resources/AppIconVariants/` + `powershell -File tools/make-icon.ps1` |

Иконки сгенерированы скриптом `tools/make-icon.ps1` (1024×1024, без альфы):
`AppIcon-1024.png` = оранжевая основная, `AppIconVariants/icon-*.png` = четыре цвета
для экрана Settings. Любой файл можно заменить своим с тем же именем.

## Локальные проверки (работают и на Windows)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-pbxproj.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-swift.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\check-eol.ps1
```

`check-pbxproj.ps1` проверяет баланс скобок в `project.pbxproj` и то, что все
24-символьные UUID, на которые есть ссылки, объявлены. `check-swift.ps1`
проверяет баланс скобок в каждом `.swift` и отсутствие макроса `#Preview`
(чтобы проект открывался и в Xcode 14, и в Xcode 15+). `check-eol.ps1` падает,
если в текстовом файле остались CRLF (флаг `-Fix` переводит их в LF): именно
CRLF в `tools/build-ipa.sh` завалил сборку Codemagic за 4 секунды, не дойдя до
компилятора.

## Ограничения, о которых стоит помнить

- Размеры чужих приложений публичного API не имеют (sandbox). Sideload-сборка читает
  их приватными геттерами `staticDiskUsage` / `dynamicDiskUsage`; там, где iOS отвечает
  0 или геттера уже нет, показывается прочерк. В App Store такое приложение не пройдёт.
- `Offload App` / `Delete App` для чужих приложений — только интерфейс: система
  не даёт стороннему приложению удалять другие приложения. Удаление в приложении
  убирает запись из списка.
- «Media / System Data» в карточке — расчётная разбивка остатка
  (`used − applications`), а не системные категории iOS.

