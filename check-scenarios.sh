#!/usr/bin/env bash
# 시나리오 자동 확인 (S1~S11)
#
# 사용법
#   1) 가상 시세 서버 실행:  docker compose up -d            (9091)
#   2) 구현한 서버 실행:      ./gradlew bootRun               (8080)
#   3) bash check-scenarios.sh
#
# - 실행할 때마다 포트폴리오 이름에 임의 값을 붙이므로 서버를 재시작하지 않고 몇 번이든 돌릴 수 있습니다.
# - 시세 갱신 주기가 30초라, 시세를 고정한 뒤 한 주기를 기다렸다가 담습니다. 그래서 전체가 1~2분쯤 걸립니다.
# - 시세 서버의 시나리오 재현 API(/sandbox)를 사용합니다. (README 7장)
# - 마지막에 /sandbox/reset으로 시세 서버를 처음 상태(장애 없음·고정 해제)로 되돌립니다.
# - macOS 기본 bash 3.2에서도 돌아가도록 명령 결과는 먼저 변수에 담아 비교합니다.

S=${SERVER_URL:-http://localhost:8080}
P=${PRICE_URL:-http://localhost:9091}
H='Content-Type: application/json'

res1=""; res2=""; res3=""; res4=""; res5=""; res6=""
res7=""; res8=""; res9=""; res10=""; res11=""
PASS=0; FAIL=0

ok(){ eval "res$1=\"\$(printf '\033[32m[통과]\033[0m S%-3s %s' \"$1\" \"$2\")\""; PASS=$((PASS+1)); }
no(){ eval "res$1=\"\$(printf '\033[31m[실패]\033[0m S%-3s %s — %s' \"$1\" \"$2\" \"$3\")\""; FAIL=$((FAIL+1)); }

code(){ curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$@" | tr -d '\r'; }
# 상품 조회(검색어는 URL 인코딩해서 보냄: 한글·대소문자 검증용)
prodq(){ curl -s -G --max-time 20 "$S/api/v1/products" --data-urlencode "query=$1" --data-urlencode "size=${2:-100}" | tr -d '\r'; }
# totalElements 값만 꺼낸다
total(){ printf '%s' "$1" | tr -d '\r' | grep -o '"totalElements":[0-9]*' | head -1 | sed 's/.*://'; }
# JSON에서 "키":숫자 형태의 값을 꺼낸다 (정수·소수 모두)
jnum(){ printf '%s' "$1" | tr -d '\r' | grep -o "\"$2\":-\{0,1\}[0-9.]*" | head -1 | sed 's/.*://'; }
# 시세 서버 /sandbox 호출
pfix(){ curl -s -o /dev/null -X POST "$P/sandbox/prices" -H "$H" -d "$1"; }
pserver(){ curl -s -o /dev/null -X POST "$P/sandbox/server" -H "$H" -d "{\"case\":\"$1\"}"; }
# 값들을 한 줄에 하나씩 받아 오름/내림차순인지 확인 (문자열 비교: yyyy-MM-dd와 한 자리 숫자 모두 정렬이 맞음)
mono(){ awk -v d="$1" 'NR>1{ if(d=="asc" && ($0"")<(p"")) b=1; if(d=="desc" && ($0"")>(p"")) b=1 } {p=$0} END{ if(NR<2) b=1; exit b+0 }'; }
# 포트폴리오 상세의 summary.totalValue가 기대값이 될 때까지 최대 $3초 기다린다 (시세 반영 대기)
wait_value(){ # $1=id $2=expected $3=maxsec  → 반영까지 걸린 초를 echo, 실패하면 -1
  local t=0 body
  while [ "$t" -lt "$3" ]; do
    body=$(curl -s --max-time 10 "$S/api/v1/portfolios/$1" | tr -d '\r')
    if printf '%s' "$body" | grep -q "\"totalValue\":$2,"; then echo "$t"; return 0; fi
    sleep 3; t=$((t+3))
  done
  echo "-1"; return 1
}

echo "서버($S)와 가상 시세 서버($P) 연결을 확인합니다..."
pingc=$(code "$S/api/v1/products?page=0&size=1")
[ "$pingc" = "000" ] && { echo "구현한 서버에 연결할 수 없습니다. ./gradlew bootRun 후 다시 실행해 주세요."; exit 1; }
resetc=$(code -X POST "$P/sandbox/reset")
[ "$resetc" = "000" ] && { echo "가상 시세 서버에 연결할 수 없습니다. docker compose up -d 후 다시 실행해 주세요."; exit 1; }

R=$RANDOM$RANDOM

# ---- 0) 시세를 고정한다. (reset은 위에서 이미 호출: 항상 맨 앞) ----
# 장애 없이·값 고정 상태로 두고, 원화 상품 A001=1000, 달러 상품 A052=10.02, 환율 1350.25로 멈춘다.
pserver STABLE
pfix '{"prices":{"A001":1000,"A052":10.02}}'
curl -s -o /dev/null -X POST "$P/sandbox/fx" -H "$H" -d '{"rate":1350.25}'

# ================= S1~S4: 상품 조회 (시세와 무관, 고정이 반영되길 기다리는 동안 먼저 확인) =================

# ---- S1 상품 검색 (코드·이름·영문명 부분 일치, 대소문자 무시) ----
# A001 = "가상 성장 채권 01" / "Virtual Growth Bond 01" (중복 없는 코드)
s1=ok
prodq "A001"   | grep -q '"code":"A001"' || s1=no   # 코드
prodq "a001"   | grep -q '"code":"A001"' || s1=no   # 코드 대소문자 무시
prodq "growth" | grep -q '"code":"A001"' || s1=no   # 영문명 대소문자 무시
prodq "성장"   | grep -q '"code":"A001"' || s1=no   # 한글 이름
if [ "$s1" = ok ]; then ok 1 "상품 검색 (코드·이름·영문명 부분 일치, 대소문자 무시)"
else no 1 "상품 검색" "A001을 코드/영문명(growth)/한글이름(성장)으로 찾지 못했습니다"; fi

# ---- S2 상품 정렬 (상장일·위험등급 오름/내림차순, 이름 정렬) ----
s2=ok
ldA=$(curl -s "$S/api/v1/products?sort=listedDate,asc&size=100" | tr -d '\r' | grep -o '"listedDate":"[^"]*"' | sed 's/.*:"//;s/"$//')
ldD=$(curl -s "$S/api/v1/products?sort=listedDate,desc&size=100" | tr -d '\r' | grep -o '"listedDate":"[^"]*"' | sed 's/.*:"//;s/"$//')
rlA=$(curl -s "$S/api/v1/products?sort=riskLevel,asc&size=100" | tr -d '\r' | grep -oE '"riskLevel":[0-9]+' | sed 's/.*://')
naA=$(curl -s "$S/api/v1/products?sort=name,asc&size=1"  | tr -d '\r' | grep -o '"code":"[^"]*"' | head -1)
naD=$(curl -s "$S/api/v1/products?sort=name,desc&size=1" | tr -d '\r' | grep -o '"code":"[^"]*"' | head -1)
printf '%s\n' "$ldA" | mono asc  || s2=no   # 상장일 오름차순
printf '%s\n' "$ldD" | mono desc || s2=no   # 상장일 내림차순
printf '%s\n' "$rlA" | mono asc  || s2=no   # 위험등급 오름차순(빈 값 제외)
{ [ -n "$naA" ] && [ "$naA" != "$naD" ]; } || s2=no  # 이름 정렬은 방향에 따라 순서가 달라짐
if [ "$s2" = ok ]; then ok 2 "상품 정렬 (상장일·위험등급 오름/내림차순, 이름 정렬)"
else no 2 "상품 정렬" "정렬 결과 순서가 기대와 다릅니다"; fi

# ---- S3 상품 필터 (유형·통화·AND 조건, 잘못된 값은 400 INVALID_REQUEST) ----
s3=ok; detail3=""
check_count(){ # $1=쿼리 $2=기대건수
  local raw t
  raw=$(curl -s "$S/api/v1/products?$1&page=0&size=1")
  t=$(total "$raw")
  [ "$t" = "$2" ] || { s3=no; detail3="$detail3 $1=$t(기대 $2)"; }
}
check_count "type=ETF"  55
check_count "type=FUND" 40
check_count "type=BOND" 25
check_count "currency=KRW" 80
check_count "currency=USD" 40
check_count "type=ETF&currency=KRW" 35   # AND
check_count "type=ETF&currency=USD" 20   # AND
for bad in "type=STOCK" "size=0"; do
  r=$(curl -s -w '\n%{http_code}' "$S/api/v1/products?$bad" | tr -d '\r')
  c=${r##*$'\n'}; b=${r%$'\n'*}
  { [ "$c" = "400" ] && printf '%s' "$b" | grep -q '"code":"INVALID_REQUEST"'; } || { s3=no; detail3="$detail3 $bad->$c"; }
done
if [ "$s3" = ok ]; then ok 3 "상품 필터 (유형·통화·AND, 잘못된 값 400 INVALID_REQUEST)"
else no 3 "상품 필터" "불일치:$detail3"; fi

# ---- S4 상품 데이터 정리 (중복 제거 120개, 통화 KRW/USD, 상장일 형식, 빈 위험등급 null) ----
s4=ok; detail4=""
rawAll=$(curl -s "$S/api/v1/products?page=0&size=1"); tAll=$(total "$rawAll")
[ "$tAll" = "120" ] || { s4=no; detail4="$detail4 고유상품수=$tAll(기대 120)"; }
rawDup=$(prodq "A012" 5); tDup=$(total "$rawDup")
[ "$tDup" = "1" ] || { s4=no; detail4="$detail4 중복코드A012=$tDup(기대 1)"; }
rawKRW=$(curl -s "$S/api/v1/products?currency=KRW&size=1"); tKRW=$(total "$rawKRW")
rawUSD=$(curl -s "$S/api/v1/products?currency=USD&size=1"); tUSD=$(total "$rawUSD")
{ [ "$tKRW" = "80" ] && [ "$tUSD" = "40" ]; } || { s4=no; detail4="$detail4 통화 KRW=$tKRW/USD=$tUSD(기대 80/40)"; }
badDate=0
for pg in 0 1; do
  n=$(curl -s "$S/api/v1/products?size=100&page=$pg" | tr -d '\r' | grep -o '"listedDate":"[^"]*"' | sed 's/.*:"//;s/"$//' | grep -vcE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
  badDate=$((badDate+n))
done
[ "$badDate" = "0" ] || { s4=no; detail4="$detail4 상장일형식오류=$badDate건"; }
prodq "A025" | grep -q '"code":"A025"[^}]*"riskLevel":null' || { s4=no; detail4="$detail4 A025위험등급!=null"; }
if [ "$s4" = ok ]; then ok 4 "상품 데이터 정리 (중복 제거 120개, 통화 통일, 상장일 형식, 빈 위험등급 null)"
else no 4 "상품 데이터 정리" "불일치:$detail4"; fi

# ---- 시세 고정이 서버에 반영될 때까지 기다린다 (최대 50초). 이후 시세 기반 시나리오를 확인한다 ----
echo "고정한 시세가 서버에 반영되기를 기다립니다..."
ready=0; t=0
while [ "$t" -lt 50 ]; do
  if prodq "A001" | grep -q '"currentPrice":1000}' && prodq "A052" | grep -q '"currentPrice":10.02}'; then ready=1; break; fi
  sleep 3; t=$((t+3))
done
[ "$ready" = 1 ] || echo "  (경고) 고정 시세가 아직 반영되지 않았습니다. S7·S8 결과가 어긋날 수 있습니다."

# ================= S5~S6: 포트폴리오 생성·조회·수정·삭제·목록 =================

# ---- S5 생성·조회·삭제·입력 검증 ----
s5=ok; detail5=""
cr=$(curl -s -w '\n%{http_code}' -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"S5-$R\",\"holdings\":[{\"code\":\"A001\",\"quantity\":1}]}" | tr -d '\r')
c=${cr##*$'\n'}; b=${cr%$'\n'*}
id5=$(jnum "$b" id)
{ [ "$c" = "201" ] && [ -n "$id5" ]; } || { s5=no; detail5="$detail5 생성=$c"; }
gc=$(code "$S/api/v1/portfolios/$id5")
[ "$gc" = "200" ] || { s5=no; detail5="$detail5 조회!=200($gc)"; }
dc=$(code -X DELETE "$S/api/v1/portfolios/$id5")
[ "$dc" = "204" ] || { s5=no; detail5="$detail5 삭제!=204($dc)"; }
dg=$(curl -s -w '\n%{http_code}' "$S/api/v1/portfolios/$id5" | tr -d '\r'); c=${dg##*$'\n'}; b=${dg%$'\n'*}
{ [ "$c" = "404" ] && printf '%s' "$b" | grep -q '"code":"PORTFOLIO_NOT_FOUND"'; } || { s5=no; detail5="$detail5 삭제후조회!=404($c)"; }
up=$(curl -s -w '\n%{http_code}' -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"S5u-$R\",\"holdings\":[{\"code\":\"ZZZ999\",\"quantity\":1}]}" | tr -d '\r')
c=${up##*$'\n'}; b=${up%$'\n'*}
{ [ "$c" = "400" ] && printf '%s' "$b" | grep -q '"code":"UNKNOWN_PRODUCT"'; } || { s5=no; detail5="$detail5 없는상품!=400/UNKNOWN_PRODUCT($c)"; }
qc=$(code -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"S5q-$R\",\"holdings\":[{\"code\":\"A001\",\"quantity\":0}]}")
[ "$qc" = "400" ] || { s5=no; detail5="$detail5 수량0!=400($qc)"; }
nc=$(code -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"holdings\":[{\"code\":\"A001\",\"quantity\":1}]}")
[ "$nc" = "400" ] || { s5=no; detail5="$detail5 이름없음!=400($nc)"; }
mc=$(code "$S/api/v1/portfolios/99999999")
[ "$mc" = "404" ] || { s5=no; detail5="$detail5 없는ID!=404($mc)"; }
if [ "$s5" = ok ]; then ok 5 "포트폴리오 생성 201·조회 200·삭제 204, 입력오류 400, 없는 ID 404"
else no 5 "포트폴리오 생성·조회·삭제·입력검증" "불일치:$detail5"; fi

# ---- S6 목록 (이름 검색·정렬·페이지) ----
s6=ok; detail6=""
curl -s -o /dev/null -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"ZQ$R-a\",\"holdings\":[{\"code\":\"A001\",\"quantity\":1}]}"
curl -s -o /dev/null -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"ZQ$R-b\",\"holdings\":[{\"code\":\"A001\",\"quantity\":1}]}"
lq=$(curl -s -G "$S/api/v1/portfolios" --data-urlencode "query=ZQ$R" --data-urlencode "size=20")
nq=$(total "$lq")
[ "$nq" = "2" ] || { s6=no; detail6="$detail6 이름검색건수=$nq(기대 2)"; }
first=$(curl -s -G "$S/api/v1/portfolios" --data-urlencode "query=ZQ$R" --data-urlencode "sort=name,asc" | tr -d '\r' | grep -o '"name":"[^"]*"' | head -1)
printf '%s' "$first" | grep -q -- "-a\"" || { s6=no; detail6="$detail6 이름정렬 첫항목=$first"; }
pg=$(curl -s -G "$S/api/v1/portfolios" --data-urlencode "query=ZQ$R" --data-urlencode "size=1" --data-urlencode "page=0")
tp=$(total "$pg")
{ [ "$tp" = "2" ] && printf '%s' "$pg" | grep -q '"totalPages":2'; } || { s6=no; detail6="$detail6 페이지 totalElements=$tp/totalPages"; }
if [ "$s6" = ok ]; then ok 6 "포트폴리오 목록 (이름 검색·정렬·페이지)"
else no 6 "포트폴리오 목록" "불일치:$detail6"; fi

# ================= S7~S9: 매입가 고정 · 평가 계산 · 주기 갱신 =================
# 고정한 시세로 포트폴리오를 만들고(매입가 결정), 시세를 바꾼 뒤 한 주기 기다려(갱신) 결과를 본다.

# 원화 포트폴리오(S7): A001 10주, 매입가 1000
r7=$(curl -s -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"S7-$R\",\"holdings\":[{\"code\":\"A001\",\"quantity\":10}]}")
id7=$(jnum "$r7" id)
# 달러 포트폴리오(S8): A052 4주, 매입가 10.02 (환율 1350.25 고정)
r8=$(curl -s -X POST "$S/api/v1/portfolios" -H "$H" -d "{\"name\":\"S8-$R\",\"holdings\":[{\"code\":\"A052\",\"quantity\":4}]}")
id8=$(jnum "$r8" id)

# 시세 변경: A001 1000->2000, A052 10.02->10.50 (환율은 그대로)
pfix '{"prices":{"A001":2000,"A052":10.50}}'
echo "시세를 바꾸고 주기 갱신으로 반영되기를 기다립니다... (최대 45초)"
# S9: 바뀐 시세(원화 포트폴리오 totalValue 10*2000=20000)가 45초 안에 반영되는지
elapsed9=$(wait_value "$id7" 20000 45)
if [ "$elapsed9" != "-1" ]; then ok 9 "시세 주기 갱신 (바뀐 시세가 45초 안에 반영: ${elapsed9}초)"
else no 9 "시세 주기 갱신" "45초 안에 평가금액에 반영되지 않음 (id=$id7)"; fi

# S7: 매입가 고정 — 매입가·매입금액은 그대로, 현재가·평가금액만 바뀜
d7=$(curl -s "$S/api/v1/portfolios/$id7")
pp=$(jnum "$d7" purchasePrice); cp=$(jnum "$d7" currentPrice)
tc=$(jnum "$d7" totalCost);     tv=$(jnum "$d7" totalValue)
if [ "$pp" = "1000" ] && [ "$tc" = "10000" ] && [ "$cp" = "2000" ] && [ "$tv" = "20000" ]; then
  ok 7 "매입가 고정 (매입가 1000·매입금액 10000 그대로, 현재가 2000·평가금액 20000 변경)"
else no 7 "매입가 고정" "매입가=$pp 매입금액=$tc 현재가=$cp 평가금액=$tv (기대 1000/10000/2000/20000)"; fi

# S8: 평가 계산 — 달러 상품 버림·반올림 (totalCost 54118, totalValue 56710, profit 2592, returnRate 4.79)
d8=$(curl -s "$S/api/v1/portfolios/$id8")
tc8=$(jnum "$d8" totalCost); tv8=$(jnum "$d8" totalValue); pf8=$(jnum "$d8" profit); rr8=$(jnum "$d8" returnRate)
if [ "$tc8" = "54118" ] && [ "$tv8" = "56710" ] && [ "$pf8" = "2592" ] && [ "$rr8" = "4.79" ]; then
  ok 8 "평가 계산 (버림·반올림: 54118 / 56710 / 2592 / 4.79)"
else no 8 "평가 계산" "매입금액=$tc8 평가금액=$tv8 수익금=$pf8 수익률=$rr8 (기대 54118/56710/2592/4.79)"; fi

# ================= S10: 토큰 만료 =================
# (1) 토큰을 강제로 만료시켜도 시세 갱신이 이어지는지  (2) 시세를 가져올 때마다 토큰을 새로 발급받지 않는지
# (2) 재사용 판정: 지금까지 쌓인 호출 기록에서 PRICES 호출 여러 건이 같은 tokenPrefix(토큰)를 쓰면 재사용한 것이다.
log=$(curl -s "$P/sandbox/requests" | tr -d '\r')
prefixes=$(printf '%s' "$log" | grep -o '{"kind":"PRICES"[^}]*}' | grep -o '"tokenPrefix":"[^"]*"' | sed 's/.*:"//;s/"$//')
npr=$(printf '%s\n' "$prefixes" | grep -c .)
dup=$(printf '%s\n' "$prefixes" | sort | uniq -d | grep -c .)
reuse=no; { [ "$npr" -ge 2 ] && [ "$dup" -ge 1 ]; } && reuse=ok
# (1) 토큰 만료 후에도 갱신이 이어지는지: 만료시키고 시세를 또 바꿔 45초 안에 반영되는지 본다
curl -s -o /dev/null -X POST "$P/sandbox/tokens/expire"
pfix '{"prices":{"A001":3000}}'
echo "토큰을 만료시키고, 갱신이 이어지는지 확인합니다... (최대 45초)"
elapsed10=$(wait_value "$id7" 30000 45)
cont=no; [ "$elapsed10" != "-1" ] && cont=ok
if [ "$reuse" = ok ] && [ "$cont" = ok ]; then
  ok 10 "토큰 만료 (만료돼도 갱신 지속: ${elapsed10}초, 토큰 재사용: PRICES ${npr}건 중 같은 토큰 반복)"
else
  m=""
  [ "$cont" != ok ] && m="만료 후 갱신이 45초 안에 이어지지 않음"
  [ "$reuse" != ok ] && m="$m; 토큰 재사용 흔적 없음(PRICES ${npr}건, 중복 토큰 ${dup})"
  no 10 "토큰 만료" "$m"
fi

# ================= S11: 시세 서버 장애 =================
# 시세 서버를 항상 실패(503)로 두어도, 조회 API(상품·포트폴리오 상세·목록)는 5xx 없이 응답해야 한다.
pserver ALWAYS_FAIL
cPr=$(code "$S/api/v1/products?page=0&size=1")
cDe=$(code "$S/api/v1/portfolios/$id7")
cLi=$(code "$S/api/v1/portfolios?page=0&size=5")
is2xx(){ case "$1" in 2??) return 0;; *) return 1;; esac; }
if is2xx "$cPr" && is2xx "$cDe" && is2xx "$cLi"; then
  ok 11 "시세 서버 장애 (장애 중에도 상품·상세·목록 조회가 5xx 없이 응답: $cPr/$cDe/$cLi)"
else no 11 "시세 서버 장애" "조회 응답 상품=$cPr 상세=$cDe 목록=$cLi (5xx면 안 됨)"; fi

# 시세 서버를 처음 상태로 되돌린다 (장애 해제·고정 해제). 공유 서버라 끄지는 않는다.
curl -s -o /dev/null -X POST "$P/sandbox/reset"

# ================= 결과 =================
echo; echo "================ 시나리오 확인 결과 ================"
for i in 1 2 3 4 5 6 7 8 9 10 11; do eval "printf '%b\n' \"\$res$i\""; done
echo "===================================================="
echo "통과 $PASS / 11"
[ "$FAIL" -gt 0 ] && echo "실패한 시나리오는 README 10장의 시나리오 목록에서 해당 항목을 확인해 주세요."
exit 0
