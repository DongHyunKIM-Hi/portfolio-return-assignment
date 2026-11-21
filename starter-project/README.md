# 가상 포트폴리오 수익률 서비스 시작 프로젝트

- 과제 설명은 과제 저장소 최상위의 `README.md`(이하 과제 설명)를 먼저 읽어 주세요.
- 이 프로젝트에는 빌드 설정(Java 17, Spring Boot 4.1.1, Gradle, JPA, H2)과 실행 클래스만 있고 도메인 코드는 없습니다.
- 이 폴더 안의 파일이 제출 저장소의 최상위가 됩니다. 제출할 때 이 파일은 실행 방법과 직접 확인한 시나리오를 적은 제출 README로 바꿔 써 주세요.

## 실행

```bash
./gradlew bootRun
```

- 포트는 `8080`입니다.
- 가상 시세 서버를 `9091` 포트로 먼저 실행해 두어야 합니다(과제 저장소의 `compose.yaml`).
- 시세 서버 주소는 환경변수 `PRICE_BASE_URL`로 바꿀 수 있게 구현해 주세요. 기본값은 `http://localhost:9091`입니다.

## 상품 데이터

과제 저장소의 `data/products.csv`를 이 폴더의 `data/products.csv`로 복사해서 사용해 주세요. **이 파일은 수정하지 않습니다.**

## 막혔을 때 확인할 것

| 증상 | 확인할 것 |
|---|---|
| 빌드가 안 되거나 문법 오류처럼 보임 | `java -version`이 17인지, IntelliJ의 Gradle JVM 설정이 17인지 확인해 주세요. |
| `./gradlew: permission denied` | 저장소를 zip으로 받으면 실행 권한이 빠질 수 있습니다. `chmod +x gradlew` 후 다시 실행해 주세요. Windows는 `gradlew.bat`을 씁니다. |
| 서버가 뜨다가 바로 죽음 | `8080` 포트를 다른 프로그램이 쓰고 있는지 확인해 주세요. |
| 시세를 계속 받지 못함 | Docker가 실행 중인지, `docker compose up`을 했는지, 브라우저에서 `http://localhost:9091/swagger-ui.html`이 열리는지 순서대로 확인해 주세요. 토큰이 만료(120초)되지 않았는지도 확인 대상입니다. |
| 상품 조회가 빈 목록임 | `data/products.csv`를 이 폴더로 복사했는지 확인해 주세요. |

## 제출 전 확인 사항

- [ ] `docs/assumptions.md`, `docs/api.md`를 작성했다 (과제 저장소의 `docs-template/`에 있는 파일을 복사해서 시작)
- [ ] `./gradlew bootRun`이 정상적으로 실행된다
- [ ] 과제 저장소의 `requests.http` 요청 결과가 과제 설명의 기대 결과와 같다
