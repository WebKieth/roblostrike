"""Execute browser pagination and the real directory controller with service doubles."""
from pathlib import Path
import unittest
import test_combat

ROOT = Path(__file__).resolve().parents[2]


class ServerBrowserTests(unittest.TestCase):
    run_luau = test_combat.CombatTests.run_luau

    def test_names_search_and_pagination(self):
        source = (ROOT / 'src/shared/ServerBrowser.luau').read_text()
        self.run_luau('local Browser = (function()\n' + source + '''
end)()
assert(Browser.validName("  Мой сервер  ")=="Мой сервер")
for _, bad in {"", "   ", "a\\nb", string.rep("Я",49), string.char(255), 123} do
    assert(not Browser.validName(bad))
end
assert(Browser.validName(string.rep("Я",48)))
local entries={}
for i=105,1,-1 do table.insert(entries,{id=tostring(i),name=string.format("Сервер %03d",i)}) end
local result=Browser.page(entries,"СЕРВЕР",1,50)
assert(#result.rows==50 and result.pages==3 and result.total==105 and result.rows[1].id=="1")
result=Browser.page(entries,"",3,50)
assert(#result.rows==5 and result.rows[1].id=="101")
result=Browser.page(entries,"",999,20)
assert(result.page==6 and result.pages==6 and #result.rows==5)
result=Browser.page(entries,"",-1,10)
assert(result.page==1 and #result.rows==10 and result.pages==11)
result=Browser.page(entries,"",1,7)
assert(result.size==50)
assert(Browser.page(entries,"[",1,50).total==0, "search must be literal, not a Lua pattern")
assert(Browser.page({{id="x",name="Ёлка"}},"ёл",1,50).total==1)
result=Browser.page(entries,"несуществующий",1,50)
assert(result.total==0 and result.pages==1 and result.page==1 and #result.rows==0)
print("Browser: validated names, Russian search, literal matching, 10/20/50 pagination OK")
''')

    def test_directory_studio_and_reserved_servers(self):
        fixture = (ROOT / 'tools/tests/fixtures/server_directory.luau').read_text()
        for marker, path in (
            ('-- BROWSER_HERE', 'src/shared/ServerBrowser.luau'),
            ('-- DIRECTORY_HERE', 'src/server/ServerDirectory.luau'),
        ):
            fixture = fixture.replace(marker, (ROOT / path).read_text())
        self.run_luau(fixture)

    def test_browser_ui_flow(self):
        fixture = (ROOT / 'tools/tests/fixtures/server_browser_ui.luau').read_text()
        fixture = fixture.replace('-- BROWSER_HERE', (ROOT / 'src/shared/ServerBrowser.luau').read_text())
        fixture = fixture.replace('-- UI_HERE', (ROOT / 'src/client/ServerBrowser.luau').read_text())
        self.run_luau(fixture)


if __name__ == '__main__':
    unittest.main()
