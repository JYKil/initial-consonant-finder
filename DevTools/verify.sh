#!/bin/bash
# 4단계 시뮬레이터 검증 일괄 실행.
#
# 권한 상태 머신은 테스트 프로세스 안에서 못 바꾼다 (simctl 은 호스트 도구).
# 그래서 각 권한 상태를 여기서 세팅하고 해당 테스트만 골라 실행한다.
#
#     ./DevTools/verify.sh
#
# ⚠️ SeedContacts 는 시뮬레이터 연락처를 전부 지운다. 실기기에서 돌리지 말 것.

set -euo pipefail

BUNDLE_ID="com.kilga.InitialConsonantFinder"
DEVICE="${DEVICE:-iPhone 17}"
DEST="platform=iOS Simulator,name=$DEVICE"
DERIVED=".build/xcode"

run_test() {
  local scheme="$1" only="$2" label="$3"
  echo ""
  echo "▶ $label"
  if xcodebuild test \
      -project InitialConsonantFinder.xcodeproj \
      -scheme "$scheme" \
      -destination "$DEST" \
      -derivedDataPath "$DERIVED" \
      ${only:+-only-testing:"$only"} \
      2>&1 | grep -E "^Test Case .*(passed|failed)|failed - |^\*\* TEST"; then
    :
  fi
}

echo "== 시뮬레이터 준비: $DEVICE =="
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true

echo "== 프로젝트 생성 =="
xcodegen generate >/dev/null

# ── 연락처 픽스처 먼저 ────────────────────────────────────────────
# 시딩은 권한이 있어야 한다. 그리고 온보딩 2단계 시트가 "N개의 연락처 모두 공유" 라서
# 연락처가 0개면 문구가 달라진다 → 권한 테스트보다 먼저 넣는다.
# privacy reset 은 TCC 만 초기화하고 연락처 데이터는 그대로 둔다.
echo ""
echo "== 연락처 픽스처 시딩 (기존 연락처 전부 삭제) =="
xcrun simctl privacy booted grant contacts "$BUNDLE_ID"
# -only-testing 을 반드시 준다. 스킴의 test action 에는 모든 테스트 타겟이 물려 있어서
# 생략하면 UI 테스트까지 같이 돌고, 권한 상태가 어긋난 채 실패한다.
run_test SeedContacts "SeedContacts/SeedContacts" "연락처 9개 시딩"

# ── 권한 상태 머신 ───────────────────────────────────────────────
# notDetermined → 온보딩 → 시스템 팝업 2단계 → 검색 화면
xcrun simctl privacy booted reset contacts "$BUNDLE_ID"
run_test UITests \
  "UITests/PermissionUITests/test_첫실행_온보딩_권한허용_검색화면" \
  "notDetermined → 온보딩 → 권한 허용(2단계) → 검색 화면"

# denied → PermissionDeniedView
xcrun simctl privacy booted revoke contacts "$BUNDLE_ID"
run_test UITests \
  "UITests/PermissionUITests/test_권한거부시_안내화면과_설정열기버튼" \
  "denied → 권한 안내 화면 + 설정 열기"

# authorized → 온보딩 스킵
xcrun simctl privacy booted grant contacts "$BUNDLE_ID"
run_test UITests \
  "UITests/PermissionUITests/test_권한있으면_온보딩_스킵하고_바로_검색화면" \
  "authorized → 온보딩 스킵, 바로 검색 화면"

# ── 검색 기능 ────────────────────────────────────────────────────
run_test UITests "UITests/SearchUITests" "초성 검색 / 상세 시트 / 로컬라이제이션"

echo ""
echo "== 단위 테스트 (Swift Package) =="
swift test 2>&1 | grep -E "Test run with|Executed [0-9]+ tests|error:" | tail -3

echo ""
echo "✅ 검증 완료"
