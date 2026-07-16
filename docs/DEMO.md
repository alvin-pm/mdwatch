# mdwatch 기능 데모

이 문서를 mdwatch로 열면 아래 기능들이 실제로 렌더링됩니다. 파일을 편집·저장하면 변경 줄이 하이라이트되는 것도 확인할 수 있습니다.

## 코드 Syntax Highlighting

언어를 명시한 펜스는 highlight.js로 색이 입혀집니다.

```sql
SELECT workplace_id, count(*) AS cnt
FROM outbound_order
WHERE created_at >= now() - interval '7 days'
GROUP BY 1 ORDER BY 2 DESC;
```

```python
def pickable(actual, picking, issue):
    return actual - picking - issue  # 주석
```

언어가 없는 블록은 평문 그대로 유지됩니다 — ASCII 다이어그램이 오염되지 않습니다. (깨지지 않는 다이어그램 작성 규칙은 [DIAGRAM-GUIDE.md](DIAGRAM-GUIDE.md) 참조)

```
+----- 박스 -----+
| 한글 정렬 유지 |
+----------------+
```

## KaTeX 수식

단독 줄 `$$...$$` 블록:

$$
UPH = \frac{\sum units}{\sum hours} \times 100\%
$$

`math` 펜스:

```math
E = mc^2
```

인라인 `$...$`는 지원하지 않습니다 — "$12K" 같은 금액 표기가 수식으로 오탐되는 것을 막기 위한 의도적 제외입니다.

## Mermaid 다이어그램

```mermaid
flowchart LR
  A[파일 저장] --> B{diff 계산}
  B --> C[SSE 전송]
  C --> D[변경 줄 하이라이트]
```

## ECharts 차트

```chart:echarts
{"_mdwatch":{"width":500,"height":250},"xAxis":{"type":"category","data":["A","B","C"]},"yAxis":{"type":"value"},"series":[{"type":"bar","data":[3,7,5]}]}
```

## 목차(TOC)

헤딩이 2개 이상인 문서는 우상단 "☰ 목차" 버튼으로 접이식 목차 패널을 열 수 있습니다. 클릭하면 해당 섹션으로 스크롤되고, 스크롤 위치에 따라 현재 섹션이 강조됩니다.

### 하위 섹션 A

내용

### 하위 섹션 B

내용

#### 더 깊은 섹션

내용
