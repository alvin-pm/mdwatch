-- mdwatch.app — Finder에서 .md 파일을 열 때 호출됨.
-- node에서 URL을 받아 브라우저에서 동일 URL 탭이 있으면 focus, 없으면 새 탭.
-- AppleEvent는 이 스크립트(=mdwatch.app)가 직접 발송 → TCC 권한이 mdwatch.app 단위로 부여됨.
--
-- ⚠️ 이 파일은 reference 입니다. 실제 mdwatch.app은 install-mdwatch.command가
--   사용자 환경(node 경로, 기본 브라우저)을 자동 감지하여 동적으로 생성·컴파일합니다.
--   직접 컴파일해서 쓰려면 아래 placeholder를 본인 환경 값으로 치환하세요:
--     __NODE_PATH__   → `which node` 결과 (예: /opt/homebrew/bin/node)
--     __MDWATCH_JS__  → mdwatch.js 절대경로 (예: $HOME/mdwatch/mdwatch.js)
--     __BROWSER_APP__ → 기본 브라우저 앱 이름 (예: Vivaldi, Google Chrome, Safari)

property NODE_BIN : "__NODE_PATH__"
property MDWATCH_JS : "__MDWATCH_JS__"

on run {input, parameters}
	if input is missing value then return
	if (count of input) is 0 then return
	repeat with aFile in input
		my handleFile(POSIX path of aFile)
	end repeat
end run

on open theFiles
	repeat with aFile in theFiles
		my handleFile(POSIX path of aFile)
	end repeat
end open

on handleFile(filePath)
	set targetURL to ""
	try
		set targetURL to do shell script (quoted form of NODE_BIN) & " " & (quoted form of MDWATCH_JS) & " __resolve " & quoted form of filePath
	on error errMsg number errNum
		display dialog "mdwatch resolve failed (" & errNum & "): " & errMsg buttons {"OK"} default button "OK"
		return
	end try
	if targetURL is "" then return
	my focusOrOpenTab(targetURL)
end handleFile

on focusOrOpenTab(targetURL)
	tell application "__BROWSER_APP__"
		set found to false
		repeat with w in windows
			set tabList to tabs of w
			repeat with i from 1 to count of tabList
				if URL of (item i of tabList) is targetURL then
					set active tab index of w to i
					set index of w to 1
					activate
					set found to true
					exit repeat
				end if
			end repeat
			if found then exit repeat
		end repeat
		if not found then
			open location targetURL
			activate
		end if
	end tell
end focusOrOpenTab
