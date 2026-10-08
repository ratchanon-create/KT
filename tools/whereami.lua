--=====================================================================
--  WHERE AM I  — บอก PlaceId / GameId / ชื่อเกม ของแมพที่กำลังเล่น
--  (รันในแมพที่ต้องการ แล้วเอาเลข PlaceId ไปใส่ในตาราง GAMES ของ main.lua)
--=====================================================================
local info
pcall(function()
    info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
end)
print("========== ข้อมูลแมพนี้ ==========")
print("ชื่อเกม   :", info and info.Name or "(ไม่ทราบ)")
print("PlaceId  :", game.PlaceId)
print("GameId   :", game.GameId)
print("Creator  :", info and tostring(info.Creator and info.Creator.Name) or "?")
print("==================================")
pcall(function()
    writefile("whereami.txt", ("%s\nplaceId=%d\ngameId=%d\n"):format(
        info and info.Name or "?", game.PlaceId, game.GameId))
end)
