# 과제 3. 가상 포트폴리오 수익률 서비스 — 시작 프로젝트

과제 설명은 상위 폴더의 `README.md`(가이드)를 먼저 읽어 주세요. 이 프로젝트는 빌드 설정(Java 17, Spring Boot 4.1.1, Gradle, JPA + H2)과 실행 진입점만 있는 빈 프로젝트입니다. 도메인 코드는 없습니다 — 여러분이 처음부터 만듭니다.

## 실행

```
./gradlew bootRun
```

기본 포트는 `8080`입니다. 가상 시세 서버(`../compose.yaml`)가 `9091`에서 먼저 떠 있어야 합니다.

## 시세 서버 주소 바꾸기

```
PRICE_BASE_URL=http://localhost:9092 ./gradlew bootRun
```

기본값은 `http://localhost:9091`입니다.

## 상품 데이터

`../data/products.csv`를 이 프로젝트의 루트(`data/products.csv`)로 복사해서 사용하세요. **수정하지 않습니다.**

## 제출 전 체크

- [ ] `docs/assumptions.md`, `docs/api.md`를 채웠는가 (`../docs-template/`를 복사해서 시작하세요)
- [ ] `./gradlew bootRun`이 정상적으로 실행되는가
- [ ] `requests.http`의 시나리오가 가이드의 기대 결과와 같은가
