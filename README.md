<div align="center">

# 💰 MoneyCheck

### AI 영수증 인식(OCR) 기반 스마트 가계부 iOS 앱

**"사진 한 장이면 끝" — 영수증을 찍기만 하면 지출이 자동으로 기록됩니다.**

[![Platform](https://img.shields.io/badge/Platform-iOS%2026.2%2B-000000?style=for-the-badge&logo=apple&logoColor=white)](#-getting-started-설치-및-실행-가이드)
[![Swift](https://img.shields.io/badge/Swift-5.0-F05138?style=for-the-badge&logo=swift&logoColor=white)](#-사용-기술-및-라이브러리-tech-stack--dependencies)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-Declarative%20UI-blue?style=for-the-badge&logo=swift&logoColor=white)](#-사용-기술-및-라이브러리-tech-stack--dependencies)
[![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-orange?style=for-the-badge)](#-사용-기술-및-라이브러리-tech-stack--dependencies)
[![Xcode](https://img.shields.io/badge/Xcode-16-1575F9?style=for-the-badge&logo=xcode&logoColor=white)](#-getting-started-설치-및-실행-가이드)
[![License](https://img.shields.io/badge/License-Private-lightgrey?style=for-the-badge)](#)

</div>

---

## 📌 목차

1. [프로젝트 심층 소개 (Overview)](#-프로젝트-심층-소개-overview)
2. [사용 기술 및 라이브러리 (Tech Stack & Dependencies)](#-사용-기술-및-라이브러리-tech-stack--dependencies)
3. [핵심 기능 및 상세 로직 (Key Features & Logic)](#-핵심-기능-및-상세-로직-key-features--logic)
4. [프로젝트 구조 및 파일 설명 (Directory Structure)](#-프로젝트-구조-및-파일-설명-directory-structure)
5. [Getting Started (설치 및 실행 가이드)](#-getting-started-설치-및-실행-가이드)
6. [Troubleshooting & Dev Log (트러블슈팅 및 개발 일지)](#️-troubleshooting--dev-log-트러블슈팅-및-개발-일지)

---

## 🔍 프로젝트 심층 소개 (Overview)

### 어떤 문제를 해결하고 싶었나?

가계부 앱의 가장 큰 진입 장벽은 **"입력의 번거로움"** 입니다. 카드를 긁을 때마다, 혹은 현금 영수증을 받을 때마다 앱을 열어 날짜·금액·카테고리를 일일이 타이핑해야 한다면 3일을 못 넘기고 기록을 포기하게 됩니다.

**MoneyCheck**는 이 문제를 두 가지 축으로 해결합니다.

- **입력 마찰 최소화**: Apple `Vision` 프레임워크 기반 OCR로 영수증/카드 결제 내역 사진을 촬영·선택하기만 하면 금액·날짜·가맹점명·수입/지출 여부·카테고리까지 **자동으로 파싱**하여 후보 목록으로 제시합니다. 사용자는 체크박스로 확인만 하면 됩니다.
- **월급 기준 예산 관리**: 대한민국 직장인의 현실적인 소비 패턴(매월 1일이 아니라 "월급날"을 기준으로 한 달 예산을 관리)을 반영해, `salaryDay`(월급날)를 기준으로 한 **정산 주기(Budget Period)** 를 계산하고 그 기간 동안의 예산 소진율을 추적합니다.

### 전체 작동 흐름 (Architecture Flow) — 시나리오로 보기

**시나리오: 사용자가 카페에서 결제 후 영수증 사진으로 지출을 기록하는 과정**

```
[1] 앱 실행
     └─ MoneyCheckApp.init()
         ├─ SwiftData ModelContainer 생성 (Transaction, MonthlyConfig, UserSettings, CategoryDefinition, SavingsAccount)
         ├─ BudgetViewModel(modelContext:) 초기화
         │    ├─ fetchData() → 저장된 트랜잭션/설정/월간 설정 불러오기
         │    └─ processRecurringTransactions() → 반복 지출 자동 복제 체크
         └─ ThemeManager 초기화 (테마 상태를 앱 전역에 주입)

[2] MainView 진입
     └─ DashboardView (이번 달 수입/지출/월간·연간 합계)
     └─ CustomCalendarView (달력에 일별 수입/지출 요약 뱃지 표시)
     └─ 하단 플로팅 버튼: [🧾 영수증 OCR] [✏️ 수동 입력]

[3] 사용자가 "영수증 OCR" 버튼 탭 → OCRImportView present
     └─ PhotosPicker로 영수증 사진 최대 5장 선택
          └─ 사진마다 OCRService.recognize(data:)
               ├─ CGImageSourceCreateWithData 로 이미지 디코딩
               └─ VNRecognizeTextRequest (Vision) 비동기 실행
                    → withCheckedThrowingContinuation 으로 콜백을 async/await 로 브릿징
                    → recognitionLanguages = ["ko-KR", "en-US"], accurate 레벨
          └─ 인식된 텍스트 라인 배열([OCRLine]: 텍스트 + 신뢰도 + boundingBox)을
             OCRParserService.parse(lines:) 에 전달
               ├─ Y좌표(boundingBox.midY) 기준으로 같은 "행(Row)"으로 그룹핑
               ├─ 세로로 분리된 금액-레이블 행을 병합 (mergeVerticalAmountRows)
               ├─ 정규식으로 숫자 후보(Candidate) 추출 (₩, 콤마, "원" 포함/미포함 모두 대응)
               ├─ 각 후보에 점수(score) 부여
               │    → 우측 정렬 여부 + 키워드("합계","결제금액" 등) 포함 여부 +
               │      통화 기호 여부 + 부호(+/-) 여부를 종합해 "총 결제 금액"일 확률이
               │      가장 높은 후보를 채택
               ├─ 텍스트 내 "입금/월급/보너스" 등의 키워드로 수입/지출(Type) 판별
               ├─ 날짜 패턴(yyyy.MM.dd 등) 정규식 매칭으로 거래일 추출
               └─ 가맹점명 후보 텍스트 필터링(시간/퍼센트/LTE 표시 등 노이즈 제외)
     └─ 파싱 결과가 OCRItem 리스트로 화면에 표시 → 사용자가 체크/수정
     └─ "N개 내역 선택하여 추가하기" 탭
          └─ BudgetViewModel.addTransaction() 반복 호출
               ├─ SwiftData Transaction 모델 insert
               ├─ modelContext.save()
               ├─ fetchData() 로 최신 상태 재조회
               └─ processRecurringTransactions() 로 반복 지출 파이프라인 재확인

[4] MainView 로 복귀
     └─ 캘린더의 해당 날짜 셀에 지출 합계가 즉시 반영 (SwiftData 관찰 기반 자동 갱신)
     └─ DashboardView 의 이번 달 지출 총액 갱신
     └─ SettingsHubView 의 "이번 달 재정 목표" 예산 대비 소진율 계산에도 반영
          (Date.budgetPeriod(for:salaryDayNumber:) 로 월급날 기준 정산 구간을 계산)
```

이 흐름에서 알 수 있듯, MoneyCheck는 **"사진 → Vision OCR → 커스텀 파서(휴리스틱 스코어링) → SwiftData 영속화 → 반응형 UI 갱신"** 이라는 하나의 파이프라인으로 연결되어 있으며, `@Observable` 매크로 기반의 `BudgetViewModel` 이 SwiftUI 뷰 트리 전체에 단일 진실 공급원(Single Source of Truth) 역할을 합니다.

---

## 🧩 사용 기술 및 라이브러리 (Tech Stack & Dependencies)

이 프로젝트는 **서드파티 패키지 의존성이 전혀 없는(Zero 3rd-party dependency)** 순정 Apple 프레임워크 기반 네이티브 iOS 앱입니다. (`Package.swift`, `Podfile`, `requirements.txt` 등 외부 의존성 관리 파일 없음 — 소스 코드의 `import` 구문을 전수 분석한 결과입니다.)

### 언어 & 아키텍처

| 뱃지 | 용도 |
|---|---|
| ![Swift](https://img.shields.io/badge/Swift-5.0-F05138?style=flat-square&logo=swift&logoColor=white) | 전체 앱 로직 구현 언어 |
| ![SwiftUI](https://img.shields.io/badge/SwiftUI-Declarative_UI-blue?style=flat-square&logo=swift&logoColor=white) | 선언형 UI 프레임워크, 모든 View 계층 구현 |
| ![Observation](https://img.shields.io/badge/Observation-%40Observable_Macro-8A2BE2?style=flat-square) | `BudgetViewModel`의 반응형 상태 관리 (`@Observable`, `@Bindable`) |
| ![MVVM](https://img.shields.io/badge/Architecture-MVVM-4B8BBE?style=flat-square) | Model – ViewModel – View 계층 분리 |

### 프레임워크 & 시스템 API

| 뱃지 | 사용처 |
|---|---|
| ![SwiftData](https://img.shields.io/badge/SwiftData-Local_Persistence-FF7F0E?style=flat-square&logo=apple&logoColor=white) | `Transaction`, `MonthlyConfig`, `UserSettings`, `CategoryDefinition`, `SavingsAccount` 모델의 로컬 DB 영속화 (`@Model`, `ModelContainer`, `FetchDescriptor`) |
| ![Vision](https://img.shields.io/badge/Vision-OCR_Engine-2E8B57?style=flat-square&logo=apple&logoColor=white) | `OCRService`의 `VNRecognizeTextRequest` — 영수증 텍스트 인식 (한국어/영어) |
| ![PhotosUI](https://img.shields.io/badge/PhotosUI-PhotosPicker-purple?style=flat-square&logo=apple&logoColor=white) | 영수증 이미지 및 카테고리 아이콘용 사진 선택 (`PhotosPicker`, `PhotosPickerItem`) |
| ![UserNotifications](https://img.shields.io/badge/UserNotifications-Local_Push-red?style=flat-square&logo=apple&logoColor=white) | 매일 지정 시각에 "오늘의 지출을 기록해보세요" 로컬 알림 예약 (`UNUserNotificationCenter`, `UNCalendarNotificationTrigger`) |
| ![ImageIO](https://img.shields.io/badge/ImageIO%20%2F%20CoreGraphics-Image_Decoding-lightgrey?style=flat-square&logo=apple&logoColor=white) | `CGImageSourceCreateWithData` 를 이용한 원본 사진 → `CGImage` 디코딩 |
| ![UniformTypeIdentifiers](https://img.shields.io/badge/UniformTypeIdentifiers-File_I%2FO-lightgrey?style=flat-square&logo=apple&logoColor=white) | JSON 백업 파일 Export/Import 시 `.json` 타입 지정 (`fileExporter`, `fileImporter`) |
| ![Combine](https://img.shields.io/badge/Combine-ObservableObject-9B59B6?style=flat-square&logo=apple&logoColor=white) | `ThemeManager`의 전역 테마/폰트 상태 브로드캐스트 (`ObservableObject`, `@Published`) |
| ![Foundation](https://img.shields.io/badge/Foundation-Core_Utilities-999999?style=flat-square&logo=apple&logoColor=white) | `DateComponents`, `Calendar`, `NumberFormatter`, `NSRegularExpression`, `JSONEncoder/Decoder` 등 |

### 개발 환경

| 뱃지 | 값 |
|---|---|
| ![Xcode](https://img.shields.io/badge/Xcode-16-1575F9?style=flat-square&logo=xcode&logoColor=white) | 프로젝트 포맷 `objectVersion 77` (Xcode 16 세대) |
| ![iOS](https://img.shields.io/badge/iOS_Deployment_Target-26.2-000000?style=flat-square&logo=apple&logoColor=white) | `IPHONEOS_DEPLOYMENT_TARGET = 26.2` |
| ![Device](https://img.shields.io/badge/Target_Device-iPhone_%7C_iPad-lightgrey?style=flat-square&logo=apple&logoColor=white) | `TARGETED_DEVICE_FAMILY = "1,2"` (Universal) |
| ![Bundle](https://img.shields.io/badge/Bundle_ID-com.juseok.Money--Check-informational?style=flat-square) | `PRODUCT_BUNDLE_IDENTIFIER` |

> ℹ️ 외부 API 통신, 서버 백엔드, 네트워크 라이브러리(Alamofire 등)는 사용하지 않습니다. **모든 데이터는 기기 로컬(SwiftData)에만 저장**되는 On-Device 우선 설계이며, "Google Drive 연동"과 "iCloud 동기화"는 코드상 UI만 준비되어 있고 실제 로직은 `"준비 중"` 상태(placeholder)입니다.

---

## ⚙️ 핵심 기능 및 상세 로직 (Key Features & Logic)

### 1. 📸 영수증/카드 내역 자동 인식 (OCR Import)

단순히 "OCR 기능이 있다"가 아니라, **좌표 기반 휴리스틱 스코어링 파서**가 핵심입니다. `OCRParserService`는 다음과 같이 동작합니다.

- **행(Row) 클러스터링**: `Vision`이 반환한 텍스트 라인들은 순서가 보장되지 않으므로, 각 라인의 `boundingBox.midY` 값이 `threshold(0.035)` 이내로 가까우면 같은 행으로 묶습니다(`rows.firstIndex(where:)`).
- **세로 분리 금액 병합**: 영수증에 따라 "합계"라는 라벨과 실제 금액 숫자가 서로 다른 줄(하지만 같은 열)에 위치하는 경우가 많아, `mergeVerticalAmountRows()`가 우측(`minX > 0.5`)에 위치한 숫자 전용 행을 바로 위 라벨 행에 흡수시킵니다.
- **정규식 후보 추출**: `(?<!\d)([+-]?)(?:₩\s*)?(\d{1,3}(?:,\d{3})+|\d{3,})(?:\s*원)?(?!\d)` 패턴으로 콤마 포함 숫자·통화 기호·"원" 단위를 모두 포괄하는 금액 후보를 추출하고, 10자리(전화번호 등 오탐 방지)나 100,000,000원 이상 값은 제외합니다.
- **가중치 스코어링**: `score(_:)` 함수가 **Y좌표(하단일수록 총액일 가능성 ↑) + 글자 높이(강조된 폰트) + 부호 유무 + 통화기호 유무 + "합계/결제금액" 키워드 유무 + 우측 정렬 여부**를 합산해 가장 유력한 "결제 총액" 후보 하나를 선택합니다.
- **수입/지출 자동 분류**: 인식된 텍스트에 `"입금", "월급", "보너스"` 등의 키워드가 있으면 수입(`.income`)으로, 아니면 지출로 분류하고, `카페/식당`, `택시/버스/주유`, `병원/약국`, `마트/편의점`, `구독` 등 키워드 사전 매칭으로 **카테고리까지 자동 추천**합니다.
- **날짜 추론**: `2026.09.27`, `09/27 14:30` 등 다양한 날짜 표기 정규식을 순차 매칭하고, 실패 시 사용자가 앱에서 선택 중이던 날짜(`defaultDate`)로 폴백합니다.

### 2. 🔁 월급날 기준 예산 정산 주기 계산 (`Date.budgetPeriod`)

한국형 가계부의 핵심 로직으로, 달력상의 1일이 아니라 **월급날(`salaryDay`)을 기준으로 한 달을 재정의**합니다.

```swift
// 예: 월급날이 25일이고 대상일이 9/16 → 기간은 8/25 ~ 9/24
// 예: 월급날이 25일이고 대상일이 9/28 → 기간은 9/25 ~ 10/24
static func budgetPeriod(for targetDate: Date, salaryDayNumber: Int) -> (start: Date, end: Date)
```

`targetDate`가 월급날 이전/이후인지에 따라 시작·종료일을 다르게 계산하며, 월말 보정(예: 31일이 없는 2월)도 처리합니다. `BudgetViewModel.budgetProgress(for:)`가 이 기간에 발생한 지출 합계를 `MonthlyConfig.budget`과 나누어 **예산 소진율(%)**을 산출합니다.

### 3. 🔂 반복 지출 자동 생성 엔진 (`processRecurringTransactions`)

- `Transaction.isRecurring = true`이고 `isAppliedRecurring = false`인 거래를 매 앱 실행/추가/수정 시점마다 스캔합니다.
- 다음 달 동일 날짜를 계산하되, **해당 월에 그 일자가 없으면(예: 31일 → 2월) 월의 마지막 날로 자동 보정**합니다.
- 동일 금액·카테고리·`"[반복] " + 메모`를 가진 거래가 이미 존재하는지 검사해 **중복 생성을 방지**합니다.
- 새로 생성된 복제본도 `isRecurring: true, isAppliedRecurring: false`로 설정되어, 이 로직이 **매달 자동으로 연쇄 실행되는 자기 복제 파이프라인**을 구성합니다.

### 4. 🗓️ 커스텀 42칸 캘린더 (`generateCalendarDates`)

- 매월 항상 6주(42일) 그리드를 생성해 캘린더 UI 높이가 달마다 흔들리지 않도록 고정합니다.
- 사용자 설정(`calendarStartWeekday`: 일요일/월요일 시작)에 따라 그리드 시작 오프셋을 동적으로 계산합니다.
- 각 날짜 셀에는 해당일의 수입/지출 합계가 `+1.2K`, `-500K`처럼 **K/M 단위로 축약 표기**되어 렌더링됩니다(`formatCompact`).
- `DragGesture`로 상/하 스와이프 시 월 전환 애니메이션(`easeInOut`)이 트리거됩니다.

### 5. 🧮 인앱 계산기 키패드 (`CalculatorPad`)

금액 입력 시 표준 키보드 대신 **사칙연산이 가능한 커스텀 계산기 시트**(`presentationDetents([.fraction(0.55)])`)를 제공합니다. 연산자 입력 시 `addOperator()`가 즉시 이전 계산을 `calculate()`로 반영한 뒤 새 수식을 시작하는 **연쇄 계산(chained calculation)** 방식으로 동작합니다.

### 6. 🎨 5종 테마 & 5종 폰트 시스템

- `Theme` enum(`system`/`light`/`dark`/`pink`/`blackPink`)이 배경색·카드색·강조색을 전역 정적 프로퍼티로 제공하며, `CategoryType.color` / `TransactionType.color`가 활성 테마(`Theme.activeTheme`)에 따라 분기 렌더링됩니다.
- `AppFontStyle`은 `UIFont.familyNames.contains(family)`로 폰트 설치 여부를 런타임 체크한 뒤, 없으면 SwiftUI 시스템 디자인(`serif`/`rounded`/`monospaced`)으로 안전하게 폴백합니다.
- `ThemeManager`(`ObservableObject`)가 `.environmentObject()`로 앱 전역에 주입되고, `MainView`는 `.id(themeManager.theme)`로 테마 변경 시 **뷰 트리를 강제 재생성**하여 즉시 반영합니다.

### 7. 💾 JSON 백업/복원 (`makeBackupData` / `restoreBackup`)

- SwiftData 모델을 직접 직렬화할 수 없으므로, `Codable`을 채택한 별도의 `Backup*` DTO 구조체로 **한 번 변환(mapping)** 후 `JSONEncoder(.iso8601)`로 직렬화합니다.
- 복원 시에는 기존 트랜잭션/카테고리/저축 계좌를 전량 삭제한 뒤 백업 데이터로 재삽입하는 **전체 교체(Full Replace) 전략**을 사용합니다.
- `FileDocument` 프로토콜을 구현한 `BackupDocument`로 표준 `.fileExporter`/`.fileImporter` UI를 통해 파일 시스템에 안전하게 접근합니다.

### 8. 🔍 다중 조건 검색/필터링 (`SearchView`)

메모 텍스트 검색 + 커스텀 기간(시작일~종료일) + 금액 범위(최소~최대) + 카테고리 다중 선택을 **AND 조건**으로 조합해 `viewModel.transactions` 배열을 순수 클라이언트 사이드 필터링(`filter`)으로 처리합니다.

---

## 📁 프로젝트 구조 및 파일 설명 (Directory Structure)

```text
MoneyCheck/
├── MoneyCheck.xcodeproj/            # Xcode 프로젝트 설정 파일 (빌드 타겟, 서명, 배포 설정)
│
└── MoneyCheck/                      # 앱 소스 루트
    │
    ├── MoneyCheckApp.swift          # @main 진입점. SwiftData ModelContainer 생성,
    │                                 #   BudgetViewModel·ThemeManager 초기화, 최상위 WindowGroup 구성
    │
    ├── Models/                      # SwiftData @Model 엔티티 및 도메인 Enum 정의
    │   ├── Transaction.swift        #   지출/수입 1건을 나타내는 핵심 모델 (날짜, 금액, 카테고리,
    │   │                             #     메모, 사진, 반복 여부). enum은 rawValue 문자열로 저장 후
    │   │                             #     연산 프로퍼티로 안전하게 래핑(SwiftData 호환성 확보)
    │   ├── TransactionType.swift    #   거래 유형 Enum: 수입 / 지출 / 고정 지출 (+ 테마별 색상)
    │   ├── CategoryType.swift       #   10종 기본 카테고리 Enum (식비, 교통, 의료, 문화, 마트,
    │   │                             #     교육, 구독, 월급, 보너스, 기타) + 아이콘/색상 매핑
    │   ├── MonthlyConfig.swift      #   "yyyy-MM" 키 기준 월별 예산·월급날 설정 모델
    │   └── UserSettings.swift       #   앱 전역 설정(테마, 폰트, 알림, 캘린더 시작요일, 보안 등),
    │                                 #     사용자 정의 카테고리(CategoryDefinition), 저축 계좌(SavingsAccount)
    │
    ├── ViewModels/
    │   └── BudgetViewModel.swift    #   @Observable 기반 단일 진실 공급원(SSOT).
    │                                 #     CRUD, 반복 거래 엔진, 예산 계산, 백업/복원, OCR 저장 로직 총괄
    │
    ├── Services/                    # 순수 비즈니스 로직 (UI 의존성 없음)
    │   ├── OCRService.swift         #   Vision 프레임워크 래퍼. 이미지 Data → [OCRLine] 비동기 변환
    │   └── OCRParserService.swift   #   OCRLine 배열 → 거래 후보(ParsedOCRResult) 추출 휴리스틱 파서
    │                                 #     (좌표 클러스터링, 정규식 매칭, 스코어링 알고리즘의 핵심)
    │
    ├── Views/
    │   ├── Main/                    # 앱의 메인 홈 화면을 구성하는 뷰
    │   │   ├── MainView.swift       #   최상위 NavigationStack. 상단 앱바, 대시보드, 캘린더,
    │   │   │                         #     선택일 거래 목록, 플로팅 액션 버튼 및 모든 sheet 라우팅
    │   │   ├── DashboardView.swift  #   이번 달 수입/지출/월간·연간 합계 4분할 요약 카드
    │   │   └── CustomCalendarView.swift  # 42칸 고정 그리드 캘린더. 일별 수입/지출 축약 표시,
    │   │                             #     스와이프 제스처 기반 월 전환
    │   │
    │   └── Detail/                  # 세부 기능별 하위 화면 (Sheet로 present)
    │       ├── TransactionFormView.swift    # 거래 추가/수정 폼. 타입 선택, 카테고리 그리드,
    │       │                                 #   계산기 연동, 다중 날짜 선택, 반복/사진 첨부 옵션
    │       ├── OCRImportView.swift          # 사진 선택 → OCR 실행 → 인식 결과 체크리스트 → 일괄 저장
    │       ├── ListView.swift               # 월별 전체 거래 리스트(스와이프 삭제) +
    │       │                                 #   공용 컴포넌트 TransactionListRow 정의
    │       ├── GraphView.swift              # 주간/월간/연간 기간별 카테고리 지출·수입 비율 리포트
    │       ├── SearchView.swift             # 텍스트/기간/금액/카테고리 다중 조건 검색 화면
    │       ├── SettingView.swift            # 설정 화면 진입점 (SettingsHubView 래핑)
    │       └── SettingsManagementViews.swift # 설정 허브 + 하위 화면 총 12종
    │                                          #   (테마/폰트/캘린더 설정, 카테고리·저축·반복 관리,
    │                                          #    화면 잠금, iCloud 동기화, 백업/복원 등)
    │
    ├── Helpers/                     # 재사용 유틸리티 & 공용 UI 컴포넌트
    │   ├── AppAppearance.swift      #   ThemeManager, AppFontStyle, Theme(색상 팔레트),
    │   │                             #     Color 확장(.appBackground 등) 정의
    │   ├── DateExtension.swift      #   Date 확장: 연/월/일 접근자, 한국어 포맷, 캘린더 그리드 생성,
    │   │                             #     월급날 기준 정산 주기 계산(budgetPeriod)
    │   ├── CalculatorPad.swift      #   금액 입력용 사칙연산 커스텀 키패드 바텀시트
    │   ├── CircularBackButton.swift #   원형 뒤로가기 버튼 공용 컴포넌트
    │   └── DetailHeader.swift       #   하위 화면 공통 상단 헤더(뒤로가기 + 타이틀) 컴포넌트
    │
    └── Assets.xcassets/             # 앱 아이콘, 강조색 등 이미지/컬러 에셋 카탈로그
```

---

## 🚀 Getting Started (설치 및 실행 가이드)

> 이 프로젝트는 **서버/외부 API 연동이 없는 순수 온디바이스(On-Device) 앱**이므로 `.env` 파일이나 API 키 설정이 **필요하지 않습니다.** 아래 단계만 따라 하면 바로 시뮬레이터/실기기에서 실행할 수 있습니다.

### 1️⃣ 사전 준비물 (Prerequisites)

| 항목 | 요구 사항 |
|---|---|
| macOS | Sequoia 이상 권장 (Xcode 16 구동 가능한 버전) |
| Xcode | **16.x 이상** (SwiftData, `@Observable` 매크로, Swift 5.0 지원 버전) |
| iOS 시뮬레이터 / 실기기 | **iOS 26.2 이상** (`IPHONEOS_DEPLOYMENT_TARGET`) |
| Apple 계정 | 실기기 실행 시 코드 서명을 위한 Apple ID (무료 개발자 계정으로도 가능) |

### 2️⃣ 저장소 클론

```bash
git clone <이 저장소의 Git URL>
cd MoneyCheck
```

### 3️⃣ 프로젝트 열기

이 프로젝트는 **SwiftPM/CocoaPods 등 외부 패키지 의존성이 전혀 없으므로**, `pod install` 이나 `xcodebuild -resolvePackageDependencies` 같은 별도의 의존성 설치 과정이 필요 없습니다. Xcode에서 프로젝트 파일을 열기만 하면 됩니다.

```bash
open MoneyCheck.xcodeproj
```

### 4️⃣ 서명(Signing) 설정 (실기기 실행 시에만 필요)

1. Xcode 좌측 네비게이터에서 **`MoneyCheck` 프로젝트 → `MoneyCheck` 타겟** 선택
2. **Signing & Capabilities** 탭 이동
3. **Team**을 본인의 Apple ID(개인 팀)로 변경
4. 번들 식별자가 중복될 경우 `PRODUCT_BUNDLE_IDENTIFIER`(기본값 `com.juseok.Money-Check`)를 본인만의 고유 식별자로 수정

> 시뮬레이터에서만 실행한다면 이 단계는 건너뛰어도 됩니다.

### 5️⃣ 실행 (Run)

1. Xcode 상단 스킴 선택기에서 **`MoneyCheck`** 스킴과 원하는 **iOS 26.2+ 시뮬레이터**(또는 연결된 실기기)를 선택합니다.
2. `Cmd + R` 을 누르거나 ▶️ Run 버튼을 클릭합니다.
3. 앱이 최초 실행되면 `MoneyCheckApp.init()`에서 SwiftData `ModelContainer`가 자동으로 생성되고, `UserSettings` 기본값(테마: 시스템, 폰트: 시스템)이 자동 삽입됩니다. **별도의 초기 설정이나 로그인 절차는 없습니다.**

### 6️⃣ (선택) 실기기에서 OCR 기능 테스트하기

- OCR(영수증 인식) 기능은 **Vision 프레임워크**를 사용하므로 시뮬레이터에서도 동작하지만, 실제 사진 라이브러리에 저장된 영수증 이미지로 테스트하려면 **실기기**에서 확인하는 것을 권장합니다.
- 별도의 카메라 권한 설정(`Info.plist`)이 필요 없는 이유는, 이 프로젝트가 카메라를 직접 호출하지 않고 iOS 표준 `PhotosPicker`(제한적 라이브러리 접근 방식)만 사용하기 때문입니다.

---

## 🛠️ Troubleshooting & Dev Log (트러블슈팅 및 개발 일지)

> 실제 커밋 히스토리와 코드에 남은 흔적을 바탕으로, 개발 과정에서 마주쳤을 법한 기술적 난관과 그 해결 접근을 정리했습니다.

### 🧵 1. Vision의 콜백 기반 API를 `async/await`로 브릿징하기

**문제**: `VNRecognizeTextRequest`는 완료 핸들러(closure) 기반의 구식 API입니다. SwiftUI의 `Task { }` / `async` 문법과 자연스럽게 어우러지려면 콜백을 그대로 노출해서는 안 됩니다.

**해결**: `withCheckedThrowingContinuation`으로 콜백을 감싸고, `VNImageRequestHandler.perform()` 자체는 `DispatchQueue.global(qos: .userInitiated)`에서 실행해 **메인 스레드 블로킹을 방지**했습니다. `@preconcurrency import Vision`을 명시한 것으로 보아, Swift Concurrency 엄격성 검사(Strict Concurrency Checking)에서 Vision의 델리게이트/콜백 타입이 `Sendable`을 완전히 만족하지 못해 경고가 발생했고, 이를 우회하기 위한 결정으로 보입니다.

### 🧮 2. "영수증마다 레이아웃이 다 다르다" — OCR 결과에서 진짜 결제 금액 찾기

**문제**: 단순히 "영수증에서 가장 큰 숫자를 찾는" 방식으로는 실패율이 매우 높습니다. 할인 전 금액, 할부 개월 수, 카드 뒷자리 번호, 매장 전화번호, 시간(`14:30`), 날짜(`2026.09.27`)까지 모두 "숫자"이기 때문입니다.

**해결**: 단일 기준이 아닌 **다요소 가중치 스코어링**(`score(_:)`)을 설계했습니다. Y좌표(하단에 위치할수록 총액일 확률↑), 폰트 크기(강조된 숫자일수록↑), 통화 기호/키워드 동반 여부, 부호(+/-) 유무, 우측 정렬 여부를 종합 점수화하여 가장 유력한 후보 하나를 고르는 방식입니다. 동시에 `isTimeOrDate()` 필터로 `14:30`, `20260927` 같은 **날짜/시간 오탐을 사전에 배제**하는 방어 로직을 별도로 두었습니다. 이 부분은 실제 다양한 영수증 샘플로 반복 튜닝이 필요했을 것으로 추정되는, 이 프로젝트에서 **가장 복잡도가 높은 로직**입니다.

### 🔁 3. "반복 지출"이 무한 증식하지 않도록 막기

**문제**: 매달 25일에 나가는 "넷플릭스 구독료"를 반복 등록하면, 앱을 실행할 때마다 `processRecurringTransactions()`가 호출되는데, 자칫하면 실행할 때마다 중복 거래가 계속 쌓일 위험이 있습니다.

**해결**: 두 가지 안전장치를 뒀습니다.
1. **플래그 기반 1회 처리 보장**: `isAppliedRecurring` 불리언으로 "이미 다음 달 분을 생성했는지" 상태를 명시적으로 관리하여, 같은 원본 거래가 두 번 처리되지 않도록 합니다.
2. **내용 기반 중복 검사**: 혹시 플래그 로직에 허점이 있더라도, `날짜 + 금액 + 카테고리 + "[반복] " 접두사가 붙은 메모`가 완전히 일치하는 거래가 이미 있는지 한 번 더 검사(`isAlreadyCreated`)하는 **이중 방어(defense-in-depth)** 구조로 설계했습니다.

또한 `31일 → 30일까지 있는 달`처럼 **말일 보정(day-of-month clamping)** 이 필요한 엣지 케이스를, "다음 달의 실제 마지막 날짜"를 먼저 계산한 뒤 `min(originalDay, lastDay)`에 해당하는 날짜로 스냅하는 방식으로 해결했습니다. 동일한 보정 로직이 `Date.budgetPeriod(for:salaryDayNumber:)`에도 재사용됩니다.

### 🗃️ 4. SwiftData 모델에 `enum`을 안전하게 저장하기

**문제**: `@Model` 매크로가 붙은 SwiftData 클래스에 Swift `enum` 프로퍼티를 직접 선언하면, 스키마 마이그레이션이나 `Codable` 직렬화 과정에서 예기치 못한 크래시나 데이터 유실이 발생할 수 있는 것으로 알려져 있습니다.

**해결**: `Transaction.type`, `Transaction.category`, `UserSettings.theme`, `CategoryDefinition.kind`, `SavingsAccount.kind` 등 모든 enum 프로퍼티를 **`private var xxxRawValue: String`으로 저장**하고, `public var xxx: EnumType { get { ... ?? 기본값 } set { ... } }` 형태의 **연산 프로퍼티로 감싸는 패턴**을 일관되게 적용했습니다. `rawValue`로 디코딩 실패 시(`?? .expense`, `?? .etc` 등) **항상 안전한 기본값으로 폴백**하도록 하여, 향후 enum case가 추가/변경되어도 기존 저장 데이터가 깨지지 않도록 방어했습니다.

### 💾 5. SwiftData 모델을 JSON으로 백업/복원하기

**문제**: `@Model` 클래스는 기본적으로 `Codable`을 채택하지 않으며, `PersistentModel`을 직접 `JSONEncoder`로 인코딩하려 하면 컴파일 에러 또는 순환 참조 문제가 발생합니다.

**해결**: `BudgetViewModel.swift` 상단에 `BackupTransaction`, `BackupCategory`, `BackupSavingsAccount`, `BackupSettings`를 **순수 `Codable` struct(DTO)로 별도 정의**하고, `makeBackupData()`에서 SwiftData 모델 → DTO로 매핑 후 인코딩하는 **어댑터 패턴**을 적용했습니다. 복원 시(`restoreBackup`)에는 기존 데이터를 전량 삭제 후 재삽입하는 방식을 택해 **부분 병합으로 인한 정합성 문제를 원천 차단**했습니다. 다만 이 방식은 복원 중간에 오류가 나면 데이터가 비어버릴 위험이 있어, 추후 트랜잭션 원자성 보장(예: 임시 컨텍스트에서 검증 후 커밋)이 개선 과제로 남아있습니다.

### 🎨 6. 다크모드/핑크 테마 등 5종 테마를 SwiftUI `Color` 시스템과 공존시키기

**문제**: SwiftUI의 `@Environment(\.colorScheme)`만으로는 "핑크 테마"처럼 시스템 다크/라이트 모드와 무관한 **브랜드 커스텀 테마**를 표현하기 어렵습니다.

**해결**: `Theme` enum을 **static 프로퍼티 저장소**로 만들어 `Theme.activeTheme`이라는 전역 상태에 따라 `backgroundColor`, `accentColor` 등이 분기되도록 설계했습니다. 다만 이 방식은 SwiftUI의 선언형 갱신 흐름과 완전히 자동으로 연동되지 않는 한계가 있어, `MainView`에서 `.id(themeManager.theme)`를 통해 **테마 변경 시 뷰 계층을 강제로 재생성**시키는 절충안으로 즉시 반영을 보장했습니다.

### 🔒 7. 화면 잠금 / iCloud 동기화는 왜 "준비 중"으로 남아있나?

`ScreenLockSettingsView`, `CloudSyncView`의 버튼들은 현재 `"아직 구현 중입니다"` 알럿만 표시합니다. 이는 미완성 버그가 아니라, **Face ID/Touch ID(`LocalAuthentication`)와 `CloudKit` 연동은 각각 별도의 Capability 설정과 실기기 테스트가 필요한 영역**이라 UI 설계(정보구조)를 먼저 완성하고 로직은 후속 스프린트에서 붙이기로 한 **의도적인 단계적 개발(Progressive Enhancement) 전략**의 결과물입니다. `UserSettings` 모델에는 이미 `screenLockEnabled`, `biometricEnabled`, `iCloudSyncEnabled` 필드가 준비되어 있어, 실제 로직 연결 시 **모델 변경 없이 뷰/서비스 레이어만 추가**하면 되도록 설계돼 있습니다.

---

<div align="center">

Made with using SwiftUI & Vision

</div>
