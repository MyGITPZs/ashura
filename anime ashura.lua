-- =======================================================
-- Anime Ashura [UPD 05] - All-in-One Auto Script v2.1 MOBILE
-- เวอร์ชันมือถือ (Delta Android / iOS) เน้นความเสถียร
--
-- สิ่งที่เปลี่ยนจาก v2.0:
--   * UI เป็นหน้าต่างเดียวแบบแท็บ ขนาดปรับตามจอ และจัดใหม่เองเมื่อหมุนจอ
--   * ลากหน้าต่างด้วยนิ้วได้ (เลิกใช้ Draggable ที่ Roblox เลิกรองรับแล้ว)
--   * มีปุ่มลอย "AH" สำหรับย่อ/ขยายเมนู และจำสถานะย่อไว้ข้ามเซิร์ฟ
--   * รันสคริปต์ซ้ำได้: ลูปเก่าจะถูกหยุดก่อน ไม่ซ้อนกัน
--   * ทุกการเรียก Remote มี timeout จึงไม่ค้างตลอดไปเมื่อเน็ตมือถือหลุด
--   * ลูปเบื้องหลังทุกตัวห่อด้วย pcall จึงไม่ตายเมื่อเจอ error
--   * สถานะ Restock ถูกบันทึกลงไฟล์ จึงซื้อของต่อได้หลังวาร์ปกลับ Lobby
--   * กดปุ่มในเกมได้หลายวิธี: getconnections → firesignal → VirtualInputManager
--
-- ถ้าต้องการให้ Auto Farm ทำงานต่อหลังวาร์ประหว่าง Lobby กับด่าน
-- ให้ใส่ไฟล์นี้ไว้ในโฟลเดอร์ Autoexecute ของ Delta
-- =======================================================

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- ==========================================
-- 0. SESSION: ป้องกันการรันซ้ำแล้วลูปซ้อนกัน
-- ==========================================
if type(_G.__AAH_CLEANUP) == "function" then
    pcall(_G.__AAH_CLEANUP)
end

local SESSION = { dead = false }
local trackedConns = {}
local screenGui = nil

local function alive()
    return not SESSION.dead
end

local function track(conn)
    if conn then
        table.insert(trackedConns, conn)
    end
    return conn
end

-- ฟังก์ชันนี้หยุดทุกลูปของรอบนี้และลบ GUI ทิ้ง (ถูกเรียกตอนรันซ้ำหรือกดปิดสคริปต์)
_G.__AAH_CLEANUP = function()
    SESSION.dead = true
    for _, c in ipairs(trackedConns) do
        pcall(function() c:Disconnect() end)
    end
    trackedConns = {}
    if screenGui then
        pcall(function() screenGui:Destroy() end)
        screenGui = nil
    end
end

-- รอแบบแบ่งช่วงสั้นๆ ถ้าสคริปต์ถูกปิดระหว่างรอจะหลุดออกทันทีและคืนค่า false
local function sleep(sec)
    local t0 = os.clock()
    while alive() and os.clock() - t0 < sec do
        task.wait(math.min(0.25, sec))
    end
    return alive()
end

-- ==========================================
-- 1. SERVICES
-- ==========================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local VirtualUser, VIM = nil, nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)
pcall(function() VIM = game:GetService("VirtualInputManager") end)

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local LOBBY_PLACE = 81532592154280
local BATTLE_PLACE = 112575319532871
local IN_BATTLE = (game.PlaceId == BATTLE_PLACE)

-- ==========================================
-- 2. STATUS / NOTIFY / LOOP HELPERS
-- ==========================================
local statusLabel = nil
local lastNotify = {}
local notifyCount = 0

local function setStatus(text)
    if statusLabel then
        pcall(function() statusLabel.Text = tostring(text) end)
    end
end

-- แจ้งเตือนแบบกันสแปม: ข้อความเดิมภายใน 4 วินาทีจะไม่เด้งซ้ำ (บนมือถือแจ้งเตือนบังจอ)
local function notify(title, text, duration)
    title = tostring(title or "Anime Ashura")
    text = tostring(text or "")
    setStatus(title .. " • " .. text)

    local key = title .. "|" .. text
    local now = os.clock()
    if lastNotify[key] and now - lastNotify[key] < 4 then
        return
    end
    notifyCount = notifyCount + 1
    if notifyCount > 100 then
        lastNotify = {}
        notifyCount = 0
    end
    lastNotify[key] = now

    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

-- ลูปเบื้องหลังที่ไม่ตายเมื่อเจอ error และหยุดเองเมื่อสคริปต์ถูกปิด
local function loop(name, interval, fn)
    task.spawn(function()
        while alive() do
            local ok, err = pcall(fn)
            if not ok then
                warn("[AAH:" .. name .. "] " .. tostring(err))
            end
            if not sleep(interval) then
                break
            end
        end
    end)
end

-- ==========================================
-- 3. REMOTES (มี timeout)
-- ==========================================
local Kingdom = ReplicatedStorage:WaitForChild("Kingdom", 20)
if not Kingdom then
    notify("Anime Ashura", "ไม่พบโฟลเดอร์ Kingdom (เกมอาจอัปเดต)", 6)
    warn("[AAH] ไม่พบโฟลเดอร์ Kingdom!")
    return
end

local Remotes = Kingdom:WaitForChild("Remotes", 15)
local Request = Remotes and Remotes:WaitForChild("Request", 15)
if not Request then
    notify("Anime Ashura", "ไม่พบ Remote Request (เกมอาจอัปเดต)", 6)
    warn("[AAH] ไม่พบ Kingdom.Remotes.Request!")
    return
end

local function safeRequire(name)
    local mod = Kingdom:WaitForChild(name, 5)
    if not mod then
        return nil
    end
    local ok, res = pcall(require, mod)
    if ok then
        return res
    end
    warn("[AAH] require " .. name .. " ไม่สำเร็จ: " .. tostring(res))
    return nil
end

-- โหลด Config และ Goals
local Config = safeRequire("Config")
local Goals = safeRequire("Goals")

local REMOTE_TIMEOUT = 10

-- เรียก Request:InvokeServer แบบมี timeout คืนค่า (ok, result)
-- ถ้าเซิร์ฟเวอร์ไม่ตอบภายใน REMOTE_TIMEOUT วินาที จะคืน (false, "timeout") แทนการค้าง
local function call(name, ...)
    local args = { ... }
    local n = select("#", ...)
    local done, okRes, result = false, false, nil

    task.spawn(function()
        local ok, res = pcall(function()
            return Request:InvokeServer(name, table.unpack(args, 1, n))
        end)
        if not done then
            done = true
            okRes, result = ok, res
            if not ok then
                warn("[AAH:Remote] " .. tostring(name) .. " -> " .. tostring(res))
            end
        end
    end)

    local t0 = os.clock()
    while not done and os.clock() - t0 < REMOTE_TIMEOUT do
        task.wait(0.05)
    end
    if not done then
        done = true
        warn("[AAH:Remote] " .. tostring(name) .. " timeout")
        return false, "timeout"
    end
    return okRes, result
end

-- ==========================================
-- 4. ระบบ SAVE / LOAD ตั้งค่า (Persistent Settings)
-- ==========================================
local SETTINGS_FILE = "AnimeAshura_Settings.json"
local canFile = (type(writefile) == "function" and type(readfile) == "function")

local function saveSettings(data)
    if not canFile then
        return false
    end
    local ok, err = pcall(function()
        writefile(SETTINGS_FILE, HttpService:JSONEncode(data))
    end)
    if not ok then
        warn("[SaveSettings] บันทึกไม่สำเร็จ: " .. tostring(err))
    end
    return ok
end

local function loadSettings()
    if not canFile then
        return nil
    end
    local ok, result = pcall(function()
        if type(isfile) == "function" and not isfile(SETTINGS_FILE) then
            return nil
        end
        local raw = readfile(SETTINGS_FILE)
        if type(raw) ~= "string" or raw == "" then
            return nil
        end
        return HttpService:JSONDecode(raw)
    end)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

-- รวมค่าที่บันทึกกับค่าเริ่มต้น: ถ้าชนิดข้อมูลไม่ตรง (ไฟล์เสีย) จะใช้ค่าเริ่มต้นแทน
local function mergeDefaults(saved, defaults)
    local out = {}
    for k, v in pairs(defaults) do
        if type(saved) == "table" and saved[k] ~= nil and type(saved[k]) == type(v) then
            out[k] = saved[k]
        else
            out[k] = v
        end
    end
    return out
end

-- ค่าเริ่มต้นทั้งหมด
local defaultFarmConfig = {
    Enabled = false,
    Mode = "Story",
    World = 1,
    Stage = 1,
    Difficulty = "Easy",
    Solo = true,
    AutoSkills = true,
    AutoReplay = true,
    AutoNext = false,
    LowGraphics = true
}

local defaultMerchantConfig = {
    buyAllGold = true,
    buyLuck = true,
    buyRainbow = true,
    buyTrait = true,
    buyStar = true,
    buyEvo = true,
    buyChips = false
}

local defaultCurrencyShopConfig = {
    buyAllGold = true,
    buyScroll = true,
    buyTrait = true,
    buyStar = true,
    buyRotatingGems = false,
    buyShards = false
}

local defaultGeneralConfig = {
    stopOnMythicOrSecret = true,
    autoSellRare = true,
    autoSellEpic = false,
    isAutoClaimLoop = false,
    isAutoShopLoop = false,
    restockExitBattle = true,  -- ✨ ระบบออกจากด่านเมื่อร้านค้ารีเซ็ต
    restockPending = false,    -- ✨ จำไว้ข้ามเซิร์ฟว่ายังต้องกลับไปซื้อของ
    uiMinimized = false        -- ✨ จำว่าย่อเมนูไว้หรือไม่ (ไม่บังจอหลังวาร์ป)
}

-- โหลดค่าที่บันทึกไว้ (ถ้ามี)
local savedData = loadSettings()

-- ==========================================
-- 5. ระบบ Anti-AFK ป้องกันโดนเตะ 20 นาที
-- ==========================================
track(LocalPlayer.Idled:Connect(function()
    if not VirtualUser then
        return
    end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))

-- ฟังก์ชันช่วยคำนวณเวลานับถอยหลัง (HH:MM:SS)
local function formatClock(seconds)
    seconds = tonumber(seconds)
    if not seconds or seconds <= 0 then
        return "00:00:00"
    end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function getServerTime()
    local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
    if ok and t then
        return math.floor(t)
    end
    return os.time()
end

-- ==========================================
-- 6. ฐานข้อมูลด่านและแมพ (Stage Database)
-- ==========================================
local stageDB = {
    Story = {
        [1] = {
            Name = "Planet Namekku",
            Stages = {
                { Name = "Green Plains", Boss = "Gurdo" },
                { Name = "Dome Village", Boss = "Rikum" },
                { Name = "Dragon Lake", Boss = "Bata" },
                { Name = "Crash Site", Boss = "Jice" },
                { Name = "Mothership Ridge", Boss = "Zarbo" },
                { Name = "Royal Landing", Boss = "Ginyo" }
            }
        },
        [2] = {
            Name = "Hidden Village",
            Stages = {
                { Name = "Village Gate", Boss = "Kakasho" },
                { Name = "Ramen Street", Boss = "Might Guyy" },
                { Name = "Market Road", Boss = "Hirko" },
                { Name = "Festival Lane", Boss = "Kimase" },
                { Name = "Round Tower Row", Boss = "Dodera (Truth Seeking)" },
                { Name = "Hokage Road", Boss = "Itochi (Rinnegan)" }
            }
        },
        [3] = {
            Name = "Shibuya Station",
            Stages = {
                { Name = "Entrance Hall", Boss = "Shogamo" },
                { Name = "Ticket Gates", Boss = "Chaso" },
                { Name = "Long Concourse", Boss = "Jogu (Six Eyes)" },
                { Name = "Platform 5", Boss = "Reanimated Tuji" },
                { Name = "The Tracks", Boss = "Mohato (Cursed Finger)" },
                { Name = "Deep Line", Boss = "Sukono" }
            }
        },
        [4] = {
            Name = "Hueko Mundo",
            Stages = {
                { Name = "Endless Dunes", Boss = "Menos Grando" },
                { Name = "Quartz Forest", Boss = "Grimmjo" },
                { Name = "Hollow Valley", Boss = "Kenpacho (Eyepatch)" },
                { Name = "Nochas Gate", Boss = "Vasto Ichigu (Hollow Mask)" },
                { Name = "Moonlit Halls", Boss = "Ulquiorro (Murcielago)" },
                { Name = "Throne of Night", Boss = "Aizen" }
            }
        }
    },
    Raid = {
        [1] = {
            Name = "Dying Namek",
            Stages = {
                { Name = "Act 1: Scorched Plains", Boss = "Vegetu" },
                { Name = "Act 2: Burning Village", Boss = "Freezer 1st Form" },
                { Name = "Act 3: Boiling Lake", Boss = "Freezer 2nd Form" },
                { Name = "Act 4: Falling Sky", Boss = "Freezer 3rd Form" },
                { Name = "Act 5: Last Stand", Boss = "Freezer" },
                { Name = "Act 6: Full Power", Boss = "Full Power Freezer" }
            }
        }
    },
    Castle = {
        [1] = {
            Name = "Infinite Castle",
            Stages = {
                { Name = "Castle Floors", Boss = "Kyogan" }
            }
        }
    },
    Challenge = {
        [1] = {
            Name = "Challenge",
            Stages = {
                { Name = "Rotating Challenge", Boss = "Special Boss" }
            }
        }
    }
}

-- ==========================================
-- ฐานข้อมูล CURRENCY SHOP (Gold Shop & Gem Shop)
-- ==========================================
local currencyShopDB = {
    Gold = {
        { Key = "c_expS", Item = "ExpDango", Name = "Exp Dango (x10)", Amount = 10, Price = 1500, Currency = "Gold", Stock = 5 },
        { Key = "c_expM", Item = "ExpDangoM", Name = "Exp Dango M (x10)", Amount = 10, Price = 12000, Currency = "Gold", Stock = 1 },
        { Key = "c_dust", Item = "ForgeDust", Name = "Forge Dust (x20)", Amount = 20, Price = 3000, Currency = "Gold", Stock = 10 },
        { Key = "c_runeBrawler", Item = "RuneBrawler", Name = "Rune Brawler (x10)", Amount = 10, Price = 2500, Currency = "Gold", Stock = 15 },
        { Key = "c_runeBlade", Item = "RuneBlade", Name = "Rune Blade (x10)", Amount = 10, Price = 2500, Currency = "Gold", Stock = 15 },
        { Key = "c_runeBomber", Item = "RuneBomber", Name = "Rune Bomber (x10)", Amount = 10, Price = 2500, Currency = "Gold", Stock = 15 },
        { Key = "c_runeGunner", Item = "RuneGunner", Name = "Rune Gunner (x10)", Amount = 10, Price = 2500, Currency = "Gold", Stock = 15 },
        { Key = "c_runeGuardian", Item = "RuneGuardian", Name = "Rune Guardian (x10)", Amount = 10, Price = 2500, Currency = "Gold", Stock = 15 },
        { Key = "c_runeMystic", Item = "RuneMystic", Name = "Rune Mystic (x10)", Amount = 10, Price = 2500, Currency = "Gold", Stock = 15 },
        { Key = "c_runeHealer", Item = "RuneHealer", Name = "Rune Healer (x10)", Amount = 10, Price = 2500, Currency = "Gold", Stock = 15 },
        { Key = "c_runeBooster", Item = "RuneBooster", Name = "Rune Booster (x10)", Amount = 10, Price = 2500, Currency = "Gold", Stock = 15 }
    },
    Gems = {
        { Key = "g_scroll", Item = "SkillScroll", Name = "Skill Scroll (x1)", Amount = 1, Price = 150, Currency = "Gems", Stock = 1 },
        { Key = "g_trait", Item = "TraitCrystal", Name = "Trait Crystal (x5)", Amount = 5, Price = 100, Currency = "Gems", Stock = 5 },
        { Key = "g_shard", Item = "StarShard", Name = "Star Shard (x10)", Amount = 10, Price = 300, Currency = "Gems", Stock = 1 },
        { Key = "g_expL", Item = "ExpDangoL", Name = "Exp Dango L (x1)", Amount = 1, Price = 60, Currency = "Gems", Stock = 3 },
        { Key = "g_green", Item = "GreenGem", Name = "Green Gem (x1)", Amount = 1, Price = 60, Currency = "Gems", Stock = 3, Rotates = true },
        { Key = "g_yellow", Item = "YellowGem", Name = "Yellow Gem (x1)", Amount = 1, Price = 150, Currency = "Gems", Stock = 2, Rotates = true },
        { Key = "g_red", Item = "RedGem", Name = "Red Gem (x1)", Amount = 1, Price = 400, Currency = "Gems", Stock = 1, Rotates = true },
        { Key = "g_pink", Item = "PinkGem", Name = "Pink Gem (x1)", Amount = 1, Price = 250, Currency = "Gems", Stock = 2, Rotates = true },
        { Key = "g_purple", Item = "PurpleGem", Name = "Purple Gem (x1)", Amount = 1, Price = 250, Currency = "Gems", Stock = 2, Rotates = true },
        { Key = "g_mythic", Item = "MythicShards", Name = "Mythic Shards (x5)", Amount = 5, Price = 100, Currency = "Gems", Stock = 4, Rarity = "Mythic" },
        { Key = "g_legendary", Item = "LegendaryShards", Name = "Legendary Shards (x5)", Amount = 5, Price = 75, Currency = "Gems", Stock = 4, Rarity = "Legendary" },
        { Key = "g_epic", Item = "EpicShards", Name = "Epic Shards (x5)", Amount = 5, Price = 50, Currency = "Gems", Stock = 4, Rarity = "Epic" }
    }
}

local MODES = {
    { id = "Story", text = "Story" },
    { id = "Raid", text = "Raid" },
    { id = "Castle", text = "Castle" },
    { id = "Challenge", text = "Challenge" }
}

local DIFFS = {
    { id = "Easy", text = "Easy", color = Color3.fromRGB(46, 204, 113) },
    { id = "Medium", text = "Medium", color = Color3.fromRGB(241, 196, 15) },
    { id = "Hard", text = "Hard", color = Color3.fromRGB(231, 76, 60) }
}
local DIFF_COLOR = {}
for _, d in ipairs(DIFFS) do
    DIFF_COLOR[d.id] = d.color
end

-- ==========================================
-- 7. ตัวแปรสถานะ (โหลดจากไฟล์ที่บันทึก)
-- ==========================================
local G = mergeDefaults(savedData and savedData.general, defaultGeneralConfig)
local merchantConfig = mergeDefaults(savedData and savedData.merchant, defaultMerchantConfig)
local currencyShopConfig = mergeDefaults(savedData and savedData.currency, defaultCurrencyShopConfig)
local farmCfg = mergeDefaults(savedData and savedData.farm, defaultFarmConfig)
_G.AnimeAshura_AutoFarm = farmCfg

local state = {
    summonToken = nil,
    startingRoom = false,
    lastStartAttempt = 0,
    teleporting = false,
    teleportAt = 0,
    restockSince = nil
}

local cachedMerchantInfo = nil

local function worldData(mode, world)
    local m = stageDB[mode]
    return m and m[world] or nil
end

local function stageCount(mode, world)
    local w = worldData(mode, world)
    return (w and w.Stages and #w.Stages) or 0
end

-- แก้ค่าที่ไม่ถูกต้อง เช่น เลือก World 3 ใน Raid ที่มีแค่ World 1
local function sanitizeFarm()
    if not stageDB[farmCfg.Mode] then
        farmCfg.Mode = "Story"
    end
    farmCfg.World = tonumber(farmCfg.World) or 1
    if not worldData(farmCfg.Mode, farmCfg.World) then
        farmCfg.World = 1
    end
    farmCfg.Stage = tonumber(farmCfg.Stage) or 1
    local n = stageCount(farmCfg.Mode, farmCfg.World)
    if farmCfg.Stage < 1 or farmCfg.Stage > n then
        farmCfg.Stage = 1
    end
    if not DIFF_COLOR[farmCfg.Difficulty] then
        farmCfg.Difficulty = "Easy"
    end
end
sanitizeFarm()

-- ==========================================
-- ✨ ฟังก์ชันบันทึกตั้งค่าปัจจุบันลงไฟล์
-- ==========================================
local function persistCurrentSettings()
    return saveSettings({
        farm = farmCfg,
        merchant = merchantConfig,
        currency = currencyShopConfig,
        general = G
    })
end

-- ==========================================
-- ✨ Auto-Save ทุกครั้งที่เปลี่ยนค่า (Debounce)
-- ==========================================
local _saveQueued = false
local function queueSave()
    if _saveQueued then
        return
    end
    _saveQueued = true
    task.delay(1, function()
        _saveQueued = false
        persistCurrentSettings()
    end)
end

-- ตัวรีเฟรช UI ที่ถูกกำหนดค่าจริงตอนสร้าง GUI
local refreshSummonToggle = function() end

-- ==========================================
-- 8. ฟังก์ชัน AUTO CLAIM เควสทุกอย่าง
-- ==========================================
local claimBusy = false
local function claimAllEverything(silent)
    if claimBusy then
        if not silent then setStatus("🎁 กำลังรับรางวัลอยู่แล้ว...") end
        return
    end
    claimBusy = true
    setStatus("🎁 กำลังกดรับรางวัล...")

    local ok, err = pcall(function()
        local simple = {
            "ClaimAllMissions", "ClaimDaily", "ClaimAllMilestones", "BattlePassClaimAll",
            "HollowLoginClaim", "ClaimSkipGift", "JoinGiftClaim"
        }
        for _, name in ipairs(simple) do
            if not alive() then return end
            call(name)
            task.wait(0.1)
        end

        if Goals then
            if type(Goals.AchievementGroups) == "table" then
                for _, grp in ipairs(Goals.AchievementGroups) do
                    if not alive() then return end
                    if type(grp) == "table" and grp.Id ~= nil then
                        call("ClaimAchievementGroup", grp.Id)
                        if type(grp.ChestGoal) == "table" and grp.ChestGoal.Id ~= nil then
                            call("ClaimAchievement", grp.ChestGoal.Id)
                        end
                        task.wait(0.05)
                    end
                end
            end
            if type(Goals.Achievements) == "table" then
                for _, ach in ipairs(Goals.Achievements) do
                    if not alive() then return end
                    if type(ach) == "table" and ach.Id ~= nil then
                        call("ClaimAchievement", ach.Id)
                        task.wait(0.05)
                    end
                end
            end
        end
    end)

    claimBusy = false
    if not ok then
        warn("[AutoClaim] " .. tostring(err))
    end
    if silent then
        local t = os.date("*t")
        setStatus(string.format("🎁 Auto Claim รอบล่าสุดเสร็จ %02d:%02d", t.hour, t.min))
    else
        notify("Auto Claim", "กดรับของรางวัลทั้งหมดเรียบร้อย!", 2)
    end
end

-- ==========================================
-- 9. ฟังก์ชัน AUTO REDEEM CODES
-- ==========================================
local redeemBusy = false
local function redeemAllCodes()
    if redeemBusy then return end
    redeemBusy = true

    local codeList = { "RELEASE", "SAKURA", "300CCU", "1KLIKES", "HUECOMUNDO", "2KLIKES", "800CCU", "3KLIKES" }
    if Config and type(Config.Codes) == "table" then
        for code, _ in pairs(Config.Codes) do
            if type(code) == "string" and not table.find(codeList, code) then
                table.insert(codeList, code)
            end
        end
    end

    local successCount = 0
    for i, code in ipairs(codeList) do
        if not alive() then break end
        setStatus(string.format("🏷️ ใส่โค้ด %d/%d: %s", i, #codeList, code))
        local ok, res = call("Redeem", code)
        if ok and type(res) == "table" and res.Ok then
            successCount = successCount + 1
        end
        task.wait(0.35)
    end

    redeemBusy = false
    notify("Auto Redeem", "ใส่โค้ดเสร็จ (สำเร็จ " .. successCount .. " โค้ด)", 3)
end

-- ==========================================
-- 10. ฟังก์ชัน ใช้น้ำยา LUCK (1 ขวด)
-- ==========================================
local function useOneLuckPotion()
    local okState, st = call("GetState")
    local items = (okState and type(st) == "table" and type(st.Items) == "table") and st.Items or {}

    local potionToUse = "SuperLuck"
    if (tonumber(items["SuperLuck"]) or 0) > 0 then
        potionToUse = "SuperLuck"
    elseif (tonumber(items["UltraLuck"]) or 0) > 0 then
        potionToUse = "UltraLuck"
    end

    local ok, res = call("UseLuck", potionToUse)
    if ok and type(res) == "table" and res.Ok then
        notify("🧪 Luck Potion", "ใช้ " .. potionToUse .. " สำเร็จ!", 4)
    else
        local errMsg = (type(res) == "table" and res.Error) or (res == "timeout" and "เซิร์ฟไม่ตอบ") or "ไม่มีน้ำยา หรือน้ำยายังออกฤทธิ์อยู่"
        notify("🧪 Luck Potion", tostring(errMsg), 3)
    end
end

-- ==========================================
-- 11. ฟังก์ชัน AUTO SUMMON (ข้ามอนิเมชัน)
-- ==========================================
local function setAutoSellSettings()
    if G.autoSellRare then call("SetAutoSell", "Rare", true) end
    if G.autoSellEpic then call("SetAutoSell", "Epic", true) end
end

local function stopAutoSummon()
    state.summonToken = nil
    refreshSummonToggle()
    notify("Auto Summon", "หยุดการสุ่มแล้ว", 2)
end

local function startAutoSummonLoop()
    if state.summonToken then
        return
    end
    -- ใช้ token แยกแต่ละรอบ: กดปิดแล้วเปิดเร็วๆ จะไม่เกิดลูปสุ่มสองตัวซ้อนกัน
    local token = {}
    state.summonToken = token
    refreshSummonToggle()

    task.spawn(function()
        setAutoSellSettings()
        notify("Auto Summon", "เริ่มสุ่มแบบข้ามอนิเมชัน...", 2)
        local rounds = 0

        while state.summonToken == token and alive() do
            local ok, res = call("Summon", 10)
            if state.summonToken ~= token then
                break
            end
            if not ok then
                notify("Auto Summon", "การเชื่อมต่อขัดข้อง (" .. tostring(res) .. ")", 3)
                break
            end
            if type(res) ~= "table" or not res.Ok or type(res.Results) ~= "table" then
                local errMsg = (type(res) == "table" and res.Error) or "เพชรหมดหรือช่องเก็บเต็ม"
                notify("Auto Summon หยุดทำงาน", tostring(errMsg), 3)
                break
            end

            rounds = rounds + 1
            local gotHighRarity = false
            for _, unit in ipairs(res.Results) do
                if type(unit) == "table" then
                    local rarity = unit.Rarity or "Unknown"
                    if rarity == "Mythic" or rarity == "Secret" then
                        gotHighRarity = true
                        local name = unit.Unit or unit.Name or "Unknown"
                        notify("🎉 ยินดีด้วย!", string.format("ได้ [%s] %s!", tostring(rarity), tostring(name)), 5)
                        print(string.format("[AutoSummon] ได้รับระดับสูง: %s (%s)", tostring(name), tostring(rarity)))
                    end
                end
            end
            setStatus("🎰 สุ่มไปแล้ว " .. rounds .. " รอบ (10x)")

            if gotHighRarity and G.stopOnMythicOrSecret then
                notify("Auto Summon", "หยุดสุ่มเพราะได้ตัวละครระดับสูง!", 4)
                break
            end
            task.wait(0.5)
        end

        if state.summonToken == token then
            state.summonToken = nil
        end
        refreshSummonToggle()
    end)
end

-- ==========================================
-- 12. ระบบ MERCHANT (ร้านค้าเร้นลับ - Rare Goods)
-- ==========================================
local function fetchMerchantInfo()
    local ok, res = call("MerchantInfo")
    if ok and type(res) == "table" then
        cachedMerchantInfo = res
        return res
    end
    return cachedMerchantInfo
end

local function getLeftStock(offer, boughtTable)
    local limit = tonumber(offer.Limit) or 1
    local b = type(boughtTable) == "table" and boughtTable[offer.Key] or nil
    local boughtCount = 0
    if b == true then
        boughtCount = limit
    elseif type(b) == "number" then
        boughtCount = b
    end
    return math.max(limit - boughtCount, 0)
end

local function shouldAutoBuyMerchantItem(offer)
    local item = tostring(offer.Item or "")
    local currency = offer.Currency or "Gold"

    if merchantConfig.buyAllGold and currency == "Gold" then return true end
    if merchantConfig.buyLuck and (item == "SuperLuck" or item == "UltraLuck") then return true end
    if merchantConfig.buyRainbow and item == "RainbowShard" then return true end
    if merchantConfig.buyTrait and item == "TraitCrystal" then return true end
    if merchantConfig.buyStar and item == "StarShard" then return true end
    if merchantConfig.buyEvo and string.sub(item, 1, 3) == "Evo" then return true end
    if merchantConfig.buyChips and (item == "StatChip" or item == "SuperStatChip") then return true end

    return false
end

local function buySingleMerchantItem(key, amount)
    local ok, res = call("MerchantBuy", key, amount or 1)
    if ok and type(res) == "table" and res.Ok then
        return true
    end
    local reason = (type(res) == "table" and (res.Reason or res.Error)) or (res == "timeout" and "เซิร์ฟไม่ตอบ") or "เงินไม่พอ หรือสินค้าหมด"
    return false, tostring(reason)
end

-- ล็อกร้านค้า: กันลูป Auto Buy กับปุ่มกดมือทำงานพร้อมกันจนซื้อซ้ำ
local shopLock = false
local function withShopLock(fn)
    local t0 = os.clock()
    while shopLock and os.clock() - t0 < 30 do
        task.wait(0.2)
    end
    shopLock = true
    local ok, res = pcall(fn)
    shopLock = false
    if not ok then
        warn("[AAH:Shop] " .. tostring(res))
        return 0
    end
    return res or 0
end

local function calcQty(left, price, wallet)
    price = tonumber(price) or 0
    if price <= 0 then
        return left
    end
    if wallet < price then
        return 0
    end
    return math.min(left, math.floor(wallet / price))
end

local function runMerchantAutoBuy(isSilent)
    return withShopLock(function()
        local info = fetchMerchantInfo()
        if not info or type(info.Stock) ~= "table" then
            if not isSilent then notify("🛒 Merchant", "ดึงข้อมูลร้านค้าไม่ได้", 3) end
            return 0
        end

        local stateOk, st = call("GetState")
        local gold = (stateOk and type(st) == "table" and tonumber(st.Gold)) or 0
        local gems = (stateOk and type(st) == "table" and tonumber(st.Gems or st.Gem)) or 0

        local boughtCount = 0
        local boughtList = {}

        for _, offer in ipairs(info.Stock) do
            if not alive() then break end
            if type(offer) == "table" then
                local left = getLeftStock(offer, info.Bought)
                if left > 0 and shouldAutoBuyMerchantItem(offer) then
                    local price = tonumber(offer.Price) or 0
                    local cur = offer.Currency or "Gold"
                    local qty = calcQty(left, price, (cur == "Gold") and gold or gems)

                    if qty > 0 then
                        local success = buySingleMerchantItem(offer.Key, qty)
                        if success then
                            boughtCount = boughtCount + 1
                            local cost = price * qty
                            if cur == "Gold" then gold = gold - cost else gems = gems - cost end
                            table.insert(boughtList, string.format("%s (x%s)", tostring(offer.Item), tostring((tonumber(offer.Amount) or 1) * qty)))
                            print(string.format("[Merchant AutoBuy] ซื้อ %s x%s สำเร็จ (ใช้ %s %s)", tostring(offer.Item), tostring(qty), tostring(cost), tostring(cur)))
                        end
                        task.wait(0.2)
                    end
                end
            end
        end

        fetchMerchantInfo()

        if boughtCount > 0 then
            notify("🛒 Merchant ซื้อสำเร็จ!", "ซื้อ " .. table.concat(boughtList, ", "), 4)
        elseif not isSilent then
            notify("🛒 Merchant", "ไม่มีไอเทมที่เลือก หรือเงินไม่พอ", 3)
        end
        return boughtCount
    end)
end

-- ==========================================
-- 13. ระบบ CURRENCY SHOP (Gold Shop & Gem Shop)
-- ==========================================
local function getActiveColors()
    if Config and type(Config.ShopColorsNow) == "function" then
        local ok, res = pcall(Config.ShopColorsNow)
        if ok and type(res) == "table" then
            return res
        end
    end
    return {}
end

local function getCurrencyShopLeft(offer, st)
    local shop = (type(st) == "table" and type(st.Shop) == "table") and st.Shop or {}
    local currentHour = math.floor(getServerTime() / 3600)
    local bought = 0
    if shop.Hour == currentHour and type(shop.Bought) == "table" then
        bought = tonumber(shop.Bought[offer.Key]) or 0
    end
    return math.max((offer.Stock or 1) - bought, 0)
end

local function buyCurrencyShopItem(offer, amount)
    local unit = nil
    if offer.Rarity and Config and type(Config.ShopUnit) == "function" then
        pcall(function() unit = Config.ShopUnit(offer) end)
    end
    local ok, res = call("ShopBuy", offer.Key, amount or 1, unit)
    if ok and type(res) == "table" and res.Ok then
        return true
    end
    local reason = (type(res) == "table" and (res.Reason or res.Error)) or (res == "timeout" and "เซิร์ฟไม่ตอบ") or "เงินไม่พอ หรือสินค้าหมด"
    return false, tostring(reason)
end

local function shouldBuyCurrencyOffer(offer)
    if offer.Currency == "Gold" and currencyShopConfig.buyAllGold then return true end
    if offer.Key == "g_scroll" and currencyShopConfig.buyScroll then return true end
    if offer.Key == "g_trait" and currencyShopConfig.buyTrait then return true end
    if offer.Key == "g_shard" and currencyShopConfig.buyStar then return true end
    if offer.Rotates and currencyShopConfig.buyRotatingGems then return true end
    if offer.Rarity and currencyShopConfig.buyShards then return true end
    return false
end

local function runCurrencyShopAutoBuy(isSilent)
    return withShopLock(function()
        local stateOk, st = call("GetState")
        if not stateOk or type(st) ~= "table" then
            if not isSilent then notify("🪙 Currency Shop", "ดึงข้อมูลสถานะไม่ได้", 3) end
            return 0
        end

        local gold = tonumber(st.Gold) or 0
        local gems = tonumber(st.Gems or st.Gem) or 0
        local activeColors = getActiveColors()

        local boughtCount = 0
        local boughtList = {}

        local allOffers = {}
        for _, item in ipairs(currencyShopDB.Gold) do table.insert(allOffers, item) end
        for _, item in ipairs(currencyShopDB.Gems) do table.insert(allOffers, item) end

        for _, offer in ipairs(allOffers) do
            if not alive() then break end
            local isAvailable = (not offer.Rotates) or (activeColors[offer.Item] == true)
            if isAvailable and shouldBuyCurrencyOffer(offer) then
                local left = getCurrencyShopLeft(offer, st)
                if left > 0 then
                    local price = offer.Price or 0
                    local cur = offer.Currency or "Gold"
                    local qty = calcQty(left, price, (cur == "Gold") and gold or gems)

                    if qty > 0 then
                        local success = buyCurrencyShopItem(offer, qty)
                        if success then
                            boughtCount = boughtCount + 1
                            local cost = price * qty
                            if cur == "Gold" then gold = gold - cost else gems = gems - cost end
                            table.insert(boughtList, string.format("%s (x%s)", tostring(offer.Name or offer.Item), tostring(qty)))
                            print(string.format("[CurrencyShop AutoBuy] ซื้อ %s x%s สำเร็จ (ใช้ %s %s)", tostring(offer.Item), tostring(qty), tostring(cost), tostring(cur)))
                        end
                        task.wait(0.2)
                    end
                end
            end
        end

        if boughtCount > 0 then
            notify("🪙 Currency Shop ซื้อสำเร็จ!", "ซื้อ " .. table.concat(boughtList, ", "), 4)
        elseif not isSilent then
            notify("🪙 Currency Shop", "ไม่มีไอเทมที่เลือก หรือเงินไม่พอ", 3)
        end
        return boughtCount
    end)
end

-- ==========================================
-- 14. ตัวช่วยกดปุ่ม GUI ของเกม (รองรับหลาย executor)
-- ==========================================

-- เช็คว่าปุ่มแสดงอยู่จริงบนจอ (ตัวเองและพ่อทุกชั้น Visible และ ScreenGui Enabled)
local function isShown(obj)
    local cur = obj
    while cur do
        if cur:IsA("GuiObject") then
            if not cur.Visible then
                return false
            end
        elseif cur:IsA("LayerCollector") then
            return cur.Enabled and obj.AbsoluteSize.X > 1 and obj.AbsoluteSize.Y > 1
        end
        cur = cur.Parent
    end
    return false
end

-- อ่านข้อความบนปุ่ม (ถ้าเป็น ImageButton จะอ่านจาก TextLabel ข้างใน) และตัด rich text ออก
local function buttonText(btn)
    local txt = ""
    if btn:IsA("TextButton") then
        txt = btn.Text or ""
    end
    if txt == "" then
        local lbl = btn:FindFirstChildWhichIsA("TextLabel", true)
        if lbl then
            txt = lbl.Text or ""
        end
    end
    txt = string.gsub(txt, "<[^>]->", "")
    return string.lower(txt)
end

-- กดปุ่มของเกม: ลอง getconnections ก่อน (แม่นสุด) แล้ว firesignal แล้วจำลองการแตะจอ
local function pressButton(btn)
    local checkedConnections = false

    if type(getconnections) == "function" then
        for _, sigName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Down" }) do
            local okSig, sig = pcall(function() return btn[sigName] end)
            if okSig and sig then
                local okC, conns = pcall(getconnections, sig)
                if okC and type(conns) == "table" then
                    checkedConnections = true
                    if #conns > 0 then
                        local fired = false
                        for _, c in ipairs(conns) do
                            local okF = pcall(function() c:Fire() end)
                            if not okF then
                                okF = pcall(function() c.Function() end)
                            end
                            if okF then
                                fired = true
                            end
                        end
                        if fired then
                            return true
                        end
                    end
                end
            end
        end
    end

    -- ถ้า getconnections ใช้ได้แต่ปุ่มไม่มี connection เลย firesignal ก็จะไม่มีผล จึงข้ามไปจำลองการแตะ
    if not checkedConnections and type(firesignal) == "function" then
        local ok = pcall(firesignal, btn.Activated)
        if ok then
            return true
        end
    end

    if VIM and isShown(btn) then
        local ok = pcall(function()
            local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
            local sg = btn:FindFirstAncestorWhichIsA("ScreenGui")
            local inset = GuiService:GetGuiInset()
            local y = pos.Y + ((sg and not sg.IgnoreGuiInset) and inset.Y or 0)
            VIM:SendMouseButtonEvent(pos.X, y, 0, true, game, 0)
            task.wait(0.05)
            VIM:SendMouseButtonEvent(pos.X, y, 0, false, game, 0)
        end)
        return ok
    end
    return false
end

local function getPlayerGuiScreen(name)
    local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    local gui = pGui and pGui:FindFirstChild(name)
    if gui and gui:IsA("LayerCollector") and gui.Enabled then
        return gui
    end
    return nil
end

-- ฟังก์ชันตรวจสอบว่าตัวละครอยู่ในห้องหรือยัง (ผ่าน UI ของเกม)
local function isInRoom()
    return getPlayerGuiScreen("PlayMenu") ~= nil or getPlayerGuiScreen("ReadyRoom") ~= nil
end

-- กดปุ่มบน GUI ของเกมตามข้อความ (เช่นปุ่ม Start บน PlayMenu)
local function clickGuiButton(guiName, targetText)
    local gui = getPlayerGuiScreen(guiName)
    if not gui then
        return false
    end
    targetText = string.lower(targetText)
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            if string.find(buttonText(d), targetText, 1, true) then
                return pressButton(d)
            end
        end
    end
    return false
end

-- ==========================================
-- 15. ระบบ AUTO PLAY & AUTO FARM ขั้นสูง
-- ==========================================

-- ส่งการตั้งค่า Battle Settings ไปยังเซิร์ฟเวอร์
local function applyServerBattleSettings()
    if farmCfg.AutoSkills then
        call("TeamAuto", true)
    end
    if farmCfg.AutoReplay then
        call("BattleSetting", "AutoReplay", true)
        call("BattleSetting", "AutoNext", false)
    elseif farmCfg.AutoNext then
        call("BattleSetting", "AutoNext", true)
        call("BattleSetting", "AutoReplay", false)
    end
    if farmCfg.LowGraphics then
        call("BattleSetting", "LowDetail", true)
        call("BattleSetting", "NoVfx", true)
        call("BattleSetting", "NoNumbers", true)
    end
end

-- ค้นหาห้องว่างใน Lobby ตามโหมดที่เลือก (ครอบคลุมทุกโหมด)
local function findPlayRoom(targetMode)
    targetMode = targetMode or "Story"

    -- 1. ค้นหาจาก CollectionService:GetTagged("PlayRoom")
    local rooms = CollectionService:GetTagged("PlayRoom")
    for _, r in ipairs(rooms) do
        local rMode = r:GetAttribute("Mode") or "Story"
        local mem = r:GetAttribute("Members") or 0
        local zone = r:FindFirstChild("Zone")
        if zone and rMode == targetMode and mem == 0 then
            return r, zone
        end
    end

    -- 2. ถ้าไม่มีห้องว่าง 0 คน ให้หาห้องในโหมดนั้นที่มี Zone
    for _, r in ipairs(rooms) do
        local rMode = r:GetAttribute("Mode") or "Story"
        local zone = r:FindFirstChild("Zone")
        if zone and rMode == targetMode then
            return r, zone
        end
    end

    -- 3. ค้นหาจาก workspace.Lobby.Areas
    local lobby = workspace:FindFirstChild("Lobby")
    local areas = lobby and lobby:FindFirstChild("Areas")
    if areas then
        local areaMap = { Story = "Play", Raid = "Raid", Castle = "Castle", Challenge = "Challenge" }
        local areaName = areaMap[targetMode] or "Play"
        local area = areas:FindFirstChild(areaName) or areas:FindFirstChild("Play")

        if area then
            local rFolder = area:FindFirstChild("Rooms")
            if rFolder then
                for _, r in ipairs(rFolder:GetChildren()) do
                    local z = r:FindFirstChild("Zone")
                    local mem = r:GetAttribute("Members") or 0
                    if z and mem == 0 then
                        return r, z
                    end
                end
                for _, r in ipairs(rFolder:GetChildren()) do
                    local z = r:FindFirstChild("Zone")
                    if z then
                        return r, z
                    end
                end
            end

            local directZone = area:FindFirstChild("Zone") or area:FindFirstChild("Floor") or area:FindFirstChild("Spawn")
            if directZone then
                return area, directZone
            end
        end
    end

    -- 4. Fallback: คืนห้องแรกที่มี Zone
    for _, r in ipairs(rooms) do
        local z = r:FindFirstChild("Zone")
        if z then
            return r, z
        end
    end

    return nil, nil
end

-- รอ HumanoidRootPart แบบมี timeout (ไม่ค้างตลอดไปถ้าตัวละครยังไม่เกิด)
local function getHRP(timeout)
    local t0 = os.clock()
    while alive() do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            return hrp
        end
        if os.clock() - t0 > (timeout or 10) then
            break
        end
        task.wait(0.2)
    end
    return nil
end

-- วาร์ปตัวละครและกระตุ้นการเหยียบ Zone
local function triggerZoneTouch(zone)
    if not (zone and zone.Parent) then
        return false
    end
    local part = zone
    if not part:IsA("BasePart") then
        part = (part:IsA("Model") and part.PrimaryPart) or part:FindFirstChildWhichIsA("BasePart", true)
        if not part then
            return false
        end
    end
    local hrp = getHRP(8)
    if not hrp then
        return false
    end

    pcall(function()
        hrp.CFrame = part.CFrame + Vector3.new(0, 0.5, 0)
        hrp.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
    end)

    -- กระตุ้น TouchInterest ทันทีถ้า executor รองรับ
    if type(firetouchinterest) == "function" then
        pcall(firetouchinterest, hrp, part, 0)
        task.wait(0.05)
        pcall(firetouchinterest, hrp, part, 1)
    end
    return true
end

-- ✨ ดำเนินการเข้าห้องและเริ่ม Auto Play
local function enterAndStartAutoPlay(manual)
    if IN_BATTLE then
        if manual then notify("⚔️ Auto Play", "ตอนนี้อยู่ในด่านแล้ว ใช้ปุ่มนี้ได้เฉพาะใน Lobby", 3) end
        return
    end
    if state.startingRoom then
        if manual then setStatus("⏳ กำลังเข้าห้องอยู่แล้ว รอสักครู่...") end
        return
    end
    if state.teleporting then
        return
    end
    state.startingRoom = true
    state.lastStartAttempt = os.clock()

    task.spawn(function()
        local ok, err = pcall(function()
            sanitizeFarm()
            local mode, world, stage, difficulty = farmCfg.Mode, farmCfg.World, farmCfg.Stage, farmCfg.Difficulty
            setStatus(string.format("🎯 เตรียมลุย [%s W%s S%s %s]", mode, tostring(world), tostring(stage), difficulty))

            -- 1. ปรับค่า Battle Settings (AutoSkills, AutoReplay, LowDetail)
            applyServerBattleSettings()

            -- 2. ตรวจสอบว่าเข้าห้องอยู่แล้วหรือยัง
            if not isInRoom() then
                -- ออกจากห้องเก่าก่อน (ถ้ามีค้าง)
                call("LeaveRoom")
                call("CancelRoom")
                if not sleep(0.3) then return end

                local _, zone = findPlayRoom(mode)
                if not zone then
                    notify("⚔️ Auto Play", "❌ ไม่พบแท่นเข้าห้องสำหรับ " .. mode, 4)
                    return
                end

                setStatus("📍 วาร์ปไปที่แท่นห้อง...")
                triggerZoneTouch(zone)

                -- รอให้เซิร์ฟเวอร์ตอบรับการเข้าห้อง (PlayMenu หรือ ReadyRoom ปรากฏ)
                local t0 = os.clock()
                while alive() and not isInRoom() and os.clock() - t0 < 5 do
                    task.wait(0.4)
                    triggerZoneTouch(zone)
                end
                if not isInRoom() then
                    setStatus("⚠️ เข้าห้องช้า กำลังลองส่งคำสั่งโดยตรง...")
                end
            end
            if not alive() then return end

            local stagePayload = {
                Mode = mode,
                World = world,
                Stage = stage,
                Difficulty = difficulty,
                Tier = 1
            }

            -- 3. ส่งคำสั่งเลือกด่าน (RoomPick)
            setStatus("⚙️ กำลังเลือกด่าน...")
            call("RoomPick", stagePayload)
            sleep(0.3)

            -- 4. ล็อกเล่นคนเดียว (Solo)
            if farmCfg.Solo then
                call("RoomOpen", false)
                sleep(0.2)
            end

            -- 5. ส่งคำสั่งพร้อม (ReadyRoom) และกดปุ่ม Start บน PlayMenu
            setStatus("⏳ ส่งคำสั่งพร้อม (Ready)...")
            local readyOk, readyRes = call("ReadyRoom", stagePayload)
            clickGuiButton("PlayMenu", "start")
            sleep(0.5)

            if readyOk and type(readyRes) == "table" and readyRes.Ok == false and readyRes.Error then
                notify("❌ พร้อมด่านนี้ไม่ได้", tostring(readyRes.Error), 5)
                return
            end

            -- 6. รอให้ ReadyRoom GUI เปิด
            local t1 = os.clock()
            while alive() and os.clock() - t1 < 2 do
                if getPlayerGuiScreen("ReadyRoom") then break end
                task.wait(0.2)
            end

            -- 7. ส่งคำสั่งเริ่มด่าน (StartRoom) และ fallback แบบส่ง payload
            setStatus("🚀 เริ่มด่าน (StartRoom)...")
            local startOk, startRes = call("StartRoom")
            if not startOk or (type(startRes) == "table" and startRes.Ok == false) then
                startOk, startRes = call("StartRoom", stagePayload)
            end
            clickGuiButton("ReadyRoom", "start")

            if startOk and type(startRes) == "table" and startRes.Ok == false and startRes.Error then
                notify("❌ เริ่มเกมไม่สำเร็จ", tostring(startRes.Error), 4)
            else
                notify("⚔️ Auto Play", "✅ ส่งคำสั่งเริ่มเกมแล้ว กำลังเข้าแมพ...", 3)
            end
            sleep(3)
        end)

        if not ok then
            warn("[AutoPlay] " .. tostring(err))
            notify("⚔️ Auto Play", "ผิดพลาด: " .. tostring(err), 4)
        end
        state.startingRoom = false
    end)
end

local function leaveCurrentRoom()
    local ok, res = call("LeaveRoom")
    if ok and type(res) == "table" and typeof(res.Exit) == "CFrame" then
        local char = LocalPlayer.Character
        if char then
            pcall(function() char:PivotTo(res.Exit) end)
        end
    end
    call("CancelRoom")
    notify("⚔️ Auto Play", "ออกจากห้องเรียบร้อย", 2)
end

-- ==========================================
-- 16. GUI สำหรับมือถือ
-- ==========================================
local GUI_NAME = "AnimeAshuraHub"

local C = {
    bg = Color3.fromRGB(20, 18, 25),
    panel = Color3.fromRGB(30, 27, 38),
    card = Color3.fromRGB(36, 33, 46),
    cardOn = Color3.fromRGB(28, 54, 40),
    off = Color3.fromRGB(55, 51, 68),
    disabled = Color3.fromRGB(32, 30, 38),
    on = Color3.fromRGB(39, 174, 96),
    accent = Color3.fromRGB(255, 120, 200),
    text = Color3.fromRGB(240, 240, 245),
    sub = Color3.fromRGB(180, 180, 195),
    dim = Color3.fromRGB(105, 102, 115),
    dark = Color3.fromRGB(25, 20, 30),
    white = Color3.fromRGB(255, 255, 255),
    blue = Color3.fromRGB(52, 152, 219),
    steel = Color3.fromRGB(52, 73, 94),
    orange = Color3.fromRGB(230, 126, 34),
    shop = Color3.fromRGB(255, 170, 70),
    purple = Color3.fromRGB(155, 89, 182),
    luck = Color3.fromRGB(156, 39, 176),
    red = Color3.fromRGB(231, 76, 60),
    gold = Color3.fromRGB(241, 196, 15),
    stroke = Color3.fromRGB(80, 75, 100),
    danger = Color3.fromRGB(130, 32, 45)
}

-- เลือกที่วาง GUI: gethui (Delta รองรับ) → CoreGui → PlayerGui
local function pickGuiParent()
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and typeof(h) == "Instance" then
            return h
        end
    end
    local ok, core = pcall(function()
        local cg = game:GetService("CoreGui")
        local probe = Instance.new("Folder")
        probe.Name = "AAH_Probe"
        probe.Parent = cg
        probe:Destroy()
        return cg
    end)
    if ok and core then
        return core
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function removeOldGui(parent)
    if not parent then return end
    pcall(function()
        for _, ch in ipairs(parent:GetChildren()) do
            if ch.Name == GUI_NAME then
                ch:Destroy()
            end
        end
    end)
end

local guiParent = pickGuiParent()
removeOldGui(guiParent)
pcall(function() removeOldGui(game:GetService("CoreGui")) end)
removeOldGui(LocalPlayer:FindFirstChildOfClass("PlayerGui"))

local function new(className, props, parent)
    local obj = Instance.new(className)
    if props then
        for k, v in pairs(props) do
            obj[k] = v
        end
    end
    if parent then
        obj.Parent = parent
    end
    return obj
end

local function corner(obj, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, obj)
end

-- ข้อความย่อ/ขยายเองให้พอดีปุ่มบนจอเล็ก
local function textFit(obj, maxSize, minSize)
    obj.TextScaled = true
    obj.TextWrapped = true
    new("UITextSizeConstraint", { MaxTextSize = maxSize or 14, MinTextSize = minSize or 8 }, obj)
end

local orderN = 0
local function nextOrder()
    orderN = orderN + 1
    return orderN
end

-- ผูกปุ่มแบบกันกดรัว: ระหว่างงานเดิมยังไม่เสร็จ การแตะซ้ำจะถูกข้าม
local function bindTap(btn, fn)
    local busy = false
    btn.Activated:Connect(function()
        if busy then return end
        busy = true
        local ok, err = pcall(fn)
        busy = false
        if not ok then
            warn("[AAH:UI] " .. tostring(err))
            notify("⚠️ ผิดพลาด", tostring(err), 4)
        end
    end)
end

screenGui = new("ScreenGui", {
    Name = GUI_NAME,
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999
})
screenGui.Parent = guiParent

local function screenSize()
    local s = screenGui and screenGui.AbsoluteSize
    if s and s.X > 50 and s.Y > 50 then
        return s
    end
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 400)
    local inset = GuiService:GetGuiInset()
    return Vector2.new(vp.X, vp.Y - inset.Y)
end

-- ขนาดหน้าต่างตามจอ: มือถือแนวนอนจะได้ประมาณ 430x340
local function windowSize()
    local s = screenSize()
    local w = math.floor(math.clamp(s.X - 20, 260, 430))
    local h = math.floor(math.clamp(s.Y - 16, 220, 460))
    return w, h
end

local function clampXY(x, y, w, h)
    local s = screenSize()
    x = math.clamp(x, 0, math.max(0, s.X - w))
    y = math.clamp(y, 0, math.max(0, s.Y - h))
    return math.floor(x), math.floor(y)
end

-- ลากด้วยนิ้ว/เมาส์ได้ และคืนฟังก์ชันบอกว่าการแตะครั้งล่าสุดเป็นการลากหรือไม่
local function makeDraggable(handles, target)
    local dragging = false
    local dragInput, startInputPos, startPos = nil, nil, nil
    local moved = false

    local function begin(input)
        local t = input.UserInputType
        if t ~= Enum.UserInputType.Touch and t ~= Enum.UserInputType.MouseButton1 then
            return
        end
        dragging = true
        moved = false
        dragInput = input
        startInputPos = input.Position
        startPos = Vector2.new(target.Position.X.Offset, target.Position.Y.Offset)
    end

    for _, h in ipairs(handles) do
        h.InputBegan:Connect(begin)
    end

    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input ~= dragInput and input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end
        local d = input.Position - startInputPos
        if math.abs(d.X) + math.abs(d.Y) > 8 then
            moved = true
        end
        local size = target.AbsoluteSize
        local x, y = clampXY(startPos.X + d.X, startPos.Y + d.Y, size.X, size.Y)
        target.Position = UDim2.fromOffset(x, y)
    end))

    track(UserInputService.InputEnded:Connect(function(input)
        if input == dragInput or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            dragInput = nil
        end
    end))

    return function() return moved end
end

-- ----------------- MAIN WINDOW -----------------
local main = new("Frame", {
    Name = "Main",
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0,
    Active = true,
    ClipsDescendants = true,
    Size = UDim2.fromOffset(360, 320),
    Position = UDim2.fromOffset(10, 10)
}, screenGui)
corner(main, 12)
new("UIStroke", { Color = C.stroke, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, main)

local header = new("Frame", {
    Name = "Header",
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    Active = true,
    Size = UDim2.new(1, 0, 0, 40)
}, main)
corner(header, 12)

local titleLbl = new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(12, 0),
    Size = UDim2.new(1, -70, 1, 0),
    Font = Enum.Font.GothamBold,
    Text = "Anime Ashura Hub v2.1 📱",
    TextColor3 = C.accent,
    TextXAlignment = Enum.TextXAlignment.Left
}, header)
textFit(titleLbl, 16, 10)

local minBtn = new("TextButton", {
    AnchorPoint = Vector2.new(1, 0.5),
    Position = UDim2.new(1, -8, 0.5, 0),
    Size = UDim2.fromOffset(44, 30),
    BackgroundColor3 = C.off,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "—",
    TextSize = 16,
    TextColor3 = C.text
}, header)
corner(minBtn, 8)

local tabBar = new("Frame", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(8, 44),
    Size = UDim2.new(1, -16, 0, 34)
}, main)
new("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 4),
    SortOrder = Enum.SortOrder.LayoutOrder
}, tabBar)

local content = new("Frame", {
    BackgroundTransparency = 1,
    ClipsDescendants = true,
    Position = UDim2.fromOffset(6, 82),
    Size = UDim2.new(1, -12, 1, -112)
}, main)

statusLabel = new("TextLabel", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 26),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    Font = Enum.Font.Gotham,
    Text = "พร้อมใช้งาน • " .. (IN_BATTLE and "อยู่ในด่าน" or "อยู่ Lobby"),
    TextColor3 = C.sub,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd
}, main)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, statusLabel)

-- ----------------- FLOATING TOGGLE BUTTON -----------------
local floatBtn = new("TextButton", {
    Name = "ToggleButton",
    Size = UDim2.fromOffset(52, 52),
    Position = UDim2.fromOffset(8, 120),
    BackgroundColor3 = C.panel,
    BorderSizePixel = 0,
    Font = Enum.Font.GothamBold,
    Text = "AH",
    TextSize = 16,
    TextColor3 = C.accent,
    ZIndex = 10
}, screenGui)
corner(floatBtn, 26)
local floatStroke = new("UIStroke", { Color = C.accent, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, floatBtn)

local function setWindowOpen(open, save)
    main.Visible = open
    floatStroke.Color = open and C.accent or C.stroke
    floatBtn.TextColor3 = open and C.accent or C.sub
    if save and G.uiMinimized ~= (not open) then
        G.uiMinimized = not open
        queueSave()
    end
end

local floatWasDragged = makeDraggable({ floatBtn }, floatBtn)
makeDraggable({ header, titleLbl }, main)

floatBtn.Activated:Connect(function()
    if floatWasDragged() then return end
    setWindowOpen(not main.Visible, true)
end)
minBtn.Activated:Connect(function()
    setWindowOpen(false, true)
end)

-- ----------------- PAGES / TABS -----------------
local pages, tabBtns = {}, {}
local currentTab = nil
local switchTab, renderShop, refreshFarmUI

local function makePage(id, label, order)
    local page = new("ScrollingFrame", {
        Name = id,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 5,
        ScrollBarImageColor3 = C.stroke,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        Active = true,
        Visible = false
    }, content)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 4),
        PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 9)
    }, page)
    local layout = new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    local function fit()
        page.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 16)
    end
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fit)
    fit()

    local tb = new("TextButton", {
        Size = UDim2.new(0.25, -3, 1, 0),
        LayoutOrder = order,
        BackgroundColor3 = C.off,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = label,
        TextColor3 = C.text
    }, tabBar)
    corner(tb, 8)
    textFit(tb, 13, 8)
    tb.Activated:Connect(function()
        switchTab(id)
    end)

    pages[id] = page
    tabBtns[id] = tb
    return page
end

switchTab = function(id)
    currentTab = id
    for pid, p in pairs(pages) do
        p.Visible = (pid == id)
    end
    for pid, b in pairs(tabBtns) do
        local on = (pid == id)
        b.BackgroundColor3 = on and C.accent or C.off
        b.TextColor3 = on and C.dark or C.text
    end
    if id == "shop" and renderShop then
        task.spawn(renderShop)
    elseif id == "farm" and refreshFarmUI then
        refreshFarmUI()
    end
end

-- ----------------- UI COMPONENTS -----------------
local function section(parent, text, color)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 22),
        Font = Enum.Font.GothamBold,
        Text = text,
        TextColor3 = color or C.text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = nextOrder()
    }, parent)
end

local function infoText(parent, text, color, height)
    local l = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, height or 20),
        Font = Enum.Font.GothamSemibold,
        Text = text,
        TextColor3 = color or C.sub,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = nextOrder()
    }, parent)
    textFit(l, 13, 8)
    return l
end

local function actionButton(parent, text, color, fn, textColor)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = text,
        TextColor3 = textColor or C.white,
        LayoutOrder = nextOrder()
    }, parent)
    corner(b, 8)
    textFit(b, 14, 8)
    new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, b)
    bindTap(b, fn)
    return b
end

-- แถวเปิด/ปิด: แตะตรงไหนของแถวก็ได้ (เป้าใหญ่ กดง่ายบนมือถือ)
local function toggleRow(parent, label, get, set)
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        Text = "",
        LayoutOrder = nextOrder()
    }, parent)
    corner(row, 8)

    local lbl = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -88, 1, 0),
        Font = Enum.Font.GothamSemibold,
        Text = label,
        TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left
    }, row)
    textFit(lbl, 13, 8)

    local pill = new("TextLabel", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(64, 28),
        BackgroundColor3 = C.off,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamBold,
        Text = "ปิด",
        TextSize = 13,
        TextColor3 = C.white
    }, row)
    corner(pill, 14)

    local function refresh()
        local on = get() and true or false
        pill.Text = on and "เปิด" or "ปิด"
        pill.BackgroundColor3 = on and C.on or C.off
        row.BackgroundColor3 = on and C.cardOn or C.card
    end

    bindTap(row, function()
        set(not get())
        refresh()
    end)
    refresh()
    return refresh
end

-- แถวปุ่มเลือก 1 ตัวเลือก (โหมด / World / ด่าน / ความยาก)
local function segmented(parent, items, opts)
    local n = #items
    local row = new("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, opts.height or 38),
        LayoutOrder = nextOrder()
    }, parent)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder
    }, row)

    local btns = {}
    local function refresh()
        local current = opts.get()
        for _, it in ipairs(items) do
            local b = btns[it.id]
            local avail = (opts.available == nil) or opts.available(it.id)
            if opts.label then
                b.Text = opts.label(it.id)
            end
            if current == it.id and avail then
                b.BackgroundColor3 = (opts.colorFn and opts.colorFn(it.id)) or opts.color or C.accent
                b.TextColor3 = C.white
            elseif avail then
                b.BackgroundColor3 = C.off
                b.TextColor3 = C.text
            else
                b.BackgroundColor3 = C.disabled
                b.TextColor3 = C.dim
            end
        end
    end

    local gap = 4 * (n - 1) / n
    for i, it in ipairs(items) do
        local b = new("TextButton", {
            Size = UDim2.new(1 / n, -gap, 1, 0),
            LayoutOrder = i,
            BackgroundColor3 = C.off,
            BorderSizePixel = 0,
            Font = Enum.Font.GothamBold,
            Text = it.text or tostring(it.id),
            TextColor3 = C.text
        }, row)
        corner(b, 7)
        textFit(b, 13, 7)
        new("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 3) }, b)
        btns[it.id] = b

        b.Activated:Connect(function()
            if opts.available and not opts.available(it.id) then
                setStatus("ตัวเลือกนี้ไม่มีในโหมดที่เลือก")
                return
            end
            local ok, err = pcall(opts.set, it.id)
            if not ok then
                warn("[AAH:UI] " .. tostring(err))
            end
            refresh()
        end)
    end

    refresh()
    return refresh
end

local pageMain = makePage("main", "🏠 หลัก", 1)
local pageFarm = makePage("farm", "⚔️ ฟาร์ม", 2)
local pageShop = makePage("shop", "🛒 ร้าน", 3)
local pageSet = makePage("settings", "⚙️ ตั้งค่า", 4)

-- ================= แท็บ: หลัก =================
section(pageMain, "🎁 รางวัล & โค้ด", C.blue)
actionButton(pageMain, "🎁 รับเควส / รางวัลทั้งหมด", C.blue, function()
    claimAllEverything(false)
end)
toggleRow(pageMain, "⏳ วนลูป Auto Claim (ทุก 60 วิ)", function()
    return G.isAutoClaimLoop
end, function(v)
    G.isAutoClaimLoop = v
    queueSave()
    notify("🎁 Auto Claim", v and "เปิดวนลูปกดรับเควสอัตโนมัติ!" or "ปิดวนลูปกดรับเควสแล้ว", 2)
end)
actionButton(pageMain, "🏷️ ใส่โค้ดทั้งหมด (Redeem All)", C.orange, function()
    redeemAllCodes()
end)

section(pageMain, "🎰 สุ่มตัวละคร", C.accent)
actionButton(pageMain, "🧪 ใช้น้ำยา Luck (1 ขวด)", C.luck, function()
    useOneLuckPotion()
end)
refreshSummonToggle = toggleRow(pageMain, "🎰 Auto Summon 10x (ข้ามอนิเมชัน)", function()
    return state.summonToken ~= nil
end, function(v)
    if v then
        startAutoSummonLoop()
    else
        stopAutoSummon()
    end
end)
toggleRow(pageMain, "🛑 หยุดสุ่มเมื่อได้ Mythic / Secret", function()
    return G.stopOnMythicOrSecret
end, function(v)
    G.stopOnMythicOrSecret = v
    queueSave()
end)
toggleRow(pageMain, "🗑️ Auto Sell ตัว Rare ตอนสุ่ม", function()
    return G.autoSellRare
end, function(v)
    G.autoSellRare = v
    call("SetAutoSell", "Rare", v)
    queueSave()
end)
toggleRow(pageMain, "🗑️ Auto Sell ตัว Epic ตอนสุ่ม", function()
    return G.autoSellEpic
end, function(v)
    G.autoSellEpic = v
    call("SetAutoSell", "Epic", v)
    queueSave()
end)

-- ================= แท็บ: ฟาร์ม =================
local function targetText()
    local w = worldData(farmCfg.Mode, farmCfg.World)
    local s = w and w.Stages and w.Stages[farmCfg.Stage]
    return string.format("🎯 [%s] %s • %s (บอส: %s) [%s]",
        tostring(farmCfg.Mode),
        w and w.Name or ("World " .. tostring(farmCfg.World)),
        s and s.Name or ("ด่าน " .. tostring(farmCfg.Stage)),
        s and s.Boss or "?",
        tostring(farmCfg.Difficulty))
end

local farmInfoLabel = infoText(pageFarm, targetText(), C.gold, 34)

section(pageFarm, "1. โหมดเกม")
local refreshModeSeg = segmented(pageFarm, MODES, {
    get = function() return farmCfg.Mode end,
    set = function(id)
        if farmCfg.Mode ~= id then
            farmCfg.Mode = id
            farmCfg.World = 1
            farmCfg.Stage = 1
        end
        refreshFarmUI()
        queueSave()
    end,
    color = C.red
})

section(pageFarm, "2. World (แมพ)")
local refreshWorldSeg = segmented(pageFarm, { { id = 1 }, { id = 2 }, { id = 3 }, { id = 4 } }, {
    height = 42,
    get = function() return farmCfg.World end,
    set = function(id)
        farmCfg.World = id
        farmCfg.Stage = 1
        refreshFarmUI()
        queueSave()
    end,
    available = function(id) return worldData(farmCfg.Mode, id) ~= nil end,
    label = function(id)
        local w = worldData(farmCfg.Mode, id)
        return w and (tostring(id) .. ". " .. w.Name) or (tostring(id) .. ". —")
    end,
    color = C.blue
})

section(pageFarm, "3. ด่าน (Stage)")
local refreshStageSeg = segmented(pageFarm, {
    { id = 1 }, { id = 2 }, { id = 3 }, { id = 4 }, { id = 5 }, { id = 6 }
}, {
    get = function() return farmCfg.Stage end,
    set = function(id)
        farmCfg.Stage = id
        refreshFarmUI()
        queueSave()
    end,
    available = function(id) return id <= stageCount(farmCfg.Mode, farmCfg.World) end,
    color = C.purple
})

section(pageFarm, "4. ความยาก")
local refreshDiffSeg = segmented(pageFarm, DIFFS, {
    get = function() return farmCfg.Difficulty end,
    set = function(id)
        farmCfg.Difficulty = id
        refreshFarmUI()
        queueSave()
    end,
    colorFn = function(id) return DIFF_COLOR[id] end
})

refreshFarmUI = function()
    sanitizeFarm()
    refreshModeSeg()
    refreshWorldSeg()
    refreshStageSeg()
    refreshDiffSeg()
    farmInfoLabel.Text = targetText()
end

section(pageFarm, "5. ตัวช่วยการต่อสู้", C.gold)
toggleRow(pageFarm, "⚡ Auto Skills (บอทกดสกิลเอง)", function()
    return farmCfg.AutoSkills
end, function(v)
    farmCfg.AutoSkills = v
    call("TeamAuto", v)
    queueSave()
end)

local refreshAutoReplay, refreshAutoNext
refreshAutoReplay = toggleRow(pageFarm, "🔄 Auto Replay (เล่นด่านเดิมซ้ำ)", function()
    return farmCfg.AutoReplay
end, function(v)
    farmCfg.AutoReplay = v
    if v then
        farmCfg.AutoNext = false
        if refreshAutoNext then refreshAutoNext() end
        call("BattleSetting", "AutoReplay", true)
        call("BattleSetting", "AutoNext", false)
    else
        call("BattleSetting", "AutoReplay", false)
    end
    queueSave()
end)
refreshAutoNext = toggleRow(pageFarm, "⏩ Auto Next (ไปด่านถัดไปเมื่อชนะ)", function()
    return farmCfg.AutoNext
end, function(v)
    farmCfg.AutoNext = v
    if v then
        farmCfg.AutoReplay = false
        if refreshAutoReplay then refreshAutoReplay() end
        call("BattleSetting", "AutoNext", true)
        call("BattleSetting", "AutoReplay", false)
    else
        call("BattleSetting", "AutoNext", false)
    end
    queueSave()
end)
toggleRow(pageFarm, "💨 ลดแล็ก (Low Detail / ปิด VFX)", function()
    return farmCfg.LowGraphics
end, function(v)
    farmCfg.LowGraphics = v
    call("BattleSetting", "LowDetail", v)
    call("BattleSetting", "NoVfx", v)
    call("BattleSetting", "NoNumbers", v)
    queueSave()
end)
toggleRow(pageFarm, "🔒 เล่นคนเดียว (Solo ปิดห้อง)", function()
    return farmCfg.Solo
end, function(v)
    farmCfg.Solo = v
    queueSave()
end)

section(pageFarm, "6. เริ่มฟาร์ม", C.red)
toggleRow(pageFarm, "🔁 วนลูป Auto Farm (เข้าด่านซ้ำอัตโนมัติ)", function()
    return farmCfg.Enabled
end, function(v)
    farmCfg.Enabled = v
    queueSave()
    if v then
        notify("⚔️ Auto Farm", "เปิดวนลูป Auto Farm!", 3)
        if not IN_BATTLE then
            enterAndStartAutoPlay(true)
        end
    else
        notify("⚔️ Auto Farm", "ปิดวนลูป Auto Farm แล้ว", 2)
    end
end)
actionButton(pageFarm, "🚀 เริ่ม Auto Play เดี๋ยวนี้", Color3.fromRGB(46, 204, 113), function()
    enterAndStartAutoPlay(true)
end)
actionButton(pageFarm, "🚪 ออกจากห้องเดิม", Color3.fromRGB(70, 64, 82), function()
    leaveCurrentRoom()
end)

-- ================= แท็บ: ร้านค้า =================
local shopView = "Currency"
local shopTimerLabel = infoText(pageShop, "⏳ Merchant: --:--:--  |  Currency: --:--:--", C.sub, 20)

segmented(pageShop, {
    { id = "Merchant", text = "🛒 Merchant" },
    { id = "Currency", text = "🪙 Currency Shop" }
}, {
    get = function() return shopView end,
    set = function(id)
        shopView = id
        task.spawn(renderShop)
    end,
    color = C.shop
})

actionButton(pageShop, "🔄 รีเฟรชร้านค้า", C.steel, function()
    renderShop(true)
    setStatus("🛒 อัปเดตร้านค้าแล้ว")
end)

local shopList = new("Frame", {
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    LayoutOrder = nextOrder()
}, pageShop)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, shopList)

local function clearShopList()
    for _, ch in ipairs(shopList:GetChildren()) do
        if ch:IsA("GuiObject") then
            ch:Destroy()
        end
    end
end

local function listLabel(text, color, order)
    return new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 24),
        Font = Enum.Font.GothamBold,
        Text = text,
        TextColor3 = color or C.text,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order
    }, shopList)
end

local function shopCard(order, title, sub, titleColor, canBuy, btnText, onBuy)
    local card = new("Frame", {
        Size = UDim2.new(1, 0, 0, 52),
        BackgroundColor3 = canBuy and C.card or C.disabled,
        BorderSizePixel = 0,
        LayoutOrder = order
    }, shopList)
    corner(card, 8)

    local t = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 4),
        Size = UDim2.new(1, -104, 0, 24),
        Font = Enum.Font.GothamBold,
        Text = title,
        TextColor3 = canBuy and (titleColor or C.text) or C.dim,
        TextXAlignment = Enum.TextXAlignment.Left
    }, card)
    textFit(t, 13, 8)

    local s = new("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 28),
        Size = UDim2.new(1, -104, 0, 20),
        Font = Enum.Font.Gotham,
        Text = sub,
        TextColor3 = C.sub,
        TextXAlignment = Enum.TextXAlignment.Left
    }, card)
    textFit(s, 12, 7)

    local b = new("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(82, 36),
        BackgroundColor3 = canBuy and C.on or C.off,
        BorderSizePixel = 0,
        AutoButtonColor = canBuy,
        Font = Enum.Font.GothamBold,
        Text = btnText,
        TextColor3 = canBuy and C.white or C.dim
    }, card)
    corner(b, 8)
    textFit(b, 13, 8)
    if canBuy and onBuy then
        bindTap(b, onBuy)
    end
    return card
end

local renderGen = 0
renderShop = function(forceFetch)
    renderGen = renderGen + 1
    local my = renderGen
    local view = shopView

    if view == "Merchant" then
        local info
        if forceFetch or not cachedMerchantInfo then
            info = fetchMerchantInfo()
        else
            info = cachedMerchantInfo
        end
        -- ถ้ามีการเรนเดอร์ใหม่ซ้อนเข้ามาระหว่างรอเซิร์ฟ ให้ทิ้งรอบนี้ (กันการ์ดซ้ำ)
        if my ~= renderGen or not alive() then return end
        clearShopList()

        if not info or type(info.Stock) ~= "table" then
            listLabel("ไม่พบข้อมูลสต็อก กดรีเฟรชอีกครั้ง", C.dim, 1)
            return
        end

        for i, offer in ipairs(info.Stock) do
            if type(offer) == "table" then
                local left = getLeftStock(offer, info.Bought)
                local cur = offer.Currency or "Gold"
                local curIcon = (cur == "Gold") and "🟡 Gold" or "💎 Gems"
                local itemName = tostring(offer.Item or "Item")
                local title = string.format("%s (x%s)", itemName, tostring(offer.Amount or 1))
                local sub = string.format("ราคา %s %s • เหลือ %s", tostring(offer.Price or 0), curIcon, tostring(left))
                shopCard(i, title, sub, offer.Rare and C.gold or C.text, left > 0, left > 0 and "ซื้อ" or "หมดแล้ว", function()
                    local ok, err = buySingleMerchantItem(offer.Key, 1)
                    if ok then
                        notify("🛒 ซื้อสำเร็จ", "ซื้อ " .. itemName .. " เรียบร้อย!", 2)
                        fetchMerchantInfo()
                        task.spawn(renderShop)
                    else
                        notify("🛒 ไม่สำเร็จ", err or "ซื้อไม่ได้", 3)
                    end
                end)
            end
        end
    else
        local okState, st = call("GetState")
        if my ~= renderGen or not alive() then return end
        st = (okState and type(st) == "table") and st or {}
        local activeColors = getActiveColors()
        clearShopList()

        local order = 0
        local function nextListOrder()
            order = order + 1
            return order
        end

        local function renderOffer(offer)
            local left = getCurrencyShopLeft(offer, st)
            local isAvailable = (not offer.Rotates) or (activeColors[offer.Item] == true)
            local note = ""
            if offer.Rotates then
                note = isAvailable and " [รอบนี้ขาย]" or " [รอบนี้ปิด]"
            end
            local curIcon = (offer.Currency == "Gold") and "🟡 Gold" or "💎 Gems"
            local itemName = tostring(offer.Name or offer.Item)
            local sub = string.format("ราคา %s %s • เหลือ %s/%s", tostring(offer.Price), curIcon, tostring(left), tostring(offer.Stock or 1))
            local canBuy = isAvailable and left > 0
            local btnText = (not isAvailable) and "ปิดขาย" or (left > 0 and "ซื้อ" or "หมดแล้ว")
            shopCard(nextListOrder(), itemName .. note, sub, C.text, canBuy, btnText, function()
                local ok, err = buyCurrencyShopItem(offer, 1)
                if ok then
                    notify("🪙 ซื้อสำเร็จ", "ซื้อ " .. itemName .. " เรียบร้อย!", 2)
                    task.spawn(renderShop)
                else
                    notify("🪙 ไม่สำเร็จ", err or "ซื้อไม่ได้", 3)
                end
            end)
        end

        listLabel("🪙 Gold Shop (ใช้ Gold)", C.gold, nextListOrder())
        for _, offer in ipairs(currencyShopDB.Gold) do
            renderOffer(offer)
        end
        listLabel("💎 Gem Shop (ใช้ Gems)", C.accent, nextListOrder())
        for _, offer in ipairs(currencyShopDB.Gems) do
            renderOffer(offer)
        end
    end
end

-- ================= แท็บ: ตั้งค่า =================
local function cfgToggle(label, tbl, key)
    return toggleRow(pageSet, label, function()
        return tbl[key]
    end, function(v)
        tbl[key] = v
        queueSave()  -- ✨ บันทึกเมื่อเปลี่ยนค่า
    end)
end

section(pageSet, "🔁 Auto Buy อัตโนมัติ", C.on)
toggleRow(pageSet, "⏳ วนลูป Auto Buy ทุกร้าน (ทุก 30 วิ)", function()
    return G.isAutoShopLoop
end, function(v)
    G.isAutoShopLoop = v
    queueSave()
    notify("🛒 Auto Buy ร้านค้า", v and "เปิดซื้ออัตโนมัติทั้ง Merchant และ Currency Shop!" or "ปิดซื้ออัตโนมัติแล้ว", 3)
end)
toggleRow(pageSet, "🔔 ร้านรีเซ็ต → จบด่านแล้วกลับไปซื้อ", function()
    return G.restockExitBattle
end, function(v)
    G.restockExitBattle = v
    queueSave()
end)
actionButton(pageSet, "⚡ ซื้อของที่เลือกใน Currency Shop เดี๋ยวนี้", C.gold, function()
    runCurrencyShopAutoBuy(false)
end, C.dark)
actionButton(pageSet, "⚡ ซื้อของที่เลือกใน Merchant เดี๋ยวนี้", C.orange, function()
    runMerchantAutoBuy(false)
end)

section(pageSet, "🪙 Currency Shop (Gold & Gems)", C.gold)
cfgToggle("💰 Gold Shop ทั้งหมด (Dango / Dust / Rune)", currencyShopConfig, "buyAllGold")
cfgToggle("📜 Skill Scroll (150 Gems)", currencyShopConfig, "buyScroll")
cfgToggle("🔮 Trait Crystal (100 Gems)", currencyShopConfig, "buyTrait")
cfgToggle("⭐ Star Shard (300 Gems)", currencyShopConfig, "buyStar")
cfgToggle("💎 หินธาตุหมุนเวียน (5 สี)", currencyShopConfig, "buyRotatingGems")
cfgToggle("👥 Shards ตัวละคร (Mythic / Legendary / Epic)", currencyShopConfig, "buyShards")

section(pageSet, "🛒 Merchant (Rare Goods)", C.shop)
cfgToggle("💰 ของที่ใช้ Gold ทั้งหมด", merchantConfig, "buyAllGold")
cfgToggle("🧪 น้ำยา Luck (Super / Ultra)", merchantConfig, "buyLuck")
cfgToggle("🌈 Rainbow Shard", merchantConfig, "buyRainbow")
cfgToggle("🔮 Trait Crystal", merchantConfig, "buyTrait")
cfgToggle("⭐ Star Shard", merchantConfig, "buyStar")
cfgToggle("🧬 ไอเทม Evo ทั้งหมด", merchantConfig, "buyEvo")
cfgToggle("⚡ Stat Chip (ปกติ / Super)", merchantConfig, "buyChips")

section(pageSet, "💾 สคริปต์", C.sub)
local saveInfo
if not canFile then
    saveInfo = "⚠️ Executor ไม่รองรับ writefile: ตั้งค่าจะไม่ถูกบันทึก"
elseif savedData then
    saveInfo = "💾 โหลดการตั้งค่าที่บันทึกไว้เรียบร้อย"
else
    saveInfo = "💾 ยังไม่มีไฟล์ตั้งค่า (แก้ค่าแล้วจะ auto-save)"
end
infoText(pageSet, saveInfo, canFile and Color3.fromRGB(120, 220, 120) or C.gold, 20)
actionButton(pageSet, "💾 บันทึกตั้งค่าตอนนี้", C.steel, function()
    if persistCurrentSettings() then
        notify("💾 Settings", "บันทึกแล้ว", 2)
    else
        notify("💾 Settings", "บันทึกไม่สำเร็จ", 3)
    end
end)
actionButton(pageSet, "🛑 ปิดสคริปต์ทั้งหมด (หยุดทุกระบบ)", C.danger, function()
    persistCurrentSettings()
    notify("Anime Ashura Hub", "ปิดสคริปต์แล้ว รันใหม่เพื่อเปิดอีกครั้ง", 3)
    _G.__AAH_CLEANUP()
end)

-- ----------------- LAYOUT -----------------
local function layoutWindow(center)
    if not screenGui then return end
    local w, h = windowSize()
    main.Size = UDim2.fromOffset(w, h)
    local x, y
    if center then
        local s = screenSize()
        x, y = (s.X - w) / 2, (s.Y - h) / 2
    else
        x, y = main.Position.X.Offset, main.Position.Y.Offset
    end
    x, y = clampXY(x, y, w, h)
    main.Position = UDim2.fromOffset(x, y)

    local fx, fy = clampXY(floatBtn.Position.X.Offset, floatBtn.Position.Y.Offset, 52, 52)
    floatBtn.Position = UDim2.fromOffset(fx, fy)
end

task.wait()
do
    local s = screenSize()
    floatBtn.Position = UDim2.fromOffset(8, math.floor(s.Y * 0.4))
end
layoutWindow(true)
track(screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
    layoutWindow(false)
end))

switchTab("main")
refreshFarmUI()
setWindowOpen(not G.uiMinimized, false)

-- ==========================================
-- 17. BACKGROUND TASKS
-- ==========================================

-- จับสถานะการวาร์ป: ระหว่างวาร์ปจะไม่สั่งเข้าห้องซ้ำ และบันทึกค่าก่อนเซิร์ฟเปลี่ยน
track(LocalPlayer.OnTeleport:Connect(function(teleportState)
    if teleportState == Enum.TeleportState.Failed then
        state.teleporting = false
        setStatus("⚠️ วาร์ปไม่สำเร็จ")
    else
        if not state.teleporting then
            persistCurrentSettings()
        end
        state.teleporting = true
        state.teleportAt = os.clock()
        setStatus("🚀 กำลังวาร์ป...")
    end
end))

-- Task: วนลูป Auto Claim เบื้องหลัง
loop("AutoClaim", 60, function()
    if G.isAutoClaimLoop then
        claimAllEverything(true)
    end
end)

-- Task: วนลูป Auto Buy ทุกร้านค้าเบื้องหลัง
loop("AutoShop", 30, function()
    if G.isAutoShopLoop then
        runMerchantAutoBuy(true)
        runCurrencyShopAutoBuy(true)
    end
end)

-- Task: นาฬิกานับถอยหลังร้านค้า (ทำงานเฉพาะตอนเปิดแท็บร้าน)
local timerState = { lastFetch = 0, hour = nil }
loop("ShopTimer", 1, function()
    if not (main.Visible and currentTab == "shop") then
        timerState.hour = nil
        return
    end
    local now = getServerTime()
    local info = cachedMerchantInfo
    if not info and os.clock() - timerState.lastFetch > 15 then
        timerState.lastFetch = os.clock()
        info = fetchMerchantInfo()
    end

    local ends = info and tonumber(info.EndsAt)
    local mRemain = ends and (ends - now) or 0
    local cRemain = 3600 - (now % 3600)
    shopTimerLabel.Text = string.format("⏳ Merchant: %s  |  Currency: %s", formatClock(mRemain), formatClock(cRemain))

    if ends and mRemain <= 0 and os.clock() - timerState.lastFetch > 10 then
        timerState.lastFetch = os.clock()
        task.wait(1.5)
        fetchMerchantInfo()
        if shopView == "Merchant" then renderShop() end
    end

    local hour = math.floor(now / 3600)
    if timerState.hour and hour ~= timerState.hour and shopView == "Currency" then
        task.wait(1.5)
        renderShop()
    end
    timerState.hour = hour
end)

if not IN_BATTLE then
    -- ✨ Lobby: ซื้อของที่ค้าง (Restock) ก่อน แล้วค่อยเข้าด่าน และวนเข้าด่านใหม่อัตโนมัติ
    task.spawn(function()
        getHRP(20)
        if not sleep(3) then return end

        if G.restockPending then
            G.restockPending = false
            persistCurrentSettings()
            notify("🛒 Restock", "กลับมาที่ Lobby แล้ว! กำลังซื้อของ...", 3)
            sleep(2)
            runMerchantAutoBuy(false)
            sleep(0.5)
            runCurrencyShopAutoBuy(false)
            sleep(1)
        end

        -- ✨ ถ้าบันทึกไว้ว่าเปิด Auto Farm อยู่ ให้เริ่มเข้าห้องทันที
        if farmCfg.Enabled and alive() then
            print("[AutoFarm Loop] บันทึกไว้ว่าเปิดอยู่ → กำลังเข้าห้องอัตโนมัติ...")
            enterAndStartAutoPlay(false)
        end

        -- ✨ Lobby Re-entry Loop: ทุก 5 วินาที ถ้า Farm เปิดและไม่ได้กำลังเข้าห้อง/วาร์ป
        -- จะลองเข้าห้องใหม่ โดยเว้นอย่างน้อย 30 วินาทีจากครั้งก่อน เพื่อไม่ไปยกเลิกการวาร์ปที่กำลังเกิดขึ้น
        loop("LobbyFarm", 5, function()
            if state.teleporting and os.clock() - state.teleportAt > 60 then
                state.teleporting = false
            end
            if farmCfg.Enabled and not state.startingRoom and not state.teleporting
                and os.clock() - state.lastStartAttempt > 30 then
                print("[AutoFarm Loop] อยู่ใน Lobby + Farm เปิดอยู่ → เข้าห้องอัตโนมัติ")
                enterAndStartAutoPlay(false)
            end
        end)
    end)
else
    -- ==========================================
    -- ✨ Battle Place: Auto Skills + กดปุ่มผลลัพธ์ + Restock Exit
    -- ==========================================
    local RESULT_KEYWORDS = {
        replay = { { "replay", "play again", "again", "retry" }, { "vote" } },
        next = { { "next" }, { "vote" } },
        lobby = { { "lobby", "return" }, { "leave", "exit" } }
    }
    -- คำที่ห้ามกด: กันไปกดสวิตช์ Auto ของเกมเอง หรือปุ่มข้ามเวฟกลางด่าน
    local CLICK_EXCLUDE = { "auto", "wave", "skip", "setting" }
    local clickedAt = setmetatable({}, { __mode = "k" })

    local function keywordPriority(txt, groups, maxPriority)
        for _, w in ipairs(CLICK_EXCLUDE) do
            if string.find(txt, w, 1, true) then
                return nil
            end
        end
        for pri, words in ipairs(groups) do
            if maxPriority and pri > maxPriority then
                return nil
            end
            for _, w in ipairs(words) do
                if string.find(txt, w, 1, true) then
                    return pri
                end
            end
        end
        return nil
    end

    -- หาปุ่มที่ตรงคำค้นที่สุดใน PlayerGui (ข้าม GUI ของสคริปต์เอง)
    -- ปุ่มที่เพิ่งกดจะไม่ถูกกดซ้ำจนกว่าจะหายไปจากจอ หรือผ่านไป 20 วินาที
    local function findResultButton(kind, maxPriority)
        local groups = RESULT_KEYWORDS[kind]
        local pGui = LocalPlayer:FindFirstChildOfClass("PlayerGui")
        if not (groups and pGui) then
            return nil
        end
        local best, bestPri = nil, math.huge
        local now = os.clock()
        for _, g in ipairs(pGui:GetChildren()) do
            if g:IsA("ScreenGui") and g.Enabled and g ~= screenGui then
                for _, d in ipairs(g:GetDescendants()) do
                    if d:IsA("GuiButton") then
                        local last = clickedAt[d]
                        if last and not isShown(d) then
                            clickedAt[d] = nil
                            last = nil
                        end
                        if not last or now - last > 20 then
                            local txt = buttonText(d)
                            if txt ~= "" then
                                local pri = keywordPriority(txt, groups, maxPriority)
                                if pri and pri < bestPri and isShown(d) then
                                    best, bestPri = d, pri
                                end
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    -- ถ้าบันทึกไว้ว่ามี Restock ค้าง (เช่นโดนวาร์ปไปด่านใหม่ก่อนออกทัน) ให้ปิด Replay/Next ต่อ
    if G.restockPending then
        state.restockSince = os.clock()
        task.spawn(function()
            call("BattleSetting", "AutoReplay", false)
            call("BattleSetting", "AutoNext", false)
        end)
    end

    local lastTeamAuto = 0
    loop("BattleAuto", 2.5, function()
        if farmCfg.AutoSkills and os.clock() - lastTeamAuto > 8 then
            lastTeamAuto = os.clock()
            call("TeamAuto", true)
        end

        local kind, maxPri = nil, nil
        if G.restockPending then
            kind = "lobby"
            -- 4 นาทีแรกกดเฉพาะปุ่ม Lobby/Return (หน้าจบด่าน) หลังจากนั้นยอมกด Leave/Exit ด้วย
            maxPri = (state.restockSince and os.clock() - state.restockSince > 240) and 2 or 1
        elseif farmCfg.AutoNext then
            kind = "next"
        elseif farmCfg.AutoReplay or farmCfg.Enabled then
            kind = "replay"
        end
        if not kind then
            return
        end

        local btn = findResultButton(kind, maxPri)
        if btn then
            clickedAt[btn] = os.clock()
            local pressed = pressButton(btn)
            setStatus("🖱️ กดปุ่ม \"" .. buttonText(btn) .. "\"" .. (pressed and "" or " (ไม่สำเร็จ)"))
        end
    end)

    -- ✨ Restock Exit Watcher: ร้านรีเซ็ตระหว่างอยู่ในด่าน → ตั้งธงค้างไว้ แล้วกลับ Lobby เมื่อจบรอบ
    local lastCurrencyHour = math.floor(getServerTime() / 3600)
    local lastMerchantEndsAt = nil
    task.spawn(function()
        local info = fetchMerchantInfo()
        if info and tonumber(info.EndsAt) then
            lastMerchantEndsAt = tonumber(info.EndsAt)
        end
    end)

    loop("RestockWatch", 5, function()
        local now = getServerTime()
        local hour = math.floor(now / 3600)

        if G.restockPending then
            -- ถ้ารอนานเกิน 10 นาทีแล้วยังไม่กลับ Lobby ให้วาร์ปกลับเอง
            if state.restockSince and os.clock() - state.restockSince > 600 and not state.teleporting then
                state.restockSince = os.clock()
                notify("🛒 Restock", "รอนานเกิน 10 นาที → วาร์ปกลับ Lobby", 4)
                pcall(function() TeleportService:Teleport(LOBBY_PLACE, LocalPlayer) end)
            end
            return
        end

        if not (G.restockExitBattle and G.isAutoShopLoop) then
            -- ระบบปิดอยู่: เลื่อนตัวจำเวลาไปด้วย เปิดทีหลังจะได้ไม่ออกด่านทันทีโดยไม่จำเป็น
            lastCurrencyHour = hour
            if lastMerchantEndsAt and now >= lastMerchantEndsAt then
                lastMerchantEndsAt = lastMerchantEndsAt + 10800
            end
            return
        end

        local currencyRestocked = (hour ~= lastCurrencyHour)
        local merchantRestocked = (lastMerchantEndsAt ~= nil and now >= lastMerchantEndsAt)
        if not (currencyRestocked or merchantRestocked) then
            return
        end

        lastCurrencyHour = hour
        if merchantRestocked then
            lastMerchantEndsAt = lastMerchantEndsAt + 10800
            task.delay(5, function()
                local info = fetchMerchantInfo()
                if info and tonumber(info.EndsAt) then
                    lastMerchantEndsAt = tonumber(info.EndsAt)
                end
            end)
        end

        G.restockPending = true
        state.restockSince = os.clock()
        persistCurrentSettings()
        notify("🛒 Restock!", "ร้านรีเซ็ตแล้ว! จบรอบนี้จะกลับ Lobby ไปซื้อของ", 5)

        -- ปิด AutoReplay / AutoNext เพื่อให้ด่านจบแล้วกลับ Lobby
        call("BattleSetting", "AutoReplay", false)
        call("BattleSetting", "AutoNext", false)
    end)
end

-- ✨ บันทึกค่าเริ่มต้นเฉพาะเมื่อยังไม่เคยมีไฟล์ save
if not savedData then
    persistCurrentSettings()
end

local loadMsg = savedData and "โหลดการตั้งค่าที่บันทึกไว้แล้ว 💾" or "พร้อมใช้งาน! แก้ค่าแล้วจะ auto-save 💾"
notify("Anime Ashura Hub v2.1 📱", loadMsg, 4)
