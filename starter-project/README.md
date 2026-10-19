# 가상 포트폴리오 수익률 서비스 시작 프로젝트

- 과제 설명은 상위 폴더의 `README.md`를 먼저 읽어 주세요.
- 이 프로젝트에는 빌드 설정(Java 17, Spring Boot 4.1.1, Gradle, JPA, H2)과 실행 클래스만 있고 도메인 코드는 없습니다.
- 이 폴더를 제출 저장소의 루트로 사용합니다.

## 실행

```bash
./gradlew bootRun
```

- 포트는 `8080`입니다.
- 가상 시세 서버(`../compose.yaml`)를 `9091` 포트로 먼저 실행해 두어야 합니다.

## 시세 서버 주소 바꾸기

시세 서버 주소는 환경변수 `PRICE_BASE_URL`로 바꿀 수 있게 구현해 주세요. 기본값은 `http://localhost:9091`입니다.

```bash
PRICE_BASE_URL=http://localhost:9999 ./gradlew bootRun
```

## 상품 데이터

`../data/products.csv`를 이 폴더의 `data/products.csv`로 복사해서 사용해 주세요. **이 파일은 수정하지 않습니다.**

## 제출 전 확인 사항

- [ ] `docs/assumptions.md`, `docs/api.md`를 작성했다 (`../docs-template/`의 파일을 복사해서 시작)
- [ ] `./gradlew bootRun`이 정상적으로 실행된다
- [ ] `../requests.http`의 시나리오가 README의 기대 결과와 같다
