# 개선안: 인라인 블록 편집 (WYSIWYG 스타일 퀵편집)

- 상태: 구현 진행 (브랜치 `feat/inline-block-edit`)
- 목적: 렌더 화면에서 **블록 단위로 소스를 즉석 편집** — vscode를 열지 않고 오타·문구·표를 바로 고친다.
- 원칙: mdwatch의 정체성("AI가 문서를 고치는 걸 지켜본다")과 충돌하지 않게, **git diff를 해치지 않는 국소 편집**만 한다. 전체 재직렬화(WYSIWYG)는 하지 않는다.

---

## 왜 mdwatch에 맞는가 (기존 자산 재사용)

| 필요한 것 | mdwatch 현황 | 위치 |
|---|---|---|
| 블록 시작줄 매핑 | `data-line` = **원본 파일 줄번호** (전처리 시 `\n` 패딩으로 줄수 보존) | `renderContent` 339–345 |
| 블록 `[시작,끝]` 범위 | **클라이언트가 이미 계산** (`end = 다음 블록 data-line − 1`) | SSE 핸들러 756–765 |
| 쓰기→재렌더 루프 | `fs.watch`→`diffLines`→SSE→`/__content` 교체+하이라이트 | 825–835, 730–800 |
| POST 엔드포인트 패턴 | `/__share`가 이미 POST+JSON+크기캡 | 906–918 |

→ 추가할 것은 사실상 **쓰기 경로(③)** 하나. 렌더·범위계산·재렌더·하이라이트는 그대로 재사용된다.

## 설계

```
[편집 시작] 블록 더블클릭 → [start,end] 범위 계산(기존 로직 재사용)
   → GET /__source 로 원본 줄 슬라이스 조회 → <textarea>에 표시
   → 즉시 localStorage 초안 저장 (SSE 와이프·크래시 대비)
[저장] POST /__edit {file, start, end, baseText, newText}
   → 서버가 현재 파일에서 baseText 재탐색:
       · 찾음(줄 밀림 자동 흡수) → 그 자리 치환 → 파일 write → (기존) watch→SSE→재렌더
       · 못 찾음 → 409 conflict + 현재 블록 텍스트
[충돌] textarea 유지 + 현재 파일 블록 나란히 표시 + [덮어쓰기]/[취소]
```

### 핵심 결정

1. **줄번호가 아니라 내용으로 재탐색** — `baseText`(편집 시작 시점의 블록 원본)를 현재 파일에서 다시 찾는다. AI가 다른 곳을 고쳐 블록이 밀려도 자동으로 새 위치에 적용되고, **그 블록 자체가 바뀐 경우에만** 충돌로 잡힌다. (줄번호 splice의 "위에 줄 추가되면 어긋남" 문제 제거)
2. **라인 정렬 매칭** — `baseText` 매치는 줄 시작·끝 경계에서만 인정(부분 문자열 오매치 방지).
3. **편집 내용 3중 보존** — ① textarea 유지(거부돼도 안 지움) ② 충돌 시 나란히 비교 UI ③ localStorage 초안(편집 **시작 시점**부터 저장 → SSE 와이프/브라우저 크래시에도 복원).
4. **SSE 에코 처리** — 편집기가 열려 있는 동안 들어온 SSE 리로드는 **큐잉**했다가 편집기를 닫을 때 적용한다(열린 편집기 DOM·입력이 innerHTML 교체로 소멸하는 것 방지).
5. **embed 파일 가드** — `<!--embeds-->`/`{{$name}}`가 있는 파일은 `processEmbeds`가 줄수를 안 맞춰 data-line이 어긋나므로 **인라인 편집 비활성**(서버가 409/`editable:false`로 응답).
6. **입도(Phase 1)** — 최상위 블록 단위(문단·표·리스트·인용·코드펜스 통째). 표 셀 단위 편집은 Phase 2.

## 신규 엔드포인트

| 메서드 | 경로 | 용도 |
|---|---|---|
| GET | `/__source?file=&start=&end=` | 블록 원본 줄 슬라이스 조회 → `{text, start, end, editable}` |
| POST | `/__edit` | `{file, start, end, baseText, newText}` → 200 `{ok}` / 409 `{reason, current}` |

## 신규/변경 함수 (mdwatch.js)

- `hasEmbeds(content)` — embed 사용 감지(가드)
- `sliceLines(content, start, end)` — 1-indexed 줄 슬라이스(후행 빈 줄 트림)
- `relocateAndReplace(content, baseText, newText, hintLine)` — 내용 재탐색 치환(핵심 정합성 로직)
- `isEditableFile(absPath)` — `.md/.markdown` 한정(쓰기 가드)
- 클라이언트: `openEditor`·`applyReload`(SSE 큐잉)·초안 stash/restore·충돌 UI

## 테스트 (신규 — 기존 자동화 테스트 0개)

`node:test`(무의존성) 기반 `test/mdwatch.test.js`:
- 순수 로직: `diffLines`, `fileToUrl`/`urlToFile`(traversal 방어 포함), `hasEmbeds`, `sliceLines`, `relocateAndReplace`(위치 불변·줄밀림 흡수·블록변경 충돌·중복 최근접·미발견) , `renderContent` data-line 계약
- 통합(in-process `server.listen(0)`): `/__ping`, `/__source`, `/__edit` happy·conflict·embed거부
- 실행: `npm test` → `node --test`

## 알려진 제약 / 후속

- 표 셀 단위 편집(Phase 2). 현재는 표 통째 소스 편집.
- 클라이언트 UI(더블클릭·충돌 패널)는 자동화 테스트 대상 밖 → 수동 검증 체크리스트로 보완.
- embed 파일은 편집 비활성(뷰만).
