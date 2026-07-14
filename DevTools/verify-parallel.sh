#!/bin/bash
# 4단계 시뮬레이터 검증 — 4개 디바이스에 병렬 샤딩.
#
# 핵심 아이디어: xcodebuild 는 build-for-testing 으로 "한 번만" 빌드하고,
# 그 산출물(.xctestrun)을 test-without-building 으로 여러 디바이스에 뿌린다.
# simctl 상태(권한/외형/글자크기/연락처)는 디바이스별로 완전히 격리되므로
# 샤드끼리 서로 간섭하지 않는다.
#
#     ./DevTools/verify-parallel.sh
#
# 순차 버전(DevTools/verify.sh)과 검증 항목이 겹치지 않는다 — 이 스크립트는
# "여러 디바이스에서만 의미 있는" 항목(뷰포트/다크모드/Dynamic Type/스케일/재설치/limited)을 맡는다.
#
# ⚠️ SeedContacts 는 각 디바이스의 연락처를 전부 지우고 픽스처로 덮어쓴다. 실기기 금지.

set -uo pipefail  # -e 는 안 쓴다. 샤드 하나가 실패해도 나머지 샤드 결과를 봐야 한다.

BUNDLE_ID="com.kilga.InitialConsonantFinder"
DERIVED=".build/xcode"
LOGDIR="/tmp/verify-parallel-$$"
mkdir -p "$LOGDIR"

# 샤드별 디바이스. macOS 시스템 bash 는 3.2 라 연관 배열(declare -A)이 없다 — 평범한 변수로 대체.
#
# ⚠️ 이름만으로 디바이스를 지칭하면 안 된다. 이 머신엔 iOS 26.4 / 26.5 런타임이 둘 다 깔려 있어서
# "iPhone 17" 같은 이름이 UDID 가 다른 두 시뮬레이터에 동시에 존재한다(`simctl list devices` 로 확인).
# `simctl <verb> "이름"` 과 `xcodebuild -destination name=...` 이 이 모호함을 각자 다르게 풀면
# — 실제로 그랬다 — simctl 로 재설치한 디바이스와 xcodebuild 가 테스트를 돌리는 디바이스가
# 서로 다른 물리 시뮬레이터가 되어 "재설치했는데 여전히 authorized" 같은 유령 실패가 난다.
# 그래서 이름을 부팅된 인스턴스의 **UDID** 로 한 번에 확정해서 이후 전부 UDID 로만 다룬다.
NAME_PERM="iPhone 17"
NAME_LAYOUT_LIGHT="iPhone SE (3rd generation)"
NAME_LAYOUT_DARK="iPhone 17 Pro Max"
NAME_SCALE="iPhone Air"

echo "== 디바이스 준비 =="
for name in "$NAME_PERM" "$NAME_LAYOUT_LIGHT" "$NAME_LAYOUT_DARK" "$NAME_SCALE"; do
  xcrun simctl boot "$name" 2>/dev/null || true
done
for name in "$NAME_PERM" "$NAME_LAYOUT_LIGHT" "$NAME_LAYOUT_DARK" "$NAME_SCALE"; do
  xcrun simctl bootstatus "$name" -b >/dev/null 2>&1 || true
done

# 이름 → 부팅된 인스턴스의 UDID. 동명 디바이스가 여럿이어도 "Booted" 상태는 유일하다.
resolve_udid() {
  local name="$1"
  xcrun simctl list devices booted -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
name = sys.argv[1]
for devices in data['devices'].values():
    for d in devices:
        if d['name'] == name and d['state'] == 'Booted':
            print(d['udid']); sys.exit(0)
sys.exit(1)
" "$name"
}

DEVICE_PERM=$(resolve_udid "$NAME_PERM")
DEVICE_LAYOUT_LIGHT=$(resolve_udid "$NAME_LAYOUT_LIGHT")
DEVICE_LAYOUT_DARK=$(resolve_udid "$NAME_LAYOUT_DARK")
DEVICE_SCALE=$(resolve_udid "$NAME_SCALE")
echo "  perm=$DEVICE_PERM ($NAME_PERM)"
echo "  layout_light=$DEVICE_LAYOUT_LIGHT ($NAME_LAYOUT_LIGHT)"
echo "  layout_dark=$DEVICE_LAYOUT_DARK ($NAME_LAYOUT_DARK)"
echo "  scale=$DEVICE_SCALE ($NAME_SCALE)"

echo "== 프로젝트 생성 =="
xcodegen generate >/dev/null

echo "== 1회 빌드 (build-for-testing) =="
xcodebuild build-for-testing \
  -project InitialConsonantFinder.xcodeproj -scheme UITests \
  -destination "platform=iOS Simulator,id=$DEVICE_PERM" \
  -derivedDataPath "$DERIVED" 2>&1 | tail -3
xcodebuild build-for-testing \
  -project InitialConsonantFinder.xcodeproj -scheme SeedContacts \
  -destination "platform=iOS Simulator,id=$DEVICE_PERM" \
  -derivedDataPath "$DERIVED" 2>&1 | tail -3

UIRUN=$(find "$DERIVED" -name "UITests*.xctestrun" | head -1)
SEEDRUN=$(find "$DERIVED" -name "SeedContacts*.xctestrun" | head -1)

run_shard() {
  local shard="$1" xctestrun="$2" device_udid="$3" only="$4" logfile="$5"
  {
    echo "▶ [$shard] $device_udid — $only"
    xcodebuild test-without-building \
      -xctestrun "$xctestrun" \
      -destination "platform=iOS Simulator,id=$device_udid" \
      -only-testing:"$only" 2>&1 | grep -E "^Test Case .*(passed|failed)|failed - |^\*\* TEST"
  } > "$logfile" 2>&1
}

echo ""
echo "== 샤드 준비: 권한·연락처·외형 세팅 =="

# perm 샤드: 재설치 시나리오 + .limited + denied + authorized 스킵.
#
# ⚠️ 실측으로 확인한 것: `simctl uninstall` + `install` 은 그 디바이스에서 **이전에
# xcodebuild test-without-building 세션이 한 번이라도 돈 적이 있으면** 더 이상 TCC 를
# 리셋하지 않는다 — 재설치해도 여전히 authorized 로 남는다. (Xcode 온디바이스 테스트 에이전트가
# 뭔가 pairing/daemon 상태를 남겨서, 단순 uninstall 이 "진짜 삭제" 로 처리되지 않는 것으로 추정.)
# 이 디바이스는 이미 SeedContacts 를 여러 번 xcodebuild 로 돌린 상태라 uninstall→install 로는
# 더 이상 안전하게 재현이 안 된다.
#
# 실사용자는 xcodebuild test 를 거칠 일이 없으니 이건 앱 버그가 아니라 테스트 도구의 한계다.
# "삭제 후 재설치" 가 실제로 의미하는 건 **TCC 초기화** 뿐이고(이 앱은 UserDefaults 등 다른 영속
# 상태가 없다 — Sources/ContactFinder/ContactStore.swift 확인됨), `simctl privacy reset` 이 그
# 효과를 더 안정적으로 낸다. verify.sh 의 동일 테스트도 이 방식으로 이미 통과하고 있다.
xcrun simctl privacy "$DEVICE_PERM" reset contacts "$BUNDLE_ID"

echo ""
echo "== 재설치(≈privacy reset) 검증 =="
run_shard perm_reinstall "$UIRUN" "$DEVICE_PERM" \
  "UITests/PermissionUITests/test_첫실행_온보딩_권한허용_검색화면" "$LOGDIR/01-perm-reinstall.log"

# perm_limited 가 피커에서 고를 연락처(김용훈/이은호/박윤희)가 필요하다. 위 테스트가 끝나
# authorized 로 전이된 뒤에 시딩한다(seed 는 권한이 있어야 CNSaveRequest 가 통과한다).
run_shard seed_perm "$SEEDRUN" "$DEVICE_PERM" \
  "SeedContacts/SeedContacts/test_seed" "$LOGDIR/00-seed-perm.log"

# layout 샤드 둘 다 연락처 시딩 + 권한 부여 필요.
xcrun simctl privacy "$DEVICE_LAYOUT_LIGHT" grant contacts "$BUNDLE_ID"
xcrun simctl privacy "$DEVICE_LAYOUT_DARK" grant contacts "$BUNDLE_ID"
run_shard seed_light "$SEEDRUN" "$DEVICE_LAYOUT_LIGHT" \
  "SeedContacts/SeedContacts/test_seed" "$LOGDIR/00-seed-light.log"
run_shard seed_dark "$SEEDRUN" "$DEVICE_LAYOUT_DARK" \
  "SeedContacts/SeedContacts/test_seed" "$LOGDIR/00-seed-dark.log"
wait

xcrun simctl ui "$DEVICE_LAYOUT_LIGHT" appearance light
xcrun simctl ui "$DEVICE_LAYOUT_LIGHT" content_size large   # 표준 크기
xcrun simctl ui "$DEVICE_LAYOUT_DARK" appearance dark
xcrun simctl ui "$DEVICE_LAYOUT_DARK" content_size accessibility-extra-extra-extra-large  # .accessibility5

# scale 샤드: 0개 / 5000개는 순차로 (같은 디바이스, 연락처 상태가 달라야 함).
xcrun simctl privacy "$DEVICE_SCALE" grant contacts "$BUNDLE_ID"

echo ""
echo "== 병렬 실행: layout-light(SE) / layout-dark(ProMax) =="
run_shard layout_light "$UIRUN" "$DEVICE_LAYOUT_LIGHT" \
  "UITests/AccessibilityUITests" "$LOGDIR/02-layout-light-se.log" &
P2=$!
run_shard layout_dark "$UIRUN" "$DEVICE_LAYOUT_DARK" \
  "UITests/AccessibilityUITests" "$LOGDIR/03-layout-dark-promax.log" &
P3=$!
wait $P2 $P3

# perm 샤드 후속 — 상태 전이가 필요해서 순차. (denied/limited/authorized 는 서로 다른 TCC 상태라
# 병렬로 돌리면 같은 디바이스의 권한을 동시에 바꾸게 되어 레이스가 난다.)
xcrun simctl privacy "$DEVICE_PERM" revoke contacts "$BUNDLE_ID"
run_shard perm_denied "$UIRUN" "$DEVICE_PERM" \
  "UITests/PermissionUITests/test_권한거부시_안내화면과_설정열기버튼" "$LOGDIR/04-perm-denied.log"

xcrun simctl privacy "$DEVICE_PERM" reset contacts "$BUNDLE_ID"
run_shard perm_limited "$UIRUN" "$DEVICE_PERM" \
  "UITests/PermissionUITests/test_limited_권한선택시_선택한_연락처만_보인다" "$LOGDIR/05-perm-limited.log"

xcrun simctl privacy "$DEVICE_PERM" grant contacts "$BUNDLE_ID"
run_shard perm_skip "$UIRUN" "$DEVICE_PERM" \
  "UITests/PermissionUITests/test_권한있으면_온보딩_스킵하고_바로_검색화면" "$LOGDIR/06-perm-skip.log"

echo ""
echo "== 스케일: 연락처 0개 → 5000개 (같은 디바이스, 순차) =="
run_shard seed_empty "$SEEDRUN" "$DEVICE_SCALE" \
  "SeedContacts/SeedContacts/test_seedEmpty" "$LOGDIR/07-seed-empty.log"
run_shard scale_empty "$UIRUN" "$DEVICE_SCALE" \
  "UITests/ScaleUITests/test_연락처0개_크래시없이_빈리스트" "$LOGDIR/08-scale-empty.log"

run_shard seed_large "$SEEDRUN" "$DEVICE_SCALE" \
  "SeedContacts/SeedContacts/test_seedLarge" "$LOGDIR/09-seed-large.log"
run_shard scale_large "$UIRUN" "$DEVICE_SCALE" \
  "UITests/ScaleUITests/test_연락처5000개_로드되고_검색된다" "$LOGDIR/10-scale-large.log"

echo ""
echo "================ 결과 ================"
cat "$LOGDIR"/*.log
echo "========================================"

FAILS=$(grep -lE "failed - |TEST EXECUTE FAILED|TEST FAILED" "$LOGDIR"/*.log 2>/dev/null | wc -l | tr -d ' ')
if [ "$FAILS" -eq 0 ]; then
  echo "✅ 병렬 검증 완료 — 전부 통과 (로그: $LOGDIR)"
else
  # ⚠️ macOS 시스템 bash(3.2) 는 비 UTF-8 로케일에서 "$VAR개" 처럼 변수 뒤에 한글이 바로 붙으면
  # 변수명 파싱이 깨져 "unbound variable" 오류를 낸다. 반드시 ${VAR} 로 중괄호를 쳐야 한다.
  echo "❌ ${FAILS}개 샤드 실패 — 로그: $LOGDIR"
  exit 1
fi
