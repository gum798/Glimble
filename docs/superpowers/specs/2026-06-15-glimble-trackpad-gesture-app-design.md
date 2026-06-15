# Glimble — 설계 문서 (Design Spec)

- **작성일**: 2026-06-15
- **상태**: 승인됨 (구현 계획 작성 전 검토 단계)
- **한 줄 요약**: 내장 트랙패드 제스처를 임의의 동작(단축키·스크립트·앱 실행·창 관리)에 매핑하는, Developer ID 서명·공증된 비샌드박스 macOS 메뉴바 앱. "BetterTouchTool만큼 강력하지만 더 심플하게."

이 문서는 검증된 기술 리서치(6개 facet, 적대적 검증, 전부 high 신뢰도)를 토대로 한다.

---

## 1. 목표 / 비목표

### 1.1 v1 목표 (좁고 완성도 높게)
- **제스처(트리거)**: 3·4손가락 방향 스와이프(상/하/좌/우), 손가락 수별 탭/클릭
- **동작(액션)**: 키보드 단축키, 셸 스크립트 / AppleScript / 단축어(Shortcuts), 앱 실행, 창 스냅·이동·리사이즈
- **UX**: 직관적 설정 UI, 즉시 쓸 수 있는 기본 프리셋, 라이브 제스처 레코더/미리보기, 권한별 온보딩
- **성능**: 메뉴바에 조용히 상주, 낮은 CPU·메모리
- **배포**: Developer ID 서명 + 공증(notarization), 직접 배포(.dmg/GitHub), 자동 업데이트(Sparkle)
- **입력 기기**: MacBook **내장 트랙패드만**
- **타깃 OS**: 최소 macOS 15(Sequoia), macOS 26(Tahoe) 검증

### 1.2 비목표 (구조상 자리는 마련, v1.x 이후로 연기)
- 사용자 지정 드로잉 제스처($1 + Protractor)
- 핀치 / 회전 / Force Touch 압력 동작
- 외장 Magic Trackpad / Magic Mouse
- Spaces 간 창 이동, 네이티브 풀스크린 창 조작, 멀티스트로크 도형($P/$Q)
- Mac App Store 배포 (비공개 프레임워크 의존으로 **영구 불가** — 의도된 트레이드오프)

---

## 2. 핵심 기술 제약 (왜 이런 설계인가)

1. **원시 멀티터치는 공개 API로 불가능.** 손가락 수별 탭, 드로잉 같은 제스처는 공개 `NSEvent`/`CGEvent`로 얻을 수 없고, 비공개 `MultitouchSupport.framework`만이 원시 per-finger 데이터를 제공한다. → 오픈소스 MIT 래퍼 **`Kyome22/OpenMultitouchSupport`**(SwiftPM, macOS 15+)를 사용해 dlopen·C 브리지를 격리한다.
2. **공증 ≠ 앱 심사.** 공증/Gatekeeper는 비공개 API를 막지 않는다(악성코드·서명·하드닝 런타임만 검사). 비공개 API는 **App Store 심사**에서만 거부되며, 어차피 App Store는 비목표다. (BTT·Karabiner·Multitouch가 통과한 정황 증거 강함. 단 Apple의 명시적 보증은 아님 → Phase 0에서 실증.)
3. **권한 2종이 독립적.** 터치 *읽기* = 입력 모니터링, 동작 *실행* = Accessibility. 각각 따로 프리플라이트/요청해야 한다.
4. **시스템 기본 제스처를 막을 수 없다.** 읽기 전용 스트림으로는 macOS의 3·4손가락 제스처를 가로챌 수 없다. → 온보딩에서 충돌 제스처 끄기를 안내하고, macOS가 안 쓰는 손가락 수/방향을 기본값으로 한다.

---

## 3. 아키텍처 개요

**단일 프로세스 메뉴바 에이전트(LSUIElement)**. 비공개 API와 OS 권한 코드는 가장자리 모듈에 격리. XPC/헬퍼 없음(고빈도 터치 경로의 지연·CPU·서명 비용 회피).

```
[트랙패드]
   │  (~60–125 Hz, N touches/frame)
   ▼
OpenMultitouchSupport.touchDataStream
   ▼
┌──────────────┐   normalized TouchFrame
│ TouchSource  │ ──────────────────────────┐
└──────────────┘                            ▼
                                   ┌────────────────────┐
        frontmost bundleID         │ GestureRecognizer  │  (순수, OS import 없음)
   ┌──────────────┐  ◀── 컨텍스트   │  ≥2손가락 게이트 →  │
   │  AppContext  │                │  상태머신 → 아비터  │
   └──────┬───────┘                └─────────┬──────────┘
          │                                  ▼ RecognizedGesture
          │                         ┌────────────────────┐
          └────────────────────────▶│     RuleStore      │  앱별 > 글로벌 스코프
                                     └─────────┬──────────┘
                                               ▼ matched Action
                                     ┌────────────────────┐
                                     │   ActionExecutor   │  CGEvent / AX / Script / launch
                                     └────────────────────┘

   ┌─────────────────────────┐   ┌──────────────────────────────────────────┐
   │ PermissionsCoordinator  │   │ AppShell (SwiftUI 뷰 + AppKit 셸)          │
   │ 입력모니터링·Accessibility│   │ NSStatusItem · 설정창 · 온보딩 · Sparkle    │
   └─────────────────────────┘   └──────────────────────────────────────────┘
```

---

## 4. 모듈 상세

각 모듈은 단일 책임 + 명확한 인터페이스 + 독립 테스트 가능을 목표로 한다.

### 4.1 TouchSource
- **책임**: `OpenMultitouchSupport`를 얇은 내부 프로토콜 뒤로 감싸 정규화된 `TouchFrame`(per-finger: id, position(x/y), velocity, pressure, axis(major/minor), angle, state) 스트림을 방출. **모든 비공개 API 접근을 이 모듈에 격리.**
- **인터페이스**: `protocol TouchSource { var frames: AsyncStream<TouchFrame> { get }; func start(); func stop() }`
- **구현 노트**:
  - `OMSManager.shared()`, `startListening()/stopListening()`, `for await touchData in manager.touchDataStream`. `OMSTouchData` 필드(id/position/pressure/total/axis/angle/density/state/timestamp)를 `TouchFrame`으로 정규화.
  - 핫패스 할당 0, 콜백 스레드에서 무거운 작업 금지(별도 큐로 hop).
  - 현재 컨텍스트에 매칭될 규칙이 없으면 `stop()`으로 스트림 정지(가벼움).
  - 패키지는 **버전 핀** + **소스 사본 vendoring**(바이너리 XCFramework 타깃 소실 대비 헤지). GPL인 calftrail 헤더는 **재벤더링 금지**(MIT 경로 유지).
- **의존**: 없음 (외부: OpenMultitouchSupport)

### 4.2 GestureRecognizer
- **책임**: 순수·결정론·핫패스 무할당 엔진. `TouchFrame` 스트림 → `RecognizedGesture`. **OS/비공개 API import 없음** → 녹화 픽스처로 단위 테스트.
- **v1 Layer 1만** (기하/운동학 + 손가락수별 상태머신 + 단일 승자 아비터). Layer 2($1+Protractor)는 구조만 열어두고 v1.x.
- **인터페이스**: `func process(_ frame: TouchFrame) -> RecognizedGesture?`
- **알고리즘**:
  - **공통 하드 게이트**: ≥2(이상적으로 ≥3) 손가락이 N프레임 안정될 때만 인식 진입 → 1손가락 커서 이동 차단(오인식 1차 방어선).
  - **스와이프**: 권위 손가락 수 = "N프레임 안정적으로 동시에 닿은 최대 손가락 수"(4→3 오판 수정). 전체 손가락 평균(강체) 이동 벡터에 거리 **및** 속도 임계 + 우세 축 규칙.
  - **탭 vs 클릭 vs 포스클릭**: 탭 = N손가락 down+up, 저이동, 클릭 없음 / 클릭 = 시스템 클릭 존재 / 포스클릭 = `NSEvent` pressure stage 2 (v1.x).
  - **상태머신**: `possible → began → changed → ended` + 명시적 `failed/cancelled`, 단일 승자 아비터.
- **의존**: TouchSource(데이터 형상만)

### 4.3 AppContext
- **책임**: 최전면 앱 bundleID(`NSWorkspace.shared.frontmostApplication`) 제공 → 규칙 스코프. 현재 컨텍스트로 매칭 가능한 규칙이 없으면 TouchSource 정지를 트리거.
- **의존**: 없음

### 4.4 RuleStore
- **책임**: 버전드 JSON 설정 로드/저장/검증, 스코프 해석(앱별 > 글로벌), 큐레이션 프리셋 번들 관리, 신뢰 불가 import 처리(스크립트 동작은 활성화 전 확인).
- **데이터 모델**: §5 참조. 트리거→동작 매핑의 단일 진실 원천.
- **의존**: 없음

### 4.5 ActionExecutor
- **책임**: `Action` 프로토콜 뒤(테스트에서 mock 가능)에서 실제 동작 실행. 모든 이벤트 합성·AX 코드가 여기 모인다.
- **동작 타입과 API**:
  - 키보드 단축키: `CGEvent(keyboardEventSource:virtualKey:keyDown:)` + `.flags`(modifier) + `.post(tap: .cghidEventTap)`
  - 창 스냅/이동/리사이즈: Accessibility API (§7)
  - 셸: `Process` + `/bin/zsh -c` (out-of-process)
  - AppleScript: `NSUserAppleScriptTask`(out-of-process, 엔타이틀먼트 불필요) — 인프로세스 `NSAppleScript` 회피
  - 단축어: `shortcuts run "Name"` CLI 또는 `shortcuts://run-shortcut?name=`
  - 앱 실행: `NSWorkspace.openApplication(at:configuration:)`
- **의존**: AppContext

### 4.6 PermissionsCoordinator
- **책임**: 기능별 TCC 처리. 읽기용 입력 모니터링과 동작용 Accessibility를 **각 기능 활성화 시점에만** 프리플라이트/요청. 정확한 설정 창 딥링크. "켜졌는데 안 먹힘"(재서명 무효화 / `trust=true`인데 AX 실패) 감지 → 복구 플로우.
- **API**:
  - 입력 모니터링: `CGPreflightListenEventAccess()` / `CGRequestListenEventAccess()` (또는 `IOHIDCheckAccess`/`IOHIDRequestAccess`). 딥링크 `x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent`
  - Accessibility: `AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`. 딥링크 `?Privacy_Accessibility`
  - 주의: `AXIsProcessTrusted()`가 true여도 `AXUIElementCopyAttributeValue`가 `.cannotComplete`로 실패 가능 → trust ≠ 동작.
- **의존**: 없음

### 4.7 AppShell
- **책임**: SwiftUI 뷰 + AppKit 셸. `NSStatusItem` + `NSApplicationDelegate`(`.accessory`/LSUIElement). 설정창(규칙 편집기, 라이브 제스처 레코더/미리보기), 온보딩, 로그인 시 실행(`SMAppService.mainApp`, live status), Sparkle 연결.
- **구현 노트**: SwiftUI `SettingsLink`/`openSettings` 의존 금지(macOS 15 불안정, macOS 26 깨짐 보고) → `NSApp`/`NSWindowController`로 설정창 직접 제어.
- **의존**: 전 모듈 조립

---

## 5. 데이터 모델

단일 **버전드 JSON 문서**.

```jsonc
{
  "version": 1,
  "rules": [
    {
      "id": "uuid",
      "scope": "global",            // "global" | bundleID 문자열 (앱별 > 글로벌)
      "trigger": {
        "type": "swipe",            // "swipe" | "tap"
        "params": { "fingers": 3, "direction": "left" }
      },
      "action": {                   // tagged union
        "kind": "shortcut",         // shortcut | shell | appleScript | shortcutsApp | launchApp | window
        "value": { /* kind별 페이로드 */ }
      },
      "enabled": true
    }
  ]
}
```

- 앱별 규칙이 글로벌보다 우선(충돌 시).
- 프리셋 = 같은 포맷의 **읽기 전용 번들**. import는 신뢰 불가 취급(스크립트 동작은 사용자 확인 후 활성화).
- `Codable`, version 필드로 마이그레이션.

---

## 6. 창 관리 설계 (공개 Accessibility API만)

- **해피 패스(~6 심볼)**: `AXIsProcessTrustedWithOptions`(게이트/프롬프트) → `NSWorkspace.shared.frontmostApplication`(pid) → `AXUIElementCreateApplication(pid)` → `kAXFocusedWindowAttribute` 읽기 → `kAXPositionAttribute`/`kAXSizeAttribute` 읽기/쓰기(`AXUIElementCopyAttributeValue`/`SetAttributeValue`, CGPoint/CGSize는 `AXValueCreate`/`AXValueGetValue`로 마샬링).
- **스냅 레이아웃** = `NSScreen.visibleFrame`(메뉴바·Dock 이미 제외) 산술. 최대화 = visibleFrame, 가운데 = 그 안 인셋.
- **`setFrame` 순서 = size → position → size**(`adjustSizeFirst`) — 디스플레이 간 이동 시 macOS 크기 클램핑 생존.
- **좌표 뒤집기**(멀티 디스플레이 1순위 버그): AppKit은 좌하단 원점, AX/Quartz는 좌상단 원점. 주 디스플레이 높이로 Y 뒤집기, 주 디스플레이보다 위 디스플레이는 AX Y가 음수. → 스택형 레이아웃 단위 테스트 필수.
- **`AXEnhancedUserInterface` 우회**(Chrome/Electron/Office 필수): **application 요소**에서 읽어 resize 전 false, 후 복원. (`AXManualAccessibility`는 만능 아님.)
- **v1 범위 밖**: Spaces 간 이동, 네이티브 풀스크린 조작 → 풀스크린(서브롤 `zoomButton` 부재 등)이면 graceful no-op. **청사진 = Rectangle(MIT)**, UX 레퍼런스 = Loop/Swish. **yabai 모델링 금지**(SIP 부분 비활성 필요).

---

## 7. 권한 & 온보딩

- 기능 활성화 시점에 해당 권한만 요청:
  - 제스처 인식 ON → 입력 모니터링
  - 키입력/창 제어 동작 → Accessibility
- 정확한 설정 창 딥링크. "권한 켜졌는데 이벤트 안 옴" 복구 플로우(재서명 무효화 대비 — **안정적 Developer ID 식별자** 사용).
- 시스템 기본 3·4손가락 제스처 끄기 안내 단계. 기본 프리셋은 비충돌 손가락 수/방향.
- 터치 리더는 **포그라운드 메뉴바 에이전트 내부**에 둔다(헤드리스 데몬은 TCC 프롬프트가 안 뜰 수 있음).
- 참고: Sequoia의 *주기적 재동의*는 화면 기록에만 해당, 입력 모니터링/Accessibility는 무관.

---

## 8. 배포 & 패키징

- **빌드 단위**: Xcode `.app` 타깃(Archive → Distribute App → Developer ID 파이프라인이 Sparkle XPC 헬퍼 서명을 올바른 순서로 처리).
- **서명/공증**: Developer ID Application 서명 → `xcrun notarytool submit --wait`(App Store Connect API key) → `xcrun stapler staple` → `spctl -a -t exec -vv` 검증.
- **엔타이틀먼트/런타임**: 하드닝 런타임 **ON** + `com.apple.security.cs.disable-library-validation = true`(다른 Team ID 서명 프레임워크 로드 허용, 프로비저닝 불필요, 공증 무방해) **단 1개**. App Sandbox **OFF**(비공개 프레임워크·전역 입력·AX 제어·셸 실행과 양립 불가, 필수).
- **메뉴바 에이전트**: `LSUIElement = YES`.
- **자동 업데이트**: Sparkle 2.x + EdDSA(Ed25519). `SUPublicEDKey`/`SUFeedURL` in Info.plist, appcast over HTTPS, **`CFBundleVersion` 매 릴리스 엄격 증가**(아니면 업데이트 no-op). 헬퍼 개별 서명, 앱 마지막, `--deep` 금지. (steipete의 샌드박스 전용 mach-lookup 예외는 비샌드박스인 Glimble에 불필요.)

---

## 9. 오류 처리 / 회복력

- **비공개 API 깨짐**(최대 리스크): TouchSource 뒤 격리, dlopen 실패 시 graceful degrade, 버전 게이트·방어적 구조체 파싱, **CI 스모크 테스트**가 깨진 터치 스트림을 사용자보다 먼저 감지.
- **TCC 무효화**: 안정적 서명 + 복구 플로우.
- **AX 실패**: `trust=true`인데 실패 처리, 풀스크린 no-op, EnhancedUI 우회.
- **스크립트 동작**: out-of-process 실행, 악성 import 방어(활성화 전 확인).
- **시스템 제스처 충돌**: 막을 수 없음 → 온보딩 안내 + 비충돌 기본값.
- **(이벤트 탭을 쓸 경우)**: `.tapDisabledByTimeout`/`.tapDisabledByUserInput` 시 `CGEvent.tapEnable(enable:true)` 재활성 + 헬스체크 타이머 + `NSWorkspace.didWakeNotification`에서 재무장.

---

## 10. 테스트 전략

- **GestureRecognizer**: OS/비공개 API import 없는 순수 모듈 → 녹화한 `TouchFrame` 픽스처로 결정론 단위 테스트(스와이프 방향/손가락 수, 탭 vs 클릭, 게이트, 아비터).
- **ActionExecutor**: `Action` 프로토콜 mock으로 테스트.
- **창 좌표 뒤집기**: 스택형 멀티 디스플레이 단위 테스트.
- **CI 스모크 테스트**: macOS 15·26 × Intel·Apple Silicon 매트릭스에서 실행 시 터치 프레임 1개 도착 확인.

---

## 11. 단계 계획

### Phase 0 — 리스크 번다운 스파이크 (1~2주, 프로젝트 게이트)
1. OpenMultitouchSupport 링크 스파이크가 **공증 + Gatekeeper 통과**하는지 클린 macOS 26에서 확인
2. macOS 15·26 / Intel·Apple Silicon에서 입력 모니터링 허용 후 **터치 프레임 실제 도착** 확인
3. OpenMultitouchSupport 정확한 핀 버전/라이선스/툴체인 직접 확인
4. Chrome 대상 AX 스냅(EnhancedUI 우회) 프로토타입
- **이 4개가 안 되면 아키텍처 확정 전 방향 재고.**

### Phase 1 — 좁은 v1 (출시 제품)
- TouchSource + GestureRecognizer(Layer 1: 3/4손가락 스와이프 + 손가락 수별 탭, 손가락 수 디바운스, ≥2 게이트)
- RuleStore(버전드 JSON) + AppContext(앱별 스코프)
- ActionExecutor: 단축키 / 셸·AppleScript·단축어 / 앱 실행 / 큐레이션 창 스냅·이동·리사이즈(size→position→size, 좌표 뒤집기, EnhancedUI 우회, 풀스크린 no-op)
- AppShell: 메뉴바 + 권한별 온보딩 + 라이브 제스처 레코더/미리보기 + 로그인 실행
- 기본 프리셋(시스템 제스처 끄기 안내 동반)
- Developer ID 서명 + 공증 + Sparkle
- CI 스모크 테스트

### Phase 2+ — v1.x 이후
- 드로잉 제스처($1+Protractor, 모디파이어 손가락 수 뒤), 핀치/회전/Force Touch, 외장 기기(MTDeviceCreateList / M5MultitouchSupport), 멀티스트로크($P/$Q), 임계값 튜닝.

---

## 12. 스택 & 의존성

- Swift 6.x / Xcode 26 / 최소 macOS 15, macOS 26 검증
- UI: SwiftUI 뷰 + AppKit 셸(`NSStatusItem`/`NSApplicationDelegate`; 설정창은 `NSWindowController`)
- SwiftPM: `Kyome22/OpenMultitouchSupport`(버전 핀 + 소스 vendoring), `sparkle-project/Sparkle` 2.x
- 창 관리: 외부 의존성 없이 공개 AX 직접(Rectangle 청사진)
- 설정: Codable JSON, 버전드

---

## 13. 주요 리스크

1. **비공개·미문서 프레임워크 의존(실존적)**: Apple이 `MTTouch` 구조체·심볼·접근을 포인트 릴리스에서 바꿀 수 있음(10.13.2 베타에서 비활성→복원 전례). → TouchSource 격리, dlopen graceful, 버전 게이트 파싱, CI 스모크.
2. **공증 호환성은 추론(명시적 Apple 보증 아님)**: 강한 실존 증거(BTT/Karabiner/Multitouch)는 있으나 Quinn의 "현재로서는 품질 검사 안 함"은 시간적 단서 → Phase 0에서 실증.
3. **macOS 26 신규 타깃**: Rectangle류 스냅/리사이즈 회귀 보고, 26에서 원시 터치 읽기 1차 확인 부재 → 양 OS 실기 검증.
4. **TCC 마찰·무효화**: 수동 권한 2종, 재서명 시 리셋, 데몬 프롬프트 실패 → 안정 식별자 + 권한별 온보딩 + 복구 플로우.
5. **시스템 3/4손가락 제스처 억제 불가**: 사용자에게 끄기 안내 의존(마찰·지원 부담) → 비충돌 기본값.
6. **SwiftUI MenuBarExtra/openSettings macOS 26 불안정**: AppKit 셸이 사실상 필수.
7. **비샌드박스+비공개 프레임워크 = App Store 영구 불가**(되돌릴 수 없음) — Developer ID 계획과 일치, 제품 목표가 바뀌지 않는지 확인.
8. **리버스 엔지니어링 필드(Force Touch 압력 의미 등)는 OS·트랙패드 세대별 불안정** → 하드웨어 캘리브레이션 필요(v1.x).

---

## 14. 미해결 / 추후 결정

- 프리셋 기본 세트 구체 목록(어떤 제스처→어떤 동작) — 구현 계획/디자인 단계에서 확정.
- 설정창 레이아웃 구체안(규칙 편집기 UX, 라이브 레코더 표현) — 필요 시 비주얼 목업.
- 앱 아이콘 / 브랜딩.
