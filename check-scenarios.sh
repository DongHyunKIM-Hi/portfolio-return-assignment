#!/usr/bin/env bash
# 시나리오 자동 확인 (S1~S8)
#
# 사용법
#   1) 가상 시세 서버 실행:  docker compose up -d            (9091)
#   2) 구현한 서버 실행:      ./gradlew bootRun               (8080)
#   3) bash check-scenarios.sh
#
# - 실행할 때마다 포트폴리오 이름에 임의 값을 붙이므로 서버를 재시작하지 않고 몇 번이든 돌릴 수 있습니다.
# - 시세 갱신 주기가 30초라, 시세를 고정한 뒤 한 주기를 기다렸다가 담습니다. 그래서 전체가 1~2분쯤 걸립니다.
# - 시세 서버의 시나리오 재현 API(/sandbox)를 사용합니다. (README 7장)
# - 마지막에 /sandbox/reset으로 시세 서버를 처음 상태(장애 없음, 고정 해제)로 되돌립니다.
# - macOS 기본 bash 3.2에서도 돌아가도록 명령 결과는 먼저 변수에 담아 비교합니다.

S=${SERVER_URL:-http://localhost:8080}
P=${PRICE_URL:-http://localhost:9091}
H='Content-Type: application/json'

res1=""; res2=""; res3=""; res4=""; res5=""; res6=""; res7=""; res8=""
PASS=0; FAIL=0

ok(){ eval "res$1=\"\$(printf '\033[32m[통과]\033[0m S%-3s %s' \"$1\" \"$2\")\""; PASS=$((PASS+1)); }
no(){ eval "res$1=\"\$(printf '\033[31m[실패]\033[0m S%-3s %s — %s' \"$1\" \"$2\" \"$3\")\""; FAIL=$((FAIL+1)); }

code(){ curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$@" | tr -d '\r'; }
body(){ curl -s --max-time 20 "$@" | tr -d '\r'; }
# JSON에서 "키":숫자 형태의 값을 꺼낸다 (정수, 소수 모두)
jnum(){ printf '%s' "$1" | tr -d '\r' | grep -o "\"$2\":-\{0,1\}[0-9.]*" | head -1 | sed 's/.*://'; }
# 배열 응답에서 특정 키가 몇 번 나오는지 센다
jcount(){ printf '%s' "$1" | tr -d '\r' | grep -o "\"$2\":" | wc -l | tr -d ' '; }
# 시세 서버 /sandbox 호출
pfix(){ curl -s -o /dev/null -X POST "$P/sandbox/prices" -H "$H" -d "$1"; }
pserver(){ curl -s -o /dev/null -X POST "$P/sandbox/server" -H "$H" -d "{\"case\":\"$1\"}"; }
# 값들을 한 줄에 하나씩 받아 오름차순인지 확인
mono_asc(){ awk 'NR>1{ if(($0"")<(p"")) b=1 } {p=$0} END{ if(NR<2) b=1; exit b+0 }'; }
# 포트폴리오 상세의 summary.totalValue가 기대값이 될 때까지 최대 $3초 기다린다 (시세 반영 대기)
wait_value(){ # $1=id $2=expected $3=maxsec  -> 반영까지 걸린 초를 echo, 실패하면 -1
  local t=0 b
  while [ "$t" -lt "$3" ]; do
    b=$(curl -s --max-time 10 "$S/api/v1/portfolios/$1" | tr -d '\r')
    if printf '%s' "$b" | grep -q "\"totalValue\":$2,"; then echo "$t"; return 0; fi
    sleep 3; t=$((t+3))
  done
  echo "-1"; return 1
}

echo "서버($S)와 가상 시세 서버($P) 연결을 확인합니다..."
pingc=$(code "$S/api/v1/products")
[ "$pingc" = "000" ] && { echo "구현한 서버에 연결할 수 없습니다. ./gradlew bootRun 후 다시 실행해 주세요."; exit 1; }
resetc=$(code -X POST "$P/sandbox/reset")
[ "$resetc" = "000" ] && { echo "가상 시세 서버에 연결할 수 없습니다. docker compose up -d 후 다시 실행해 주세요."; exit 1; }

R=$RANDOM$RANDOM

# ---- 0) 시세를 고정한다. (reset은 위에서 이미 호출: 항상 맨 앞) ----
# 실패하지 않는 상태로 두고 A001=10000, A002=20000으로 멈춘다.
pserver STABLE
pfix '{"prices":{"A001":10000,"A002":20000}}'

# ================= S1: 상품 목록 =================
plist=$(body "$S/api/v1/products")
pcount=$(jcount "$plist" code)
porder=$(printf '%s' "$plist" | grep -o '"code":"[^"]*"' | sed 's/.*:"//;s/"//' | mono_asc; echo $?)
if [ "$pcount" = "80" ] && [ "$porder" = "0" ]; then
  ok 1 "상품 목록" 
else
  no 1 "상품 목록" "상품 수 $pcount (기대 80), 코드 오름차순 여부 코드값 $porder"
fi

# ================= S2: 생성, 조회, 삭제, 입력 검증 =================
s2fail=""
created=$(body -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"검증 $R\",\"holdings\":[{\"code\":\"A001\",\"quantity\":1}]}")
cid=$(jnum "$created" id)
[ -z "$cid" ] && s2fail="$s2fail 생성 응답에 id 없음;"
c=$(code -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"검증 $R\",\"holdings\":[{\"code\":\"A001\",\"quantity\":1}]}")
[ "$c" = "201" ] || s2fail="$s2fail 생성 $c (기대 201);"
c=$(code "$S/api/v1/portfolios/$cid")
[ "$c" = "200" ] || s2fail="$s2fail 조회 $c (기대 200);"
c=$(code -X POST "$S/api/v1/portfolios" -H "$H" -d '{"name":"","holdings":[{"code":"A001","quantity":1}]}')
[ "$c" = "400" ] || s2fail="$s2fail 빈 이름 $c (기대 400);"
c=$(code -X POST "$S/api/v1/portfolios" -H "$H" -d '{"name":"x","holdings":[{"code":"A001","quantity":0}]}')
[ "$c" = "400" ] || s2fail="$s2fail 수량 0 $c (기대 400);"
c=$(code -X POST "$S/api/v1/portfolios" -H "$H" -d '{"name":"x","holdings":[{"code":"A001","quantity":1},{"code":"A001","quantity":2}]}')
[ "$c" = "400" ] || s2fail="$s2fail 코드 중복 $c (기대 400);"
unk=$(body -X POST "$S/api/v1/portfolios" -H "$H" -d '{"name":"x","holdings":[{"code":"ZZZZ","quantity":1}]}')
printf '%s' "$unk" | grep -q 'UNKNOWN_PRODUCT' || s2fail="$s2fail 없는 코드에 UNKNOWN_PRODUCT 아님;"
c=$(code "$S/api/v1/portfolios/99999999")
[ "$c" = "404" ] || s2fail="$s2fail 없는 ID $c (기대 404);"
c=$(code -X DELETE "$S/api/v1/portfolios/$cid")
[ "$c" = "204" ] || s2fail="$s2fail 삭제 $c (기대 204);"
if [ -z "$s2fail" ]; then ok 2 "포트폴리오 생성, 조회, 삭제, 입력 검증"; else no 2 "포트폴리오 생성, 조회, 삭제, 입력 검증" "$s2fail"; fi

# ================= S3: 목록 =================
listb=$(body "$S/api/v1/portfolios")
lcount=$(jcount "$listb" id)
if [ "$lcount" -ge 1 ] && printf '%s' "$listb" | grep -q '"totalValue"' && printf '%s' "$listb" | grep -q '"returnRate"'; then
  ok 3 "포트폴리오 목록"
else
  no 3 "포트폴리오 목록" "항목 수 $lcount, totalValue 또는 returnRate 누락"
fi

# ---- 고정한 시세가 서버에 반영될 때까지 기다린다 (최대 50초) ----
echo "고정한 시세가 서버에 반영되기를 기다립니다..."
t=0; ready=0
while [ "$t" -lt 50 ]; do
  pb=$(body "$S/api/v1/products")
  if printf '%s' "$pb" | grep -q '"code":"A001","name":"[^"]*","type":"[^"]*","currentPrice":10000'; then ready=1; break; fi
  sleep 3; t=$((t+3))
done
[ "$ready" = "1" ] || echo "  (시세 고정이 아직 반영되지 않았습니다. 이후 시나리오가 실패할 수 있습니다.)"

# ================= S4, S5, S6: 매입가 고정, 평가 계산, 주기 갱신 =================
# A001 10주를 10,000원에 담는다. 원가 100,000.
pf=$(body -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"평가 $R\",\"holdings\":[{\"code\":\"A001\",\"quantity\":10}]}")
pid=$(jnum "$pf" id)
cost=$(jnum "$pf" totalCost)
pp=$(jnum "$pf" purchasePrice)

# 시세를 11,000으로 바꾸고 한 주기를 기다린다. 평가금액 110,000이 되어야 한다.
pfix '{"prices":{"A001":11000}}'
echo "시세를 바꾼 뒤 갱신을 기다립니다 (최대 45초)..."
elapsed=$(wait_value "$pid" 110000 45)
after=$(body "$S/api/v1/portfolios/$pid")
pp2=$(jnum "$after" purchasePrice)
cost2=$(jnum "$after" totalCost)
val2=$(jnum "$after" totalValue)
prof2=$(jnum "$after" profit)
rate2=$(jnum "$after" returnRate)

if [ "$pp" = "10000" ] && [ "$pp2" = "10000" ] && [ "$cost" = "100000" ] && [ "$cost2" = "100000" ]; then
  ok 4 "매입가 고정"
else
  no 4 "매입가 고정" "매입가 $pp -> $pp2 (기대 10000 유지), 원가 $cost -> $cost2 (기대 100000 유지)"
fi

rate_ok=0
case "$rate2" in 10|10.0|10.00) rate_ok=1;; esac
if [ "$val2" = "110000" ] && [ "$prof2" = "10000" ] && [ "$rate_ok" = "1" ]; then
  ok 5 "평가 계산"
else
  no 5 "평가 계산" "평가금액 $val2 (기대 110000), 수익금 $prof2 (기대 10000), 수익률 $rate2 (기대 10.00)"
fi

if [ "$elapsed" != "-1" ]; then
  ok 6 "시세 주기 갱신 (${elapsed}초 만에 반영)"
else
  no 6 "시세 주기 갱신" "45초 안에 새 시세가 평가금액에 반영되지 않음"
fi

# ================= S7: 토큰 만료 =================
curl -s -o /dev/null -X POST "$P/sandbox/tokens/expire"
pfix '{"prices":{"A001":12000}}'
echo "토큰을 만료시킨 뒤 갱신이 이어지는지 기다립니다 (최대 45초)..."
e7=$(wait_value "$pid" 120000 45)
reqs=$(body "$P/sandbox/requests")
ntoken=$(printf '%s' "$reqs" | grep -o '"kind":"TOKEN"' | wc -l | tr -d ' ')
nprices=$(printf '%s' "$reqs" | grep -o '"kind":"PRICES"' | wc -l | tr -d ' ')
reuse=1
[ "$nprices" -gt 0 ] && [ $((ntoken * 2)) -gt "$nprices" ] && reuse=0
if [ "$e7" != "-1" ] && [ "$reuse" = "1" ]; then
  ok 7 "토큰 만료 (토큰 발급 ${ntoken}회, 시세 조회 ${nprices}회)"
elif [ "$e7" = "-1" ]; then
  no 7 "토큰 만료" "토큰이 만료된 뒤 45초 안에 시세 갱신이 이어지지 않음"
else
  no 7 "토큰 만료" "시세를 가져올 때마다 토큰을 새로 발급받고 있음 (토큰 ${ntoken}회, 시세 ${nprices}회)"
fi

# ================= S8: 시세 서버 장애 =================
pserver ALWAYS_FAIL
c1=$(code "$S/api/v1/products")
c2=$(code "$S/api/v1/portfolios")
c3=$(code "$S/api/v1/portfolios/$pid")
bad=""
for c in "$c1" "$c2" "$c3"; do
  case "$c" in 5*|000) bad="$bad $c";; esac
done
if [ -z "$bad" ]; then
  ok 8 "시세 서버 장애 중 조회 (상품 $c1, 목록 $c2, 상세 $c3)"
else
  no 8 "시세 서버 장애 중 조회" "5xx 또는 무응답:$bad (상품 $c1, 목록 $c2, 상세 $c3)"
fi

# ---- 정리: 시세 서버를 처음 상태로 되돌린다 ----
curl -s -o /dev/null -X POST "$P/sandbox/reset"
code -X DELETE "$S/api/v1/portfolios/$pid" > /dev/null

echo
echo "=============== 결과 ==============="
for i in 1 2 3 4 5 6 7 8; do eval "printf '%s\n' \"\$res$i\""; done
echo "===================================="
printf '통과 %d / 실패 %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
