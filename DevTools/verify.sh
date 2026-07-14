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
DERIVED=".build/xcode"

echo "== 시뮬레이터 준비: $DEVICE =="
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null 2>&1 || true

# ⚠️ 이름만으로 디바이스/simctl 명령을 지칭하면 안 된다. 이 머신엔 iOS 런타임이 여러 개 깔려 있어서
# "iPhone 17" 같은 이름이 UDID 가 다른 시뮬레이터 여러 개에 동시에 존재할 수 있고, 개발 중에
# 다른 시뮬레이터를 함께 부팅해두면(DevTools/verify-parallel.sh 등) `simctl ... booted` 나
# `-destination name=...` 이 의도와 다른 인스턴스를 가리켜 유령 실패가 난다
# (실측: DevTools/verify-parallel.sh 개발 중 동일 증상 확인). 부팅된 인스턴스의 UDID 로 고정한다.
DEVICE_UDID=$(xcrun simctl list devices booted -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
name = sys.argv[1]
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == name and d['state'] == 'Booted':
            print(d['udid']); sys.exit(0)
sys.exit(1)
" "$DEVICE")
DEST="platform=iOS Simulator,id=$DEVICE_UDID"
echo "  UDID=$DEVICE_UDID"

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

echo "== 프로젝트 생성 =="
xcodegen generate >/dev/null

# ── 연락처 픽스처 먼저 ────────────────────────────────────────────
# 시딩은 권한이 있어야 한다. 그리고 온보딩 2단계 시트가 "N개의 연락처 모두 공유" 라서
# 연락처가 0개면 문구가 달라진다 → 권한 테스트보다 먼저 넣는다.
# privacy reset 은 TCC 만 초기화하고 연락처 데이터는 그대로 둔다.
echo ""
echo "== 연락처 픽스처 시딩 (기존 연락처 전부 삭제) =="
xcrun simctl privacy "$DEVICE_UDID" grant contacts "$BUNDLE_ID"
# ⚠️ -only-testing 은 반드시 메서드까지 지정한다. 클래스 단위("SeedContacts/SeedContacts")로
# 주면 SeedContacts 클래스의 다른 메서드(test_seedEmpty, test_seedLarge)까지 같이 돌아서,
# 마지막에 실행된 test_seedLarge 가 9개 픽스처를 5000개+김용훈 하나로 덮어써 버린다
# (실측: 김철수/박윤희 등이 사라져 이후 검색 테스트가 무더기로 깨졌다).
run_test SeedContacts "SeedContacts/SeedContacts/test_seed" "연락처 9개 시딩"

# ── 권한 상태 머신 ───────────────────────────────────────────────
# notDetermined → 온보딩 → 시스템 팝업 2단계 → 검색 화면
xcrun simctl privacy "$DEVICE_UDID" reset contacts "$BUNDLE_ID"
run_test UITests \
  "UITests/PermissionUITests/test_첫실행_온보딩_권한허용_검색화면" \
  "notDetermined → 온보딩 → 권한 허용(2단계) → 검색 화면"

# denied → PermissionDeniedView
xcrun simctl privacy "$DEVICE_UDID" revoke contacts "$BUNDLE_ID"
run_test UITests \
  "UITests/PermissionUITests/test_권한거부시_안내화면과_설정열기버튼" \
  "denied → 권한 안내 화면 + 설정 열기"

# authorized → 온보딩 스킵
xcrun simctl privacy "$DEVICE_UDID" grant contacts "$BUNDLE_ID"
run_test UITests \
  "UITests/PermissionUITests/test_권한있으면_온보딩_스킵하고_바로_검색화면" \
  "authorized → 온보딩 스킵, 바로 검색 화면"

# ── 검색 기능 ────────────────────────────────────────────────────
run_test UITests "UITests/SearchUITests" "초성 검색 / 상세 시트 / 로컬라이제이션"

# ── 로드 상태 전이 (스피너 억제 / 로드 중 타이핑 / 실패-재시도) ─────
run_test UITests "UITests/LoadStateUITests" "로드 실패-재시도 / 스피너 억제 / 로드 중 타이핑"

echo ""
echo "== 단위 테스트 (Swift Package) =="
swift test 2>&1 | grep -E "Test run with|Executed [0-9]+ tests|error:" | tail -3

echo ""
echo "✅ 검증 완료"
