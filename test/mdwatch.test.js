'use strict';

// ROOT를 임시 디렉토리로 고정한 뒤 모듈 로드 (require보다 먼저 env 설정)
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const { test, before, after } = require('node:test');
const assert = require('node:assert');

const TMP = fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), 'mdwatch-test-')));
process.env.MDWATCH_ROOT = TMP;

const mdw = require('../src/mdwatch.js');

// 임시 .md 파일 생성 헬퍼
let _n = 0;
function tmpMd(content) {
  const p = path.join(TMP, `f${_n++}.md`);
  fs.writeFileSync(p, content, 'utf8');
  return p;
}

// ---------------------------------------------------------------- diffLines
test('diffLines: 변경 없음 → []', () => {
  assert.deepStrictEqual(mdw.diffLines('a\nb\nc', 'a\nb\nc'), []);
});
test('diffLines: 중간 줄 변경 → 해당 줄', () => {
  assert.deepStrictEqual(mdw.diffLines('a\nb\nc', 'a\nB\nc'), [2]);
});
test('diffLines: 끝에 줄 추가 → 추가된 줄', () => {
  assert.deepStrictEqual(mdw.diffLines('a\nb', 'a\nb\nc'), [3]);
});
test('diffLines: 줄 삭제 → 삭제 위치', () => {
  const r = mdw.diffLines('a\nb\nc', 'a\nc');
  assert.ok(r.length >= 1);
});

// -------------------------------------------------------- fileToUrl/urlToFile
test('fileToUrl/urlToFile: ROOT 내부 파일 왕복', () => {
  const p = tmpMd('hello\n');
  const url = mdw.fileToUrl(p);
  assert.ok(url.startsWith('/'));
  assert.strictEqual(mdw.urlToFile(url), p);
});
test('urlToFile: traversal은 ROOT 밖으로 탈출 불가', () => {
  // new URL()이 pathname의 ..를 정규화 → path.resolve가 ROOT 안쪽으로 클램프.
  // /etc/passwd 로 탈출하지 못하고 ROOT 내부 경로(존재하지 않음)로 갇힌다.
  const r = mdw.urlToFile('/../../../etc/passwd');
  assert.ok(r === null || r.startsWith(TMP + path.sep), 'ROOT 밖 접근 차단');
  assert.ok(!r || !r.startsWith('/etc/'), '/etc 직접 접근 불가');
});
test('urlToFile: ?abs= 파라미터', () => {
  const p = tmpMd('x\n');
  assert.strictEqual(mdw.urlToFile('/?abs=' + encodeURIComponent(p)), p);
});

// ------------------------------------------------------------------ hasEmbeds
test('hasEmbeds: 일반 문서 → false', () => {
  assert.strictEqual(mdw.hasEmbeds('# 제목\n본문\n'), false);
});
test('hasEmbeds: embed 마커 + 참조 → true', () => {
  const md = '본문 {{$foo}}\n\n<!--embeds-->\n{{$foo}}\n내용\n{{/foo}}\n';
  assert.strictEqual(mdw.hasEmbeds(md), true);
});

// ------------------------------------------------------------------ sliceLines
test('sliceLines: 1-indexed 범위 추출', () => {
  const c = 'l1\nl2\nl3\nl4';
  assert.strictEqual(mdw.sliceLines(c, 2, 3), 'l2\nl3');
});
test('sliceLines: 후행 빈 줄 트림', () => {
  const c = 'l1\npara\n\n\nl5';
  assert.strictEqual(mdw.sliceLines(c, 2, 4), 'para');
});
test('sliceLines: 범위 밖 클램프', () => {
  assert.strictEqual(mdw.sliceLines('a\nb', 1, 99), 'a\nb');
});

// ------------------------------------------------------- relocateAndReplace
test('relocate: 위치 불변 → 치환', () => {
  const c = '# T\n\nold para\n\nfooter';
  const r = mdw.relocateAndReplace(c, 'old para', 'new para', 3);
  assert.strictEqual(r.status, 'ok');
  assert.strictEqual(r.content, '# T\n\nnew para\n\nfooter');
});
test('relocate: 위에 줄이 추가돼 블록이 밀려도 재탐색 성공', () => {
  const c = '# T\n\nINSERTED\nMORE\n\nold para\n\nfooter';
  const r = mdw.relocateAndReplace(c, 'old para', 'new para', 3); // hint는 옛 위치
  assert.strictEqual(r.status, 'ok');
  assert.ok(r.content.includes('new para'));
  assert.ok(!r.content.includes('old para'));
  assert.ok(r.content.includes('INSERTED'));
});
test('relocate: 블록 자체가 바뀌면 conflict', () => {
  const c = '# T\n\nCHANGED para\n\nfooter';
  const r = mdw.relocateAndReplace(c, 'old para', 'new para', 3);
  assert.strictEqual(r.status, 'conflict');
});
test('relocate: 중복 블록은 hint에 가까운 것 선택', () => {
  const c = 'dup\n\nmid\n\ndup\n\nend';
  const r = mdw.relocateAndReplace(c, 'dup', 'X', 5); // 두 번째 dup(5줄)에 가까움
  assert.strictEqual(r.status, 'ok');
  assert.strictEqual(r.content, 'dup\n\nmid\n\nX\n\nend');
});
test('relocate: 줄 경계 아닌 부분매치는 무시(conflict)', () => {
  const c = 'prefix_old para_suffix\n';
  const r = mdw.relocateAndReplace(c, 'old para', 'new', 1);
  assert.strictEqual(r.status, 'conflict');
});

// ------------------------------------------------------------ renderContent
test('renderContent: 블록에 원본 줄번호 data-line 주입', () => {
  const html = mdw.renderContent('# 헤딩\n\n첫 문단\n\n둘째 문단');
  assert.ok(/<h1 data-line="1">/.test(html), 'h1 data-line=1');
  assert.ok(/<p data-line="3"/.test(html), 'para data-line=3');
  assert.ok(/<p data-line="5"/.test(html), 'para data-line=5');
});

// ------------------------------------------------------ HTTP 통합 (server)
let baseUrl;
before(async () => {
  await new Promise((resolve) => mdw.server.listen(0, '127.0.0.1', resolve));
  baseUrl = 'http://127.0.0.1:' + mdw.server.address().port;
});
after(() => { mdw.server.close(); fs.rmSync(TMP, { recursive: true, force: true }); });

function req(method, urlPath, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(baseUrl + urlPath);
    const data = body ? JSON.stringify(body) : null;
    const r = http.request(u, {
      method,
      headers: data ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } : {},
    }, (res) => {
      let buf = '';
      res.on('data', c => buf += c);
      res.on('end', () => {
        let json = null; try { json = JSON.parse(buf); } catch (e) {}
        resolve({ status: res.statusCode, text: buf, json });
      });
    });
    r.on('error', reject);
    if (data) r.write(data);
    r.end();
  });
}

test('GET /__ping → ok', async () => {
  const r = await req('GET', '/__ping');
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.text, 'ok');
});

test('GET /__source → 블록 소스 슬라이스', async () => {
  const p = tmpMd('# T\n\n원본 문단\n\n끝');
  const r = await req('GET', '/__source?file=' + encodeURIComponent(p) + '&start=3&end=4');
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.json.text, '원본 문단');
  assert.strictEqual(r.json.editable, true);
});

test('POST /__edit: 정상 저장 → 파일 갱신', async () => {
  const p = tmpMd('# T\n\n원본 문단\n\n끝');
  const r = await req('POST', '/__edit', { file: p, start: 3, end: 4, baseText: '원본 문단', newText: '수정된 문단' });
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.json.ok, true);
  assert.strictEqual(fs.readFileSync(p, 'utf8'), '# T\n\n수정된 문단\n\n끝');
});

test('POST /__edit: baseText 불일치 → 409 conflict + 현재 내용', async () => {
  const p = tmpMd('# T\n\n실제 다른 내용\n\n끝');
  const r = await req('POST', '/__edit', { file: p, start: 3, end: 4, baseText: '내가 본 원본', newText: '수정' });
  assert.strictEqual(r.status, 409);
  assert.strictEqual(r.json.reason, 'conflict');
  assert.strictEqual(r.json.current, '실제 다른 내용');
});

test('POST /__edit: embed 파일 → 409 embeds 거부', async () => {
  const p = tmpMd('본문 {{$foo}}\n\n<!--embeds-->\n{{$foo}}\nX\n{{/foo}}\n');
  const r = await req('POST', '/__edit', { file: p, start: 1, end: 1, baseText: '본문 {{$foo}}', newText: 'Y' });
  assert.strictEqual(r.status, 409);
  assert.strictEqual(r.json.reason, 'embeds');
});

test('POST /__edit: 비-마크다운 → 403', async () => {
  const p = path.join(TMP, 'x.txt'); fs.writeFileSync(p, 'a', 'utf8');
  const r = await req('POST', '/__edit', { file: p, start: 1, end: 1, baseText: 'a', newText: 'b' });
  assert.strictEqual(r.status, 403);
});
