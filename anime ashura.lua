-- =======================================================
-- Anime Ashura [UPD 05] - All-in-One Auto Script v2.0
-- (Save/Load Settings, Auto Claim, Auto Code, Auto Summon,
--  Merchant & Currency Shop + Restock Exit, Enhanced Auto Farm)
-- =======================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local VirtualUser = game:GetService("VirtualUser")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Kingdom = ReplicatedStorage:WaitForChild("Kingdom", 15)
if not Kingdom then
    warn("[AutoScript] ไม่พบโฟลเดอร์ Kingdom!")
    return
end

local Remotes = Kingdom:WaitForChild("Remotes", 10)
local Request = Remotes:WaitForChild("Request", 10)

-- โหลด Config และ Goals
local Config = pcall(function() return require(Kingdom:WaitForChild("Config", 5)) end) and require(Kingdom.Config) or nil
local Goals = pcall(function() return require(Kingdom:WaitForChild("Goals", 5)) end) and require(Kingdom.Goals) or nil

-- ==========================================
-- ระบบ SAVE / LOAD ตั้งค่า (Persistent Settings)
-- ==========================================
local SETTINGS_FILE = "AnimeAshura_Settings.json"

local function saveSettings(data)
    local ok, err = pcall(function()
        local json = HttpService:JSONEncode(data)
        writefile(SETTINGS_FILE, json)
    end)
    if not ok then
        warn("[SaveSettings] บันทึกไม่สำเร็จ: " .. tostring(err))
    end
end

local function loadSettings()
    local ok, result = pcall(function()
        local exists = false
        if pcall(function() return isfile(SETTINGS_FILE) end) then
            exists = isfile(SETTINGS_FILE)
        else
            local test = pcall(function() return readfile(SETTINGS_FILE) end)
            exists = test
        end
        if exists then
            local raw = readfile(SETTINGS_FILE)
            if raw and raw ~= "" then
                return HttpService:JSONDecode(raw)
            end
        end
        return nil
    end)
    if ok and result and type(result) == "table" then
        return result
    end
    return nil
end

local function mergeDefaults(saved, defaults)
    if not saved then return defaults end
    for k, v in pairs(defaults) do
        if saved[k] == nil then
            saved[k] = v
        end
    end
    return saved
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
    isAutoShopLoop = false,
    isAutoClaimLoop = false,
    restockExitBattle = true  -- ✨ ระบบออกจากด่านเมื่อร้านค้ารีเซ็ต
}

-- โหลดค่าที่บันทึกไว้ (ถ้ามี)
local savedData = loadSettings()
local savedFarm = savedData and savedData.farm or nil
local savedMerchant = savedData and savedData.merchant or nil
local savedCurrency = savedData and savedData.currency or nil
local savedGeneral = savedData and savedData.general or nil

-- ระบบ Anti-AFK ป้องกันโดนเตะ 20 นาที
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Anime Ashura",
            Text = text or "",
            Duration = duration or 3
        })
    end)
end

-- ฟังก์ชันช่วยคำนวณเวลานับถอยหลัง (HH:MM:SS)
local function formatClock(seconds)
    if not seconds or seconds <= 0 then return "00:00:00" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local function getServerTime()
    local ok, t = pcall(function() return workspace:GetServerTimeNow() end)
    if ok and t then return math.floor(t) end
    return os.time()
end

-- ==========================================
-- ฐานข้อมูลด่านและแมพ (Stage Database)
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

-- ==========================================
-- ตัวแปรสถานะ (โหลดจากไฟล์ที่บันทึก)
-- ==========================================
local generalConfig = mergeDefaults(savedGeneral, defaultGeneralConfig)
local stopOnMythicOrSecret = (generalConfig.stopOnMythicOrSecret ~= false)
local autoSellRare = (generalConfig.autoSellRare ~= false)
local autoSellEpic = (generalConfig.autoSellEpic == true)
local isAutoClaimLoop = (generalConfig.isAutoClaimLoop == true)
local isAutoShopLoop = (generalConfig.isAutoShopLoop == true)
local isAutoSummoning = false

-- ตัวแปร Merchant & Currency Shop
local cachedMerchantInfo = nil

local merchantConfig = mergeDefaults(savedMerchant, defaultMerchantConfig)
local currencyShopConfig = mergeDefaults(savedCurrency, defaultCurrencyShopConfig)

-- ตัวแปรระบบ AUTO PLAY / AUTO FARM ขั้นสูง (โหลดจากไฟล์ที่บันทึก)
local farmCfg = mergeDefaults(savedFarm, defaultFarmConfig)
_G.AnimeAshura_AutoFarm = farmCfg

-- ✨ ระบบ Restock Exit Battle
local restockExitBattle = generalConfig.restockExitBattle
local _restockPending = false  -- แฟล็กบอกว่ามี restock ค้างอยู่ ต้องกลับ lobby ไปซื้อ

-- ==========================================
-- ✨ ฟังก์ชันบันทึกตั้งค่าปัจจุบันลงไฟล์
-- ==========================================
local function persistCurrentSettings()
    local cfg = _G.AnimeAshura_AutoFarm or {}
    local data = {
        farm = {
            Enabled = (cfg.Enabled == true),
            Mode = cfg.Mode or "Story",
            World = tonumber(cfg.World) or 1,
            Stage = tonumber(cfg.Stage) or 1,
            Difficulty = cfg.Difficulty or "Easy",
            Solo = (cfg.Solo ~= false),
            AutoSkills = (cfg.AutoSkills ~= false),
            AutoReplay = (cfg.AutoReplay == true),
            AutoNext = (cfg.AutoNext == true),
            LowGraphics = (cfg.LowGraphics ~= false)
        },
        merchant = merchantConfig,
        currency = currencyShopConfig,
        general = {
            isAutoClaimLoop = (isAutoClaimLoop == true),
            isAutoShopLoop = (isAutoShopLoop == true),
            stopOnMythicOrSecret = (stopOnMythicOrSecret ~= false),
            autoSellRare = (autoSellRare ~= false),
            autoSellEpic = (autoSellEpic == true),
            restockExitBattle = (restockExitBattle ~= false)
        }
    }
    saveSettings(data)
end

-- ==========================================
-- ✨ Auto-Save ทุกครั้งที่เปลี่ยนค่า (Debounce)
-- ==========================================
local _saveQueued = false
local function queueSave()
    if _saveQueued then return end
    _saveQueued = true
    task.delay(1, function()
        _saveQueued = false
        persistCurrentSettings()
    end)
end

-- UI References
local summonBtn = nil
local loopClaimBtn = nil
local stopToggleBtn = nil
local shopFrame = nil
local loopShopBtn = nil
local merchantTimerLabel = nil
local stockContainer = nil
local currencyContainer = nil
local autoFarmFrame = nil
local farmLoopBtn = nil
local farmInfoLabel = nil
local autoSkillsBtn = nil
local autoReplayBtn = nil
local autoNextBtn = nil
local lowGfxBtn = nil

local function updateSummonUI(enabled)
    if not summonBtn then return end
    if enabled then
        summonBtn.Text = "🎰 Auto Summon 10x: [ เปิดใช้งาน ]"
        summonBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
    else
        summonBtn.Text = "🎰 Auto Summon 10x (Skip): [ ปิด ]"
        summonBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
    end
end

-- ==========================================
-- 1. ฟังก์ชัน AUTO CLAIM เควสทุกอย่าง
-- ==========================================
local function claimAllEverything()
    pcall(function() Request:InvokeServer("ClaimAllMissions") end)
    pcall(function() Request:InvokeServer("ClaimDaily") end)
    pcall(function() Request:InvokeServer("ClaimAllMilestones") end)
    pcall(function() Request:InvokeServer("BattlePassClaimAll") end)
    pcall(function() Request:InvokeServer("HollowLoginClaim") end)
    pcall(function() Request:InvokeServer("ClaimSkipGift") end)
    pcall(function() Request:InvokeServer("JoinGiftClaim") end)

    if Goals then
        if Goals.AchievementGroups then
            for _, grp in ipairs(Goals.AchievementGroups) do
                pcall(function()
                    Request:InvokeServer("ClaimAchievementGroup", grp.Id)
                    if grp.ChestGoal and grp.ChestGoal.Id then
                        Request:InvokeServer("ClaimAchievement", grp.ChestGoal.Id)
                    end
                end)
            end
        end
        if Goals.Achievements then
            for _, ach in ipairs(Goals.Achievements) do
                pcall(function() Request:InvokeServer("ClaimAchievement", ach.Id) end)
            end
        end
    end
    notify("Auto Claim", "กดรับของรางวัลทั้งหมดเรียบร้อย!", 2)
end

local function setAutoClaimLoop(enabled)
    isAutoClaimLoop = enabled
    if loopClaimBtn then
        if isAutoClaimLoop then
            loopClaimBtn.Text = "⏳ วนลูป Auto Claim: [ เปิด ]"
            loopClaimBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        else
            loopClaimBtn.Text = "⏳ วนลูป Auto Claim: [ ปิด ]"
            loopClaimBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
        end
    end
end

-- เธรดสำหรับวนลูป Auto Claim เบื้องหลัง
task.spawn(function()
    while true do
        if isAutoClaimLoop then
            claimAllEverything()
        end
        task.wait(60)
    end
end)

-- ==========================================
-- 2. ฟังก์ชัน AUTO REDEEM CODES
-- ==========================================
local function redeemAllCodes()
    local codeList = { "RELEASE", "SAKURA", "300CCU", "1KLIKES", "HUECOMUNDO", "2KLIKES", "800CCU", "3KLIKES" }
    if Config and Config.Codes then
        for code, _ in pairs(Config.Codes) do
            if not table.find(codeList, code) then
                table.insert(codeList, code)
            end
        end
    end

    local successCount = 0
    for _, code in ipairs(codeList) do
        local ok, res = pcall(function() return Request:InvokeServer("Redeem", code) end)
        if ok and res and res.Ok then
            successCount = successCount + 1
        end
        task.wait(0.35)
    end
    notify("Auto Redeem", "ใส่โค้ดทั้งหมดเสร็จสิ้น (สำเร็จ " .. successCount .. " โค้ด)", 3)
end

-- ==========================================
-- 3. ฟังก์ชัน ใช้น้ำยา LUCK (1 ขวด)
-- ==========================================
local function useOneLuckPotion()
    local state = pcall(function() return Request:InvokeServer("GetState") end) and Request:InvokeServer("GetState") or nil
    local items = (state and state.Items) or {}

    local potionToUse = "SuperLuck"
    if (items["SuperLuck"] or 0) > 0 then
        potionToUse = "SuperLuck"
    elseif (items["UltraLuck"] or 0) > 0 then
        potionToUse = "UltraLuck"
    end

    local ok, res = pcall(function()
        return Request:InvokeServer("UseLuck", potionToUse)
    end)

    if ok and res and res.Ok then
        notify("🧪 Luck Potion", "กดใช้ " .. potionToUse .. " สำเร็จ! (เพิ่มเรทการสุ่มแล้ว)", 4)
    else
        local errMsg = (res and res.Error) or "ไม่มีน้ำยาในตัว หรือน้ำยายังออกฤทธิ์อยู่"
        notify("🧪 Luck Potion", errMsg, 3)
    end
end

-- ==========================================
-- 4. ฟังก์ชัน AUTO SUMMON (ข้ามอนิเมชัน 100%)
-- ==========================================
local function setAutoSellSettings()
    pcall(function()
        if autoSellRare then Request:InvokeServer("SetAutoSell", "Rare", true) end
        if autoSellEpic then Request:InvokeServer("SetAutoSell", "Epic", true) end
    end)
end

local function stopAutoSummon()
    isAutoSummoning = false
    updateSummonUI(false)
    notify("Auto Summon", "หยุดการสุ่มแล้ว", 2)
end

local function startAutoSummonLoop()
    if isAutoSummoning then return end
    isAutoSummoning = true
    updateSummonUI(true)
    setAutoSellSettings()

    task.spawn(function()
        notify("Auto Summon", "เริ่มการสุ่มแบบข้ามอนิเมชัน...", 2)

        while isAutoSummoning do
            local ok, res = pcall(function()
                return Request:InvokeServer("Summon", 10)
            end)

            if ok and res then
                if res.Ok and res.Results then
                    local gotHighRarity = false
                    for _, unit in ipairs(res.Results) do
                        local name = unit.Unit or unit.Name or "Unknown"
                        local rarity = unit.Rarity or "Unknown"

                        if rarity == "Mythic" or rarity == "Secret" then
                            gotHighRarity = true
                            notify("🎉 ยินดีด้วย!", string.format("ได้ [%s] %s!", rarity, name), 5)
                            print(string.format("[AutoSummon] ได้รับระดับสูง: %s (%s)", name, rarity))
                        end
                    end

                    if gotHighRarity and stopOnMythicOrSecret then
                        notify("Auto Summon", "หยุดสุ่มเนื่องจากได้ตัวละครระดับสูง!", 4)
                        break
                    end
                else
                    local errMsg = (res and res.Error) or "เพชรหมดหรือช่องเก็บเต็ม"
                    notify("Auto Summon หยุดทำงาน", errMsg, 3)
                    break
                end
            else
                notify("Auto Summon", "การเชื่อมต่อขัดข้อง", 3)
                break
            end

            task.wait(0.5)
        end

        isAutoSummoning = false
        updateSummonUI(false)
    end)
end

-- ==========================================
-- 5. ระบบ MERCHANT (ร้านค้าเร้นลับ - Rare Goods)
-- ==========================================
local function fetchMerchantInfo()
    local ok, res = pcall(function()
        return Request:InvokeServer("MerchantInfo")
    end)
    if ok and res then
        cachedMerchantInfo = res
        return res
    end
    return cachedMerchantInfo
end

local function getLeftStock(offer, boughtTable)
    local limit = offer.Limit or 1
    local b = boughtTable and boughtTable[offer.Key]
    local boughtCount = 0
    if b == true then
        boughtCount = limit
    elseif type(b) == "number" then
        boughtCount = b
    end
    return math.max(limit - boughtCount, 0)
end

local function shouldAutoBuyMerchantItem(offer)
    local item = offer.Item or ""
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
    local ok, res = pcall(function()
        return Request:InvokeServer("MerchantBuy", key, amount or 1)
    end)
    if ok and res and res.Ok then
        return true
    end
    local reason = (res and (res.Reason or res.Error)) or "เงินไม่พอ หรือสินค้าหมด"
    return false, reason
end

local function runMerchantAutoBuy(isSilent)
    local info = fetchMerchantInfo()
    if not info or not info.Stock then
        if not isSilent then notify("🛒 Merchant", "ไม่สามารถดึงข้อมูลร้านค้าได้", 3) end
        return 0
    end

    local stateOk, state = pcall(function() return Request:InvokeServer("GetState") end)
    local gold = (stateOk and state and state.Gold) or 0
    local gems = (stateOk and state and (state.Gems or state.Gem)) or 0

    local boughtCount = 0
    local boughtList = {}

    for _, offer in ipairs(info.Stock) do
        local left = getLeftStock(offer, info.Bought)
        if left > 0 and shouldAutoBuyMerchantItem(offer) then
            local price = offer.Price or 0
            local cur = offer.Currency or "Gold"

            local canBuyQty = 0
            if cur == "Gold" and gold >= price then
                canBuyQty = math.min(left, math.floor(gold / price))
            elseif cur ~= "Gold" and gems >= price then
                canBuyQty = math.min(left, math.floor(gems / price))
            end

            if canBuyQty > 0 then
                local success = buySingleMerchantItem(offer.Key, canBuyQty)
                if success then
                    boughtCount = boughtCount + 1
                    local cost = price * canBuyQty
                    if cur == "Gold" then gold = gold - cost else gems = gems - cost end
                    table.insert(boughtList, string.format("%s (x%d)", offer.Item, (offer.Amount or 1) * canBuyQty))
                    print(string.format("[Merchant AutoBuy] ซื้อ %s x%d สำเร็จ (ใช้ %d %s)", offer.Item, canBuyQty, cost, cur))
                end
            end
        end
    end

    fetchMerchantInfo()

    if boughtCount > 0 then
        notify("🛒 Merchant ซื้อสำเร็จ!", "ซื้อ " .. table.concat(boughtList, ", "), 4)
    elseif not isSilent then
        notify("🛒 Merchant", "ไม่มีไอเทมที่เลือก หรือเงินไม่เพียงพอ", 3)
    end

    return boughtCount
end

-- ==========================================
-- 6. ระบบ CURRENCY SHOP (Gold Shop & Gem Shop)
-- ==========================================
local function getCurrencyShopLeft(offer, state)
    local shop = (state and state.Shop) or {}
    local currentHour = math.floor(getServerTime() / 3600)
    local bought = 0
    if shop.Hour == currentHour and shop.Bought then
        bought = shop.Bought[offer.Key] or 0
    end
    return math.max((offer.Stock or 1) - bought, 0)
end

local function buyCurrencyShopItem(offer, amount)
    local unit = nil
    if offer.Rarity and Config and Config.ShopUnit then
        pcall(function() unit = Config.ShopUnit(offer) end)
    end
    local ok, res = pcall(function()
        return Request:InvokeServer("ShopBuy", offer.Key, amount or 1, unit)
    end)
    if ok and res and res.Ok then
        return true
    end
    local reason = (res and (res.Reason or res.Error)) or "เงินไม่พอ หรือสินค้าหมด"
    return false, reason
end

local function runCurrencyShopAutoBuy(isSilent)
    local stateOk, state = pcall(function() return Request:InvokeServer("GetState") end)
    if not stateOk or not state then
        if not isSilent then notify("🪙 Currency Shop", "ไม่สามารถดึงข้อมูลสถานะได้", 3) end
        return 0
    end

    local gold = state.Gold or 0
    local gems = state.Gems or state.Gem or 0
    local activeColors = (Config and Config.ShopColorsNow and Config.ShopColorsNow()) or {}

    local boughtCount = 0
    local boughtList = {}

    local allOffers = {}
    for _, item in ipairs(currencyShopDB.Gold) do table.insert(allOffers, item) end
    for _, item in ipairs(currencyShopDB.Gems) do table.insert(allOffers, item) end

    for _, offer in ipairs(allOffers) do
        local isAvailable = true
        if offer.Rotates then
            isAvailable = (activeColors[offer.Item] == true)
        end

        if isAvailable then
            local left = getCurrencyShopLeft(offer, state)
            local shouldBuy = false

            if offer.Currency == "Gold" and currencyShopConfig.buyAllGold then
                shouldBuy = true
            elseif offer.Key == "g_scroll" and currencyShopConfig.buyScroll then
                shouldBuy = true
            elseif offer.Key == "g_trait" and currencyShopConfig.buyTrait then
                shouldBuy = true
            elseif offer.Key == "g_shard" and currencyShopConfig.buyStar then
                shouldBuy = true
            elseif offer.Rotates and currencyShopConfig.buyRotatingGems then
                shouldBuy = true
            elseif offer.Rarity and currencyShopConfig.buyShards then
                shouldBuy = true
            end

            if shouldBuy and left > 0 then
                local price = offer.Price or 0
                local cur = offer.Currency or "Gold"
                local canBuyQty = 0

                if cur == "Gold" and gold >= price then
                    canBuyQty = math.min(left, math.floor(gold / price))
                elseif cur ~= "Gold" and gems >= price then
                    canBuyQty = math.min(left, math.floor(gems / price))
                end

                if canBuyQty > 0 then
                    local success = buyCurrencyShopItem(offer, canBuyQty)
                    if success then
                        boughtCount = boughtCount + 1
                        local cost = price * canBuyQty
                        if cur == "Gold" then gold = gold - cost else gems = gems - cost end
                        table.insert(boughtList, string.format("%s (x%d)", offer.Name or offer.Item, canBuyQty))
                        print(string.format("[CurrencyShop AutoBuy] ซื้อ %s x%d สำเร็จ (ใช้ %d %s)", offer.Item, canBuyQty, cost, cur))
                    end
                end
            end
        end
    end

    if boughtCount > 0 then
        notify("🪙 Currency Shop ซื้อสำเร็จ!", "ซื้อ " .. table.concat(boughtList, ", "), 4)
    elseif not isSilent then
        notify("🪙 Currency Shop", "ไม่มีไอเทมที่เลือก หรือเงินไม่เพียงพอ", 3)
    end

    return boughtCount
end

local function setAutoShopLoop(enabled)
    isAutoShopLoop = enabled
    if loopShopBtn then
        if isAutoShopLoop then
            loopShopBtn.Text = "⏳ วนลูป Auto Buy ทุกร้าน: [ เปิด ]"
            loopShopBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        else
            loopShopBtn.Text = "⏳ วนลูป Auto Buy ทุกร้าน: [ ปิด ]"
            loopShopBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
        end
    end
end

-- เธรดสำหรับวนลูป Auto Buy ทุกร้านค้าเบื้องหลัง
task.spawn(function()
    while true do
        if isAutoShopLoop then
            runMerchantAutoBuy(true)
            runCurrencyShopAutoBuy(true)
        end
        for _ = 1, 30 do
            task.wait(1)
        end
    end
end)

-- สลับการเปิด/ปิดวนลูป Auto Buy ทั้งสองร้าน
local function toggleAllShopLoop()
    setAutoShopLoop(not isAutoShopLoop)
    queueSave()
    if isAutoShopLoop then
        notify("🛒 Auto Buy ร้านค้า", "เปิดระบบซื้ออัตโนมัติทั้ง Merchant และ Currency Shop!", 3)
    else
        notify("🛒 Auto Buy ร้านค้า", "ปิดระบบซื้ออัตโนมัติแล้ว", 2)
    end
end

-- ==========================================
-- 7. ระบบ AUTO PLAY & AUTO FARM ขั้นสูง
-- ==========================================

-- ส่งการตั้งค่า Battle Settings ไปยังเซิร์ฟเวอร์
local function applyServerBattleSettings()
    local cfg = _G.AnimeAshura_AutoFarm

    if cfg.AutoSkills then
        pcall(function() Request:InvokeServer("TeamAuto", true) end)
    end

    if cfg.AutoReplay then
        pcall(function()
            Request:InvokeServer("BattleSetting", "AutoReplay", true)
            Request:InvokeServer("BattleSetting", "AutoNext", false)
        end)
    elseif cfg.AutoNext then
        pcall(function()
            Request:InvokeServer("BattleSetting", "AutoNext", true)
            Request:InvokeServer("BattleSetting", "AutoReplay", false)
        end)
    end

    if cfg.LowGraphics then
        pcall(function()
            Request:InvokeServer("BattleSetting", "LowDetail", true)
            Request:InvokeServer("BattleSetting", "NoVfx", true)
            Request:InvokeServer("BattleSetting", "NoNumbers", true)
        end)
    end
end

-- ฟังก์ชันตรวจสอบว่าตัวละครอยู่ในห้องหรือยัง (ผ่าน UI ของเกม)
local function isInRoom()
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not pGui then return false end
    local playMenu = pGui:FindFirstChild("PlayMenu")
    if playMenu and playMenu.Enabled then return true end
    local readyRoom = pGui:FindFirstChild("ReadyRoom")
    if readyRoom and readyRoom.Enabled then return true end
    return false
end

-- ฟังก์ชันกดปุ่มบน GUI ของเกมโดยตรง (Native Click via firesignal)
local function clickGuiButton(guiName, targetText)
    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
    local gui = pGui and pGui:FindFirstChild(guiName)
    if not gui or not gui.Enabled then return false end

    targetText = string.lower(targetText)
    for _, desc in ipairs(gui:GetDescendants()) do
        if desc:IsA("TextButton") or desc:IsA("ImageButton") or desc:IsA("GuiButton") then
            local textMatch = false
            if desc:IsA("TextButton") and string.find(string.lower(desc.Text), targetText) then
                textMatch = true
            else
                local lbl = desc:FindFirstChildWhichIsA("TextLabel", true)
                if lbl and string.find(string.lower(lbl.Text), targetText) then
                    textMatch = true
                end
            end

            if textMatch and desc.Visible then
                pcall(function()
                    if firesignal then
                        firesignal(desc.Activated)
                    end
                end)
                return true
            end
        end
    end
    return false
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
        local areaMap = {
            Story = "Play",
            Raid = "Raid",
            Castle = "Castle",
            Challenge = "Challenge"
        }
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
        if z then return r, z end
    end

    return nil, nil
end

-- วาร์ปตัวละครและกระตุ้นการเหยียบ Zone อย่างสมบูรณ์
local function triggerZoneTouch(zone)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp and zone then
        -- ย้ายตำแหน่งตัวละครไปที่ Zone
        hrp.CFrame = zone.CFrame + Vector3.new(0, 0.5, 0)
        pcall(function() hrp.AssemblyLinearVelocity = Vector3.new(0, -5, 0) end)

        -- กระตุ้น TouchInterest ทันทีถ้า executor รองรับ
        pcall(function()
            if firetouchinterest then
                firetouchinterest(hrp, zone, 0)
                task.wait(0.05)
                firetouchinterest(hrp, zone, 1)
            end
        end)
        return true
    end
    return false
end

-- ✨ ดำเนินการเข้าห้องและเริ่ม Auto Play แบบสมบูรณ์ 100%
local isStartingRoom = false
local function enterAndStartAutoPlay()
    if isStartingRoom then return end
    isStartingRoom = true

    local cfg = _G.AnimeAshura_AutoFarm or {}
    local mode = cfg.Mode or "Story"
    local world = tonumber(cfg.World) or 1
    local stage = tonumber(cfg.Stage) or 1
    local difficulty = cfg.Difficulty or "Easy"
    local isSolo = (cfg.Solo ~= false)

    task.spawn(function()
        notify("⚔️ Auto Play", string.format("🎯 เตรียมลุยด่าน [%s W%d S%d (%s)]...", mode, world, stage, difficulty), 3)

        -- 1. ปรับค่า Battle Settings (AutoSkills, AutoReplay, LowDetail)
        applyServerBattleSettings()

        -- 2. ตรวจสอบว่าเข้าห้องอยู่แล้วหรือยัง
        if not isInRoom() then
            -- ออกจากห้องเก่าก่อน (ถ้ามีค้าง)
            pcall(function() Request:InvokeServer("LeaveRoom") end)
            pcall(function() Request:InvokeServer("CancelRoom") end)
            task.wait(0.3)

            -- ค้นหาห้องว่าง
            local room, zone = findPlayRoom(mode)
            if not zone then
                notify("⚔️ Auto Play", "❌ ไม่พบแท่นเข้าห้องสำหรับ " .. mode, 4)
                isStartingRoom = false
                return
            end

            -- วาร์ปเข้าสู่ Zone
            notify("⚔️ Auto Play", "📍 วาร์ปไปที่แท่นห้อง...", 2)
            triggerZoneTouch(zone)

            -- รอให้เซิร์ฟเวอร์ตอบรับการเข้าห้อง (PlayMenu หรือ ReadyRoom ปรากฏ)
            local waitTime = 0
            while not isInRoom() and waitTime < 4 do
                task.wait(0.3)
                waitTime = waitTime + 0.3
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp and zone then
                    hrp.CFrame = zone.CFrame + Vector3.new(math.random(-1, 1) * 0.1, 0.2, math.random(-1, 1) * 0.1)
                end
                triggerZoneTouch(zone)
            end

            if not isInRoom() then
                notify("⚔️ Auto Play", "⚠️ เข้าห้องล่าช้า กำลังลองส่งคำสั่งโดยตรง...", 2)
            end
        end

        local stagePayload = {
            Mode = mode,
            World = world,
            Stage = stage,
            Difficulty = difficulty,
            Tier = 1
        }

        -- 3. ส่งคำสั่งเลือกด่าน (RoomPick)
        notify("⚔️ Auto Play", "⚙️ กำลังเลือกด่าน...", 2)
        pcall(function() Request:InvokeServer("RoomPick", stagePayload) end)
        task.wait(0.25)

        -- 4. ล็อกเล่นคนเดียว (Solo)
        if isSolo then
            pcall(function() Request:InvokeServer("RoomOpen", false) end)
            task.wait(0.2)
        end

        -- 5. ส่งคำสั่งพร้อม (ReadyRoom) และกดปุ่ม Start บน PlayMenu
        notify("⚔️ Auto Play", "⏳ ส่งคำสั่งพร้อม (Ready)...", 2)
        local readyOk, readyRes = pcall(function()
            return Request:InvokeServer("ReadyRoom", stagePayload)
        end)

        -- จำลองการกดปุ่ม Start บน PlayMenu เผื่อเซิร์ฟเวอร์รอสัญญาณ UI
        clickGuiButton("PlayMenu", "Start")
        task.wait(0.5)

        if readyOk and readyRes and readyRes.Ok == false and readyRes.Error then
            notify("❌ ไม่สามารถพร้อมด่านนี้ได้", tostring(readyRes.Error), 5)
            isStartingRoom = false
            return
        end

        -- 6. รอให้ ReadyRoom GUI เปิด
        local rWait = 0
        while rWait < 2 do
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            local rr = pGui and pGui:FindFirstChild("ReadyRoom")
            if rr and rr.Enabled then break end
            task.wait(0.2)
            rWait = rWait + 0.2
        end

        -- 7. ส่งคำสั่งเริ่มด่าน (StartRoom)
        notify("⚔️ Auto Play", "🚀 เริ่มด่าน (StartRoom)...", 2)
        local startOk, startRes = pcall(function()
            return Request:InvokeServer("StartRoom")
        end)

        -- Fallback: ลองส่ง stagePayload ด้วย
        if not startOk or (startRes and startRes.Ok == false) then
            pcall(function()
                return Request:InvokeServer("StartRoom", stagePayload)
            end)
        end

        -- จำลองการกดปุ่ม Start บน ReadyRoom GUI ด้วย
        clickGuiButton("ReadyRoom", "Start")

        if startOk and startRes and startRes.Ok == false and startRes.Error then
            notify("❌ เริ่มเกมไม่สำเร็จ", tostring(startRes.Error), 4)
        else
            notify("⚔️ Auto Play", "✅ ส่งคำสั่งเริ่มเกมเรียบร้อย! กำลังเข้าสู่แมพ...", 4)
        end

        task.wait(3)
        isStartingRoom = false
    end)
end

local function leaveCurrentRoom()
    pcall(function()
        local res = Request:InvokeServer("LeaveRoom")
        if res and res.Exit and LocalPlayer.Character then
            LocalPlayer.Character:PivotTo(res.Exit)
        end
    end)
    pcall(function() Request:InvokeServer("CancelRoom") end)
    notify("⚔️ Auto Play", "ออกจากห้องเรียบร้อย", 2)
end

-- ==========================================
-- ✨ 7.5 ระบบ RESTOCK EXIT BATTLE (ออกด่านไปซื้อของแล้วกลับเล่นต่อ)
-- ==========================================
-- ฟังก์ชันคำนวณเวลาที่เหลือก่อน restock
local function getMerchantRestockRemaining()
    local info = cachedMerchantInfo or fetchMerchantInfo()
    if info and info.EndsAt then
        return info.EndsAt - getServerTime()
    end
    return 10800  -- default 3 ชั่วโมง
end

local function getCurrencyShopRestockRemaining()
    return 3600 - (getServerTime() % 3600)
end

-- ฟังก์ชันหลักของ Restock Exit: ตรวจจับการรีเซ็ตและสั่งกลับ Lobby ไปซื้อ
local function runRestockExitWatcher()
    task.spawn(function()
        -- ติดตาม "ชั่วโมง" ที่ซื้อล่าสุด เพื่อดูว่า restock ใหม่ยัง
        local lastCurrencyHour = math.floor(getServerTime() / 3600)
        local lastMerchantEndsAt = nil
        pcall(function()
            local info = fetchMerchantInfo()
            if info and info.EndsAt then
                lastMerchantEndsAt = info.EndsAt
            end
        end)

        while true do
            task.wait(5)

            -- ไม่เปิดระบบ Restock Exit
            if not restockExitBattle then continue end
            -- ไม่ได้เปิด Auto Shop Loop
            if not isAutoShopLoop then continue end
            -- ไม่ได้อยู่ใน Battle Place
            if game.PlaceId ~= 112575319532871 then
                -- อยู่ใน Lobby: ถ้ามี pending restock ให้ซื้อของแล้วเข้าด่านใหม่
                if _restockPending then
                    _restockPending = false
                    notify("🛒 Restock", "กลับมาที่ Lobby แล้ว! กำลังซื้อของ...", 3)
                    task.wait(2)
                    runMerchantAutoBuy(false)
                    task.wait(0.5)
                    runCurrencyShopAutoBuy(false)
                    task.wait(1)
                    -- กลับไปฟาร์มต่อ
                    if _G.AnimeAshura_AutoFarm and _G.AnimeAshura_AutoFarm.Enabled then
                        notify("⚔️ Auto Play", "ซื้อของเสร็จ! กำลังกลับเข้าด่านฟาร์มต่อ...", 3)
                        task.wait(1)
                        enterAndStartAutoPlay()
                    end
                end
                continue
            end

            -- อยู่ใน Battle Place: ตรวจจับ restock
            local now = getServerTime()
            local currentHour = math.floor(now / 3600)

            local currencyRestocked = (currentHour ~= lastCurrencyHour)
            local merchantRestocked = false

            if lastMerchantEndsAt and now >= lastMerchantEndsAt then
                merchantRestocked = true
            end

            if currencyRestocked or merchantRestocked then
                -- อัปเดตตัวจำ
                lastCurrencyHour = currentHour
                if merchantRestocked then
                    lastMerchantEndsAt = (lastMerchantEndsAt or 0) + 10800
                end

                _restockPending = true
                notify("🛒 Restock!", "ร้านค้ารีเซ็ตแล้ว! จะออกจากด่านเมื่อเล่นจบรอบนี้...", 5)

                -- ปิด AutoReplay / AutoNext เพื่อให้ด่านจบแล้วกลับ Lobby
                pcall(function()
                    Request:InvokeServer("BattleSetting", "AutoReplay", false)
                    Request:InvokeServer("BattleSetting", "AutoNext", false)
                end)

                -- รอจนกลับ Lobby (PlaceId เปลี่ยน)
                local waitCount = 0
                while game.PlaceId == 112575319532871 and waitCount < 300 do
                    task.wait(2)
                    waitCount = waitCount + 1

                    -- กดปุ่ม Return to Lobby / Leave ถ้าเห็น
                    pcall(function()
                        local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                        if pGui then
                            for _, g in ipairs(pGui:GetChildren()) do
                                if g:IsA("ScreenGui") and g.Enabled then
                                    for _, btn in ipairs(g:GetDescendants()) do
                                        if btn:IsA("TextButton") and btn.Visible then
                                            local txt = string.lower(btn.Text)
                                            if string.find(txt, "lobby") or string.find(txt, "return") or string.find(txt, "leave") or string.find(txt, "exit") then
                                                pcall(function() firesignal(btn.Activated) end)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end

                -- ถ้ารอนานเกินไป ลอง TeleportService กลับ Lobby
                if game.PlaceId == 112575319532871 then
                    pcall(function()
                        game:GetService("TeleportService"):Teleport(81532592154280, LocalPlayer)
                    end)
                end
            end
        end
    end)
end

-- ==========================================
-- 8. GUI เมนูควบคุม (Draggable)
-- ==========================================
local parentGui = (pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui")) or LocalPlayer:WaitForChild("PlayerGui")

if parentGui:FindFirstChild("AnimeAshuraHub") then
    parentGui.AnimeAshuraHub:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AnimeAshuraHub"
screenGui.ResetOnSpawn = false
screenGui.Parent = parentGui

-- ----------------- MAIN FRAME -----------------
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.fromOffset(260, 440)
mainFrame.Position = UDim2.new(0.5, -310, 0.20, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 18, 25)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(80, 75, 100)
stroke.Thickness = 1.5

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 38)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Anime Ashura Hub v2.0"
title.TextColor3 = Color3.fromRGB(255, 120, 200)
title.TextSize = 16

local function createButton(name, text, pos, color, callback, parent)
    local btn = Instance.new("TextButton", parent or mainFrame)
    btn.Name = name
    btn.Size = UDim2.new(1, -24, 0, 36)
    btn.Position = pos
    btn.BackgroundColor3 = color
    btn.Font = Enum.Font.GothamSemibold
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true

    local btnCorner = Instance.new("UICorner", btn)
    btnCorner.CornerRadius = UDim.new(0, 8)

    btn.Activated:Connect(callback)
    return btn
end

-- ----------------- SHOP SUB-FRAME (MERCHANT & CURRENCY SHOP) -----------------
shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Size = UDim2.fromOffset(380, 480)
shopFrame.Position = UDim2.new(0.5, -40, 0.18, 0)
shopFrame.BackgroundColor3 = Color3.fromRGB(22, 20, 30)
shopFrame.BorderSizePixel = 0
shopFrame.Active = true
shopFrame.Draggable = true
shopFrame.Visible = false
shopFrame.Parent = screenGui

local sCorner = Instance.new("UICorner", shopFrame)
sCorner.CornerRadius = UDim.new(0, 10)

local sStroke = Instance.new("UIStroke", shopFrame)
sStroke.Color = Color3.fromRGB(255, 170, 70)
sStroke.Thickness = 1.5

local sTitle = Instance.new("TextLabel", shopFrame)
sTitle.Size = UDim2.new(1, -50, 0, 30)
sTitle.Position = UDim2.fromOffset(12, 4)
sTitle.BackgroundTransparency = 1
sTitle.Font = Enum.Font.GothamBold
sTitle.Text = "🛒 ร้านค้าและตลาด (Shop System)"
sTitle.TextColor3 = Color3.fromRGB(255, 180, 80)
sTitle.TextSize = 15
sTitle.TextXAlignment = Enum.TextXAlignment.Left

local closeSBtn = Instance.new("TextButton", shopFrame)
closeSBtn.Name = "CloseShopBtn"
closeSBtn.Size = UDim2.fromOffset(26, 26)
closeSBtn.Position = UDim2.new(1, -34, 0, 8)
closeSBtn.BackgroundColor3 = Color3.fromRGB(45, 40, 50)
closeSBtn.Font = Enum.Font.GothamBold
closeSBtn.Text = "✕"
closeSBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeSBtn.TextSize = 13
local closeSCorner = Instance.new("UICorner", closeSBtn)
closeSCorner.CornerRadius = UDim.new(0, 6)
closeSBtn.Activated:Connect(function()
    shopFrame.Visible = false
end)

merchantTimerLabel = Instance.new("TextLabel", shopFrame)
merchantTimerLabel.Size = UDim2.new(1, -24, 0, 18)
merchantTimerLabel.Position = UDim2.fromOffset(12, 32)
merchantTimerLabel.BackgroundTransparency = 1
merchantTimerLabel.Font = Enum.Font.Gotham
merchantTimerLabel.Text = "⏳ Merchant รีเฟรชใน: --:--:--  |  Currency Shop ใน: --:--:--"
merchantTimerLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
merchantTimerLabel.TextSize = 11
merchantTimerLabel.TextXAlignment = Enum.TextXAlignment.Left

local currentShopTab = "Currency"

local merchantPage = Instance.new("Frame", shopFrame)
merchantPage.Name = "MerchantPage"
merchantPage.Size = UDim2.new(1, -20, 1, -95)
merchantPage.Position = UDim2.fromOffset(10, 88)
merchantPage.BackgroundTransparency = 1
merchantPage.Visible = false

local currencyPage = Instance.new("Frame", shopFrame)
currencyPage.Name = "CurrencyPage"
currencyPage.Size = UDim2.new(1, -20, 1, -95)
currencyPage.Position = UDim2.fromOffset(10, 88)
currencyPage.BackgroundTransparency = 1
currencyPage.Visible = true

local shopConfigPage = Instance.new("ScrollingFrame", shopFrame)
shopConfigPage.Name = "ShopConfigPage"
shopConfigPage.Size = UDim2.new(1, -20, 1, -95)
shopConfigPage.Position = UDim2.fromOffset(10, 88)
shopConfigPage.BackgroundTransparency = 1
shopConfigPage.BorderSizePixel = 0
shopConfigPage.ScrollBarThickness = 4
shopConfigPage.Visible = false

local tabBtn1 = Instance.new("TextButton", shopFrame)
tabBtn1.Size = UDim2.new(0.33, -6, 0, 30)
tabBtn1.Position = UDim2.fromOffset(10, 52)
tabBtn1.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
tabBtn1.Font = Enum.Font.GothamBold
tabBtn1.Text = "🛒 Merchant (Rare)"
tabBtn1.TextColor3 = Color3.fromRGB(220, 220, 220)
tabBtn1.TextSize = 11
local t1c = Instance.new("UICorner", tabBtn1)
t1c.CornerRadius = UDim.new(0, 6)

local tabBtn2 = Instance.new("TextButton", shopFrame)
tabBtn2.Size = UDim2.new(0.33, -6, 0, 30)
tabBtn2.Position = UDim2.new(0.33, 7, 0, 52)
tabBtn2.BackgroundColor3 = Color3.fromRGB(255, 170, 70)
tabBtn2.Font = Enum.Font.GothamBold
tabBtn2.Text = "🪙 Currency Shop"
tabBtn2.TextColor3 = Color3.fromRGB(25, 20, 30)
tabBtn2.TextSize = 11
local t2c = Instance.new("UICorner", tabBtn2)
t2c.CornerRadius = UDim.new(0, 6)

local tabBtn3 = Instance.new("TextButton", shopFrame)
tabBtn3.Size = UDim2.new(0.33, -6, 0, 30)
tabBtn3.Position = UDim2.new(0.66, 4, 0, 52)
tabBtn3.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
tabBtn3.Font = Enum.Font.GothamBold
tabBtn3.Text = "⚙️ ตั้งค่า Auto Buy"
tabBtn3.TextColor3 = Color3.fromRGB(220, 220, 220)
tabBtn3.TextSize = 11
local t3c = Instance.new("UICorner", tabBtn3)
t3c.CornerRadius = UDim.new(0, 6)

local function switchShopTab(tab)
    currentShopTab = tab
    merchantPage.Visible = (tab == "Merchant")
    currencyPage.Visible = (tab == "Currency")
    shopConfigPage.Visible = (tab == "Config")

    tabBtn1.BackgroundColor3 = (tab == "Merchant") and Color3.fromRGB(255, 170, 70) or Color3.fromRGB(45, 42, 55)
    tabBtn1.TextColor3 = (tab == "Merchant") and Color3.fromRGB(25, 20, 30) or Color3.fromRGB(220, 220, 220)

    tabBtn2.BackgroundColor3 = (tab == "Currency") and Color3.fromRGB(255, 170, 70) or Color3.fromRGB(45, 42, 55)
    tabBtn2.TextColor3 = (tab == "Currency") and Color3.fromRGB(25, 20, 30) or Color3.fromRGB(220, 220, 220)

    tabBtn3.BackgroundColor3 = (tab == "Config") and Color3.fromRGB(255, 170, 70) or Color3.fromRGB(45, 42, 55)
    tabBtn3.TextColor3 = (tab == "Config") and Color3.fromRGB(25, 20, 30) or Color3.fromRGB(220, 220, 220)
end

tabBtn1.Activated:Connect(function() switchShopTab("Merchant") end)
tabBtn2.Activated:Connect(function() switchShopTab("Currency") end)
tabBtn3.Activated:Connect(function() switchShopTab("Config") end)

-- 1. MERCHANT PAGE
local refreshMerchantBtn = Instance.new("TextButton", merchantPage)
refreshMerchantBtn.Size = UDim2.new(1, 0, 0, 26)
refreshMerchantBtn.Position = UDim2.fromOffset(0, 0)
refreshMerchantBtn.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
refreshMerchantBtn.Font = Enum.Font.GothamSemibold
refreshMerchantBtn.Text = "🔄 กดรีเฟรชเช็คของใน Merchant"
refreshMerchantBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshMerchantBtn.TextSize = 12
local rCorner = Instance.new("UICorner", refreshMerchantBtn)
rCorner.CornerRadius = UDim.new(0, 6)

stockContainer = Instance.new("ScrollingFrame", merchantPage)
stockContainer.Size = UDim2.new(1, 0, 1, -32)
stockContainer.Position = UDim2.fromOffset(0, 32)
stockContainer.BackgroundTransparency = 1
stockContainer.BorderSizePixel = 0
stockContainer.ScrollBarThickness = 4

local stockLayout = Instance.new("UIListLayout", stockContainer)
stockLayout.Padding = UDim.new(0, 6)
stockLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function renderMerchantCards()
    for _, child in ipairs(stockContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local info = cachedMerchantInfo or fetchMerchantInfo()
    if not info or not info.Stock then
        local emptyLbl = Instance.new("TextLabel", stockContainer)
        emptyLbl.Size = UDim2.new(1, 0, 0, 60)
        emptyLbl.BackgroundTransparency = 1
        emptyLbl.Text = "ไม่พบข้อมูลสต็อก กรุณากดปุ่มรีเฟรช"
        emptyLbl.TextColor3 = Color3.fromRGB(150, 150, 150)
        emptyLbl.Font = Enum.Font.Gotham
        emptyLbl.TextSize = 13
        return
    end

    local count = 0
    for _, offer in ipairs(info.Stock) do
        count = count + 1
        local left = getLeftStock(offer, info.Bought)
        local cur = offer.Currency or "Gold"
        local curIcon = (cur == "Gold") and "🟡 Gold" or "💎 Gems"
        local itemName = offer.Item or "Item"
        local totalQty = (offer.Amount or 1)
        local price = offer.Price or 0

        local card = Instance.new("Frame", stockContainer)
        card.Size = UDim2.new(1, -6, 0, 44)
        card.BackgroundColor3 = Color3.fromRGB(32, 29, 42)
        local cCorner = Instance.new("UICorner", card)
        cCorner.CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel", card)
        nameLbl.Size = UDim2.new(1, -85, 0, 22)
        nameLbl.Position = UDim2.fromOffset(8, 2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Text = string.format("%s (x%d)", itemName, totalQty)
        nameLbl.TextColor3 = offer.Rare and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(240, 240, 240)
        nameLbl.TextSize = 13
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        local infoLbl = Instance.new("TextLabel", card)
        infoLbl.Size = UDim2.new(1, -85, 0, 18)
        infoLbl.Position = UDim2.fromOffset(8, 22)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Font = Enum.Font.Gotham
        infoLbl.Text = string.format("ราคา: %s %s | เหลือ: %d ชิ้น", price, curIcon, left)
        infoLbl.TextColor3 = Color3.fromRGB(180, 180, 190)
        infoLbl.TextSize = 11
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left

        local buyNowBtn = Instance.new("TextButton", card)
        buyNowBtn.Size = UDim2.fromOffset(70, 30)
        buyNowBtn.Position = UDim2.new(1, -76, 0.5, -15)
        buyNowBtn.Font = Enum.Font.GothamBold
        buyNowBtn.TextSize = 11
        local bCorner = Instance.new("UICorner", buyNowBtn)
        bCorner.CornerRadius = UDim.new(0, 6)

        if left > 0 then
            buyNowBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            buyNowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            buyNowBtn.Text = "ซื้อทันที"
            buyNowBtn.Activated:Connect(function()
                local ok, err = buySingleMerchantItem(offer.Key, 1)
                if ok then
                    notify("🛒 ซื้อสำเร็จ", "ซื้อ " .. itemName .. " เรียบร้อย!", 2)
                    fetchMerchantInfo()
                    renderMerchantCards()
                else
                    notify("🛒 ไม่สำเร็จ", err or "ไม่สามารถซื้อได้", 3)
                end
            end)
        else
            buyNowBtn.BackgroundColor3 = Color3.fromRGB(55, 52, 65)
            buyNowBtn.TextColor3 = Color3.fromRGB(130, 130, 130)
            buyNowBtn.Text = "หมดแล้ว"
        end
    end

    stockContainer.CanvasSize = UDim2.new(0, 0, 0, count * 50)
end

refreshMerchantBtn.Activated:Connect(function()
    fetchMerchantInfo()
    renderMerchantCards()
    notify("🛒 Merchant", "อัปเดตข้อมูลร้านค้าเรียบร้อย!", 2)
end)

-- 2. CURRENCY SHOP PAGE
local refreshCurrencyBtn = Instance.new("TextButton", currencyPage)
refreshCurrencyBtn.Size = UDim2.new(1, 0, 0, 26)
refreshCurrencyBtn.Position = UDim2.fromOffset(0, 0)
refreshCurrencyBtn.BackgroundColor3 = Color3.fromRGB(52, 73, 94)
refreshCurrencyBtn.Font = Enum.Font.GothamSemibold
refreshCurrencyBtn.Text = "🔄 กดรีเฟรชเช็คของใน Currency Shop"
refreshCurrencyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshCurrencyBtn.TextSize = 12
local rcCorner = Instance.new("UICorner", refreshCurrencyBtn)
rcCorner.CornerRadius = UDim.new(0, 6)

currencyContainer = Instance.new("ScrollingFrame", currencyPage)
currencyContainer.Size = UDim2.new(1, 0, 1, -32)
currencyContainer.Position = UDim2.fromOffset(0, 32)
currencyContainer.BackgroundTransparency = 1
currencyContainer.BorderSizePixel = 0
currencyContainer.ScrollBarThickness = 4

local curLayout = Instance.new("UIListLayout", currencyContainer)
curLayout.Padding = UDim.new(0, 6)
curLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function renderCurrencyShopCards()
    for _, child in ipairs(currencyContainer:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
    end

    local stateOk, state = pcall(function() return Request:InvokeServer("GetState") end)
    state = (stateOk and state) or {}
    local activeColors = (Config and Config.ShopColorsNow and Config.ShopColorsNow()) or {}

    local totalCards = 0

    local function addSectionTitle(text, color)
        local sec = Instance.new("TextLabel", currencyContainer)
        sec.Size = UDim2.new(1, -6, 0, 24)
        sec.BackgroundTransparency = 1
        sec.Font = Enum.Font.GothamBold
        sec.Text = text
        sec.TextColor3 = color
        sec.TextSize = 13
        sec.TextXAlignment = Enum.TextXAlignment.Left
        totalCards = totalCards + 0.5
    end

    local function renderOfferItem(offer)
        totalCards = totalCards + 1
        local left = getCurrencyShopLeft(offer, state)
        local cur = offer.Currency or "Gold"
        local curIcon = (cur == "Gold") and "🟡 Gold" or "💎 Gems"
        local itemName = offer.Name or offer.Item

        local isAvailable = true
        local note = ""
        if offer.Rotates then
            isAvailable = (activeColors[offer.Item] == true)
            note = isAvailable and " [เปิดขายรอบนี้]" or " [รอบนี้ปิด]"
        end

        local card = Instance.new("Frame", currencyContainer)
        card.Size = UDim2.new(1, -6, 0, 44)
        card.BackgroundColor3 = isAvailable and Color3.fromRGB(32, 29, 42) or Color3.fromRGB(25, 23, 30)
        local cc = Instance.new("UICorner", card)
        cc.CornerRadius = UDim.new(0, 6)

        local nameLbl = Instance.new("TextLabel", card)
        nameLbl.Size = UDim2.new(1, -85, 0, 22)
        nameLbl.Position = UDim2.fromOffset(8, 2)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.Text = itemName .. note
        nameLbl.TextColor3 = isAvailable and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(120, 120, 130)
        nameLbl.TextSize = 12
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left

        local infoLbl = Instance.new("TextLabel", card)
        infoLbl.Size = UDim2.new(1, -85, 0, 18)
        infoLbl.Position = UDim2.fromOffset(8, 22)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Font = Enum.Font.Gotham
        infoLbl.Text = string.format("ราคา: %d %s | เหลือ: %d/%d", offer.Price, curIcon, left, offer.Stock or 1)
        infoLbl.TextColor3 = Color3.fromRGB(180, 180, 190)
        infoLbl.TextSize = 11
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left

        local buyBtn = Instance.new("TextButton", card)
        buyBtn.Size = UDim2.fromOffset(70, 30)
        buyBtn.Position = UDim2.new(1, -76, 0.5, -15)
        buyBtn.Font = Enum.Font.GothamBold
        buyBtn.TextSize = 11
        local bc = Instance.new("UICorner", buyBtn)
        bc.CornerRadius = UDim.new(0, 6)

        if isAvailable and left > 0 then
            buyBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
            buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            buyBtn.Text = "ซื้อทันที"
            buyBtn.Activated:Connect(function()
                local ok, err = buyCurrencyShopItem(offer, 1)
                if ok then
                    notify("🪙 ซื้อสำเร็จ", "ซื้อ " .. itemName .. " เรียบร้อย!", 2)
                    renderCurrencyShopCards()
                else
                    notify("🪙 ไม่สำเร็จ", err or "ไม่สามารถซื้อได้", 3)
                end
            end)
        else
            buyBtn.BackgroundColor3 = Color3.fromRGB(55, 52, 65)
            buyBtn.TextColor3 = Color3.fromRGB(130, 130, 130)
            buyBtn.Text = (not isAvailable) and "ปิดขาย" or "หมดแล้ว"
        end
    end

    addSectionTitle("🪙 Gold Shop (ใช้ Gold)", Color3.fromRGB(241, 196, 15))
    for _, offer in ipairs(currencyShopDB.Gold) do
        renderOfferItem(offer)
    end

    addSectionTitle("💎 Gem Shop (ใช้ Gems)", Color3.fromRGB(255, 120, 200))
    for _, offer in ipairs(currencyShopDB.Gems) do
        renderOfferItem(offer)
    end

    currencyContainer.CanvasSize = UDim2.new(0, 0, 0, totalCards * 52)
end

refreshCurrencyBtn.Activated:Connect(function()
    renderCurrencyShopCards()
    notify("🪙 Currency Shop", "อัปเดตข้อมูลร้านค้าเรียบร้อย!", 2)
end)

-- 3. CONFIG PAGE
local cfgLayout = Instance.new("UIListLayout", shopConfigPage)
cfgLayout.Padding = UDim.new(0, 6)
cfgLayout.SortOrder = Enum.SortOrder.LayoutOrder

local function createShopToggleRow(name, labelText, tbl, key)
    local row = Instance.new("TextButton", shopConfigPage)
    row.Name = name
    row.Size = UDim2.new(1, -6, 0, 32)
    row.BackgroundColor3 = tbl[key] and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(45, 42, 55)
    row.Font = Enum.Font.GothamSemibold
    row.Text = string.format("%s: [ %s ]", labelText, tbl[key] and "เปิด" or "ปิด")
    row.TextColor3 = Color3.fromRGB(255, 255, 255)
    row.TextSize = 12
    local rc = Instance.new("UICorner", row)
    rc.CornerRadius = UDim.new(0, 6)

    row.Activated:Connect(function()
        tbl[key] = not tbl[key]
        if tbl[key] then
            row.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
            row.Text = string.format("%s: [ เปิด ]", labelText)
        else
            row.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
            row.Text = string.format("%s: [ ปิด ]", labelText)
        end
        queueSave()  -- ✨ บันทึกเมื่อเปลี่ยนค่า
    end)
    return row
end

local function addConfigHeader(text, color)
    local hdr = Instance.new("TextLabel", shopConfigPage)
    hdr.Size = UDim2.new(1, -6, 0, 22)
    hdr.BackgroundTransparency = 1
    hdr.Font = Enum.Font.GothamBold
    hdr.Text = text
    hdr.TextColor3 = color
    hdr.TextSize = 13
    hdr.TextXAlignment = Enum.TextXAlignment.Left
end

addConfigHeader("🪙 ตั้งค่า Currency Shop (Gold & Gems):", Color3.fromRGB(241, 196, 15))
createShopToggleRow("TogGoldShop", "💰 ซื้อของ Gold Shop ทั้งหมด (Dango, Dust, Runes)", currencyShopConfig, "buyAllGold")
createShopToggleRow("TogScroll", "📜 ซื้อ Skill Scroll (สมุดสกิล 150 Gems)", currencyShopConfig, "buyScroll")
createShopToggleRow("TogTrait", "🔮 ซื้อ Trait Crystal (100 Gems)", currencyShopConfig, "buyTrait")
createShopToggleRow("TogStar", "⭐ ซื้อ Star Shard (300 Gems)", currencyShopConfig, "buyStar")
createShopToggleRow("TogGems", "💎 ซื้อหินธาตุหมุนเวียน (Green/Yellow/Red/Pink/Purple)", currencyShopConfig, "buyRotatingGems")
createShopToggleRow("TogShards", "👥 ซื้อเศษตัวละคร (Mythic / Legendary Shards)", currencyShopConfig, "buyShards")

addConfigHeader("🛒 ตั้งค่า Merchant Shop (Rare Goods):", Color3.fromRGB(255, 170, 70))
createShopToggleRow("TogMGold", "💰 ซื้อของที่ใช้ Gold ทั้งหมด (Merchant)", merchantConfig, "buyAllGold")
createShopToggleRow("TogMLuck", "⭐ ซื้อน้ำยา Luck (Super/Ultra)", merchantConfig, "buyLuck")
createShopToggleRow("TogMRainbow", "🌈 ซื้อ Rainbow Shard (Merchant)", merchantConfig, "buyRainbow")
createShopToggleRow("TogMTrait", "🔮 ซื้อ Trait Crystal (Merchant)", merchantConfig, "buyTrait")
createShopToggleRow("TogMStar", "⭐ ซื้อ Star Shard (Merchant)", merchantConfig, "buyStar")
createShopToggleRow("TogMEvo", "🧬 ซื้อไอเทม Evo ทั้งหมด", merchantConfig, "buyEvo")
createShopToggleRow("TogMChips", "⚡ ซื้อ Stat Chip (ปกติ/Super)", merchantConfig, "buyChips")

local buyCurNowBtn = Instance.new("TextButton", shopConfigPage)
buyCurNowBtn.Size = UDim2.new(1, -6, 0, 36)
buyCurNowBtn.BackgroundColor3 = Color3.fromRGB(241, 196, 15)
buyCurNowBtn.Font = Enum.Font.GothamBold
buyCurNowBtn.Text = "⚡ ซื้อของที่เลือกใน Currency Shop เดี๋ยวนี้"
buyCurNowBtn.TextColor3 = Color3.fromRGB(25, 20, 30)
buyCurNowBtn.TextSize = 12
local bcnCorner = Instance.new("UICorner", buyCurNowBtn)
bcnCorner.CornerRadius = UDim.new(0, 6)
buyCurNowBtn.Activated:Connect(function()
    runCurrencyShopAutoBuy(false)
    renderCurrencyShopCards()
end)

local buyMerchantNowBtn = Instance.new("TextButton", shopConfigPage)
buyMerchantNowBtn.Size = UDim2.new(1, -6, 0, 36)
buyMerchantNowBtn.BackgroundColor3 = Color3.fromRGB(230, 126, 34)
buyMerchantNowBtn.Font = Enum.Font.GothamBold
buyMerchantNowBtn.Text = "⚡ ซื้อของที่เลือกใน Merchant เดี๋ยวนี้"
buyMerchantNowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
buyMerchantNowBtn.TextSize = 12
local bmnCorner = Instance.new("UICorner", buyMerchantNowBtn)
bmnCorner.CornerRadius = UDim.new(0, 6)
buyMerchantNowBtn.Activated:Connect(function()
    runMerchantAutoBuy(false)
    renderMerchantCards()
end)

loopShopBtn = Instance.new("TextButton", shopConfigPage)
loopShopBtn.Size = UDim2.new(1, -6, 0, 36)
loopShopBtn.BackgroundColor3 = isAutoShopLoop and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(45, 42, 55)
loopShopBtn.Font = Enum.Font.GothamBold
loopShopBtn.Text = string.format("⏳ วนลูป Auto Buy ทุกร้าน: [ %s ]", isAutoShopLoop and "เปิด" or "ปิด")
loopShopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
loopShopBtn.TextSize = 12
local lsCorner = Instance.new("UICorner", loopShopBtn)
lsCorner.CornerRadius = UDim.new(0, 6)
loopShopBtn.Activated:Connect(function()
    toggleAllShopLoop()
end)

-- ✨ ปุ่ม Restock Exit Battle
local restockExitBtn = Instance.new("TextButton", shopConfigPage)
restockExitBtn.Size = UDim2.new(1, -6, 0, 36)
restockExitBtn.BackgroundColor3 = restockExitBattle and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(45, 42, 55)
restockExitBtn.Font = Enum.Font.GothamBold
restockExitBtn.Text = string.format("🔔 ร้านรีเซ็ต → จบด่านแล้วออกมาซื้อ: [ %s ]", restockExitBattle and "เปิด" or "ปิด")
restockExitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
restockExitBtn.TextSize = 11.5
local reCorner = Instance.new("UICorner", restockExitBtn)
reCorner.CornerRadius = UDim.new(0, 6)
restockExitBtn.Activated:Connect(function()
    restockExitBattle = not restockExitBattle
    if restockExitBattle then
        restockExitBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
        restockExitBtn.Text = "🔔 ร้านรีเซ็ต → จบด่านแล้วออกมาซื้อ: [ เปิด ]"
    else
        restockExitBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
        restockExitBtn.Text = "🔔 ร้านรีเซ็ต → จบด่านแล้วออกมาซื้อ: [ ปิด ]"
    end
    queueSave()
end)

shopConfigPage.CanvasSize = UDim2.new(0, 0, 0, 20 * 38)

task.spawn(function()
    while true do
        task.wait(1)
        if shopFrame and shopFrame.Visible then
            local info = cachedMerchantInfo or fetchMerchantInfo()
            local mRemain = (info and info.EndsAt) and (info.EndsAt - getServerTime()) or 0
            local cRemain = 3600 - (getServerTime() % 3600)

            if merchantTimerLabel then
                merchantTimerLabel.Text = string.format("⏳ Merchant ใน: %s  |  Currency Shop ใน: %s", formatClock(mRemain), formatClock(cRemain))
            end

            if mRemain <= 0 and mRemain > -2 then
                task.wait(1.5)
                fetchMerchantInfo()
                if currentShopTab == "Merchant" then renderMerchantCards() end
            end

            if cRemain <= 1 then
                task.wait(1.5)
                if currentShopTab == "Currency" then renderCurrencyShopCards() end
            end
        end
    end
end)

-- ----------------- ENHANCED AUTO PLAY / AUTO FARM SUB-FRAME -----------------
autoFarmFrame = Instance.new("Frame")
autoFarmFrame.Name = "AutoFarmFrame"
autoFarmFrame.Size = UDim2.fromOffset(380, 500)
autoFarmFrame.Position = UDim2.new(0.5, -40, 0.18, 0)
autoFarmFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 28)
autoFarmFrame.BorderSizePixel = 0
autoFarmFrame.Active = true
autoFarmFrame.Draggable = true
autoFarmFrame.Visible = false
autoFarmFrame.Parent = screenGui

local fCorner = Instance.new("UICorner", autoFarmFrame)
fCorner.CornerRadius = UDim.new(0, 10)

local fStroke = Instance.new("UIStroke", autoFarmFrame)
fStroke.Color = Color3.fromRGB(231, 76, 60)
fStroke.Thickness = 1.5

local fTitle = Instance.new("TextLabel", autoFarmFrame)
fTitle.Size = UDim2.new(1, -50, 0, 30)
fTitle.Position = UDim2.fromOffset(12, 4)
fTitle.BackgroundTransparency = 1
fTitle.Font = Enum.Font.GothamBold
fTitle.Text = "⚔️ ระบบ Auto Play & Auto Farm v2.0"
fTitle.TextColor3 = Color3.fromRGB(255, 105, 90)
fTitle.TextSize = 15
fTitle.TextXAlignment = Enum.TextXAlignment.Left

local closeFBtn = Instance.new("TextButton", autoFarmFrame)
closeFBtn.Name = "CloseFarmBtn"
closeFBtn.Size = UDim2.fromOffset(26, 26)
closeFBtn.Position = UDim2.new(1, -34, 0, 8)
closeFBtn.BackgroundColor3 = Color3.fromRGB(45, 40, 50)
closeFBtn.Font = Enum.Font.GothamBold
closeFBtn.Text = "✕"
closeFBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeFBtn.TextSize = 13
local closeFCorner = Instance.new("UICorner", closeFBtn)
closeFCorner.CornerRadius = UDim.new(0, 6)
closeFBtn.Activated:Connect(function()
    autoFarmFrame.Visible = false
end)

farmInfoLabel = Instance.new("TextLabel", autoFarmFrame)
farmInfoLabel.Size = UDim2.new(1, -24, 0, 20)
farmInfoLabel.Position = UDim2.fromOffset(12, 34)
farmInfoLabel.BackgroundTransparency = 1
farmInfoLabel.Font = Enum.Font.GothamSemibold
farmInfoLabel.Text = "🎯 กำลังเลือก: [Story] W1 Namekku - ด่าน 1"
farmInfoLabel.TextColor3 = Color3.fromRGB(240, 200, 120)
farmInfoLabel.TextSize = 11.5
farmInfoLabel.TextXAlignment = Enum.TextXAlignment.Left

-- ✨ แสดงสถานะ Save
local saveStatusLabel = Instance.new("TextLabel", autoFarmFrame)
saveStatusLabel.Size = UDim2.new(1, -24, 0, 14)
saveStatusLabel.Position = UDim2.fromOffset(12, 52)
saveStatusLabel.BackgroundTransparency = 1
saveStatusLabel.Font = Enum.Font.Gotham
saveStatusLabel.Text = savedData and "💾 โหลดการตั้งค่าที่บันทึกไว้เรียบร้อย" or "💾 ยังไม่มีการบันทึก (ตั้งค่าแล้วจะ auto-save)"
saveStatusLabel.TextColor3 = Color3.fromRGB(120, 220, 120)
saveStatusLabel.TextSize = 10
saveStatusLabel.TextXAlignment = Enum.TextXAlignment.Left

local farmScroll = Instance.new("ScrollingFrame", autoFarmFrame)
farmScroll.Size = UDim2.new(1, -20, 1, -78)
farmScroll.Position = UDim2.fromOffset(10, 70)
farmScroll.BackgroundTransparency = 1
farmScroll.BorderSizePixel = 0
farmScroll.ScrollBarThickness = 4
farmScroll.CanvasSize = UDim2.new(0, 0, 0, 700)

local fList = Instance.new("UIListLayout", farmScroll)
fList.Padding = UDim.new(0, 8)
fList.SortOrder = Enum.SortOrder.LayoutOrder

local function updateFarmInfoText()
    local cfg = _G.AnimeAshura_AutoFarm
    local mode = cfg.Mode or "Story"
    local world = cfg.World or 1
    local stage = cfg.Stage or 1
    local diff = cfg.Difficulty or "Easy"

    local modeData = stageDB[mode]
    local wData = modeData and modeData[world]
    local sData = wData and wData.Stages and wData.Stages[stage]

    local wName = wData and wData.Name or ("World " .. world)
    local sName = sData and sData.Name or ("ด่าน " .. stage)
    local bName = sData and sData.Boss or "บอส"

    farmInfoLabel.Text = string.format("🎯 [%s] %s • %s (บอส: %s) [%s]", mode, wName, sName, bName, diff)
end

-- 1. เลือกโหมด
local modeHeader = Instance.new("TextLabel", farmScroll)
modeHeader.Size = UDim2.new(1, 0, 0, 18)
modeHeader.BackgroundTransparency = 1
modeHeader.Font = Enum.Font.GothamBold
modeHeader.Text = "1. เลือกโหมดเกม (Game Mode):"
modeHeader.TextColor3 = Color3.fromRGB(220, 220, 230)
modeHeader.TextSize = 12.5
modeHeader.TextXAlignment = Enum.TextXAlignment.Left

local modeContainer = Instance.new("Frame", farmScroll)
modeContainer.Size = UDim2.new(1, -6, 0, 30)
modeContainer.BackgroundTransparency = 1

local modeBtns = {}
local modesList = {
    { Id = "Story", Name = "Story (เนื้อเรื่อง)" },
    { Id = "Raid", Name = "Raid (เรด)" },
    { Id = "Castle", Name = "Castle (หอคอย)" },
    { Id = "Challenge", Name = "Challenge" }
}

for i, m in ipairs(modesList) do
    local btn = Instance.new("TextButton", modeContainer)
    btn.Size = UDim2.new(0.25, -4, 1, 0)
    btn.Position = UDim2.new((i - 1) * 0.25, 2, 0, 0)
    btn.Font = Enum.Font.GothamBold
    btn.Text = m.Name
    btn.TextSize = 10
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = (_G.AnimeAshura_AutoFarm.Mode == m.Id) and Color3.fromRGB(231, 76, 60) or Color3.fromRGB(45, 42, 55)
    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(0, 6)

    btn.Activated:Connect(function()
        _G.AnimeAshura_AutoFarm.Mode = m.Id
        _G.AnimeAshura_AutoFarm.World = 1
        _G.AnimeAshura_AutoFarm.Stage = 1
        for _, b in pairs(modeBtns) do b.BackgroundColor3 = Color3.fromRGB(45, 42, 55) end
        btn.BackgroundColor3 = Color3.fromRGB(231, 76, 60)
        updateFarmInfoText()
        queueSave()  -- ✨ Auto-save
    end)
    modeBtns[m.Id] = btn
end

-- 2. เลือก World
local worldHeader = Instance.new("TextLabel", farmScroll)
worldHeader.Size = UDim2.new(1, 0, 0, 18)
worldHeader.BackgroundTransparency = 1
worldHeader.Font = Enum.Font.GothamBold
worldHeader.Text = "2. เลือก World (แมพ/โลก):"
worldHeader.TextColor3 = Color3.fromRGB(220, 220, 230)
worldHeader.TextSize = 12.5
worldHeader.TextXAlignment = Enum.TextXAlignment.Left

local worldContainer = Instance.new("Frame", farmScroll)
worldContainer.Size = UDim2.new(1, -6, 0, 30)
worldContainer.BackgroundTransparency = 1

local worldBtns = {}
local worldsList = {
    { Id = 1, Name = "1. Namekku" },
    { Id = 2, Name = "2. Hidden Village" },
    { Id = 3, Name = "3. Shibuya" },
    { Id = 4, Name = "4. Hueko Mundo" }
}

for i, w in ipairs(worldsList) do
    local btn = Instance.new("TextButton", worldContainer)
    btn.Size = UDim2.new(0.25, -4, 1, 0)
    btn.Position = UDim2.new((i - 1) * 0.25, 2, 0, 0)
    btn.Font = Enum.Font.GothamBold
    btn.Text = w.Name
    btn.TextSize = 9.5
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = (_G.AnimeAshura_AutoFarm.World == w.Id) and Color3.fromRGB(52, 152, 219) or Color3.fromRGB(45, 42, 55)
    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(0, 6)

    btn.Activated:Connect(function()
        _G.AnimeAshura_AutoFarm.World = w.Id
        _G.AnimeAshura_AutoFarm.Stage = 1
        for _, b in pairs(worldBtns) do b.BackgroundColor3 = Color3.fromRGB(45, 42, 55) end
        btn.BackgroundColor3 = Color3.fromRGB(52, 152, 219)
        updateFarmInfoText()
        queueSave()  -- ✨ Auto-save
    end)
    worldBtns[w.Id] = btn
end

-- 3. เลือก Stage
local stageHeader = Instance.new("TextLabel", farmScroll)
stageHeader.Size = UDim2.new(1, 0, 0, 18)
stageHeader.BackgroundTransparency = 1
stageHeader.Font = Enum.Font.GothamBold
stageHeader.Text = "3. เลือก Stage (ด่านที่ 1 - 6):"
stageHeader.TextColor3 = Color3.fromRGB(220, 220, 230)
stageHeader.TextSize = 12.5
stageHeader.TextXAlignment = Enum.TextXAlignment.Left

local stageContainer = Instance.new("Frame", farmScroll)
stageContainer.Size = UDim2.new(1, -6, 0, 30)
stageContainer.BackgroundTransparency = 1

local stageBtns = {}
for i = 1, 6 do
    local btn = Instance.new("TextButton", stageContainer)
    btn.Size = UDim2.new(0.166, -4, 1, 0)
    btn.Position = UDim2.new((i - 1) * 0.166, 2, 0, 0)
    btn.Font = Enum.Font.GothamBold
    btn.Text = "ด่าน " .. i
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = (_G.AnimeAshura_AutoFarm.Stage == i) and Color3.fromRGB(155, 89, 182) or Color3.fromRGB(45, 42, 55)
    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(0, 6)

    btn.Activated:Connect(function()
        _G.AnimeAshura_AutoFarm.Stage = i
        for _, b in pairs(stageBtns) do b.BackgroundColor3 = Color3.fromRGB(45, 42, 55) end
        btn.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
        updateFarmInfoText()
        queueSave()  -- ✨ Auto-save
    end)
    stageBtns[i] = btn
end

-- 4. เลือกระดับความยาก
local diffHeader = Instance.new("TextLabel", farmScroll)
diffHeader.Size = UDim2.new(1, 0, 0, 18)
diffHeader.BackgroundTransparency = 1
diffHeader.Font = Enum.Font.GothamBold
diffHeader.Text = "4. เลือกระดับความยาก (Difficulty):"
diffHeader.TextColor3 = Color3.fromRGB(220, 220, 230)
diffHeader.TextSize = 12.5
diffHeader.TextXAlignment = Enum.TextXAlignment.Left

local diffContainer = Instance.new("Frame", farmScroll)
diffContainer.Size = UDim2.new(1, -6, 0, 30)
diffContainer.BackgroundTransparency = 1

local diffBtns = {}
local diffsList = {
    { Id = "Easy", Name = "Easy (ง่าย)", Color = Color3.fromRGB(46, 204, 113) },
    { Id = "Medium", Name = "Medium (ปานกลาง)", Color = Color3.fromRGB(241, 196, 15) },
    { Id = "Hard", Name = "Hard (ยาก)", Color = Color3.fromRGB(231, 76, 60) }
}

for i, d in ipairs(diffsList) do
    local btn = Instance.new("TextButton", diffContainer)
    btn.Size = UDim2.new(0.333, -4, 1, 0)
    btn.Position = UDim2.new((i - 1) * 0.333, 2, 0, 0)
    btn.Font = Enum.Font.GothamBold
    btn.Text = d.Name
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.BackgroundColor3 = (_G.AnimeAshura_AutoFarm.Difficulty == d.Id) and d.Color or Color3.fromRGB(45, 42, 55)
    local bc = Instance.new("UICorner", btn)
    bc.CornerRadius = UDim.new(0, 6)

    btn.Activated:Connect(function()
        _G.AnimeAshura_AutoFarm.Difficulty = d.Id
        for _, b in pairs(diffBtns) do b.BackgroundColor3 = Color3.fromRGB(45, 42, 55) end
        btn.BackgroundColor3 = d.Color
        updateFarmInfoText()
        queueSave()  -- ✨ Auto-save
    end)
    diffBtns[d.Id] = btn
end

-- 5. การตั้งค่า Battle Automation
local optHeader = Instance.new("TextLabel", farmScroll)
optHeader.Size = UDim2.new(1, 0, 0, 18)
optHeader.BackgroundTransparency = 1
optHeader.Font = Enum.Font.GothamBold
optHeader.Text = "5. ตั้งค่าการต่อสู้และตัวช่วย (Battle Automation):"
optHeader.TextColor3 = Color3.fromRGB(241, 196, 15)
optHeader.TextSize = 12.5
optHeader.TextXAlignment = Enum.TextXAlignment.Left

-- ปุ่ม Auto Skills
autoSkillsBtn = Instance.new("TextButton", farmScroll)
autoSkillsBtn.Size = UDim2.new(1, -6, 0, 32)
autoSkillsBtn.BackgroundColor3 = _G.AnimeAshura_AutoFarm.AutoSkills and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(45, 42, 55)
autoSkillsBtn.Font = Enum.Font.GothamSemibold
autoSkillsBtn.Text = string.format("⚡ Auto Skills (บอทกดสกิลเอง 100%%): [ %s ]", _G.AnimeAshura_AutoFarm.AutoSkills and "เปิด" or "ปิด")
autoSkillsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoSkillsBtn.TextSize = 12
local askc = Instance.new("UICorner", autoSkillsBtn)
askc.CornerRadius = UDim.new(0, 6)
autoSkillsBtn.Activated:Connect(function()
    _G.AnimeAshura_AutoFarm.AutoSkills = not _G.AnimeAshura_AutoFarm.AutoSkills
    if _G.AnimeAshura_AutoFarm.AutoSkills then
        autoSkillsBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
        autoSkillsBtn.Text = "⚡ Auto Skills (บอทกดสกิลเอง 100%): [ เปิด ]"
        pcall(function() Request:InvokeServer("TeamAuto", true) end)
    else
        autoSkillsBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
        autoSkillsBtn.Text = "⚡ Auto Skills (บอทกดสกิลเอง 100%): [ ปิด ]"
        pcall(function() Request:InvokeServer("TeamAuto", false) end)
    end
    queueSave()
end)

-- ปุ่ม Auto Replay
autoReplayBtn = Instance.new("TextButton", farmScroll)
autoReplayBtn.Size = UDim2.new(1, -6, 0, 32)
autoReplayBtn.BackgroundColor3 = _G.AnimeAshura_AutoFarm.AutoReplay and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(45, 42, 55)
autoReplayBtn.Font = Enum.Font.GothamSemibold
autoReplayBtn.Text = string.format("🔄 Auto-Replay (เล่นด่านเดิมซ้ำ ไม่กลับล็อบบี้): [ %s ]", _G.AnimeAshura_AutoFarm.AutoReplay and "เปิด" or "ปิด")
autoReplayBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoReplayBtn.TextSize = 11.5
local arpc = Instance.new("UICorner", autoReplayBtn)
arpc.CornerRadius = UDim.new(0, 6)
autoReplayBtn.Activated:Connect(function()
    _G.AnimeAshura_AutoFarm.AutoReplay = not _G.AnimeAshura_AutoFarm.AutoReplay
    if _G.AnimeAshura_AutoFarm.AutoReplay then
        _G.AnimeAshura_AutoFarm.AutoNext = false
        if autoNextBtn then
            autoNextBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
            autoNextBtn.Text = "⏩ Auto-Next (ลุยด่านถัดไปอัตโนมัติเมื่อชนะ): [ ปิด ]"
        end
        autoReplayBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
        autoReplayBtn.Text = "🔄 Auto-Replay (เล่นด่านเดิมซ้ำ ไม่กลับล็อบบี้): [ เปิด ]"
        pcall(function()
            Request:InvokeServer("BattleSetting", "AutoReplay", true)
            Request:InvokeServer("BattleSetting", "AutoNext", false)
        end)
    else
        autoReplayBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
        autoReplayBtn.Text = "🔄 Auto-Replay (เล่นด่านเดิมซ้ำ ไม่กลับล็อบบี้): [ ปิด ]"
        pcall(function() Request:InvokeServer("BattleSetting", "AutoReplay", false) end)
    end
    queueSave()
end)

-- ปุ่ม Auto Next
autoNextBtn = Instance.new("TextButton", farmScroll)
autoNextBtn.Size = UDim2.new(1, -6, 0, 32)
autoNextBtn.BackgroundColor3 = _G.AnimeAshura_AutoFarm.AutoNext and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(45, 42, 55)
autoNextBtn.Font = Enum.Font.GothamSemibold
autoNextBtn.Text = string.format("⏩ Auto-Next (ลุยด่านถัดไปอัตโนมัติเมื่อชนะ): [ %s ]", _G.AnimeAshura_AutoFarm.AutoNext and "เปิด" or "ปิด")
autoNextBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
autoNextBtn.TextSize = 11.5
local anxc = Instance.new("UICorner", autoNextBtn)
anxc.CornerRadius = UDim.new(0, 6)
autoNextBtn.Activated:Connect(function()
    _G.AnimeAshura_AutoFarm.AutoNext = not _G.AnimeAshura_AutoFarm.AutoNext
    if _G.AnimeAshura_AutoFarm.AutoNext then
        _G.AnimeAshura_AutoFarm.AutoReplay = false
        if autoReplayBtn then
            autoReplayBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
            autoReplayBtn.Text = "🔄 Auto-Replay (เล่นด่านเดิมซ้ำ ไม่กลับล็อบบี้): [ ปิด ]"
        end
        autoNextBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
        autoNextBtn.Text = "⏩ Auto-Next (ลุยด่านถัดไปอัตโนมัติเมื่อชนะ): [ เปิด ]"
        pcall(function()
            Request:InvokeServer("BattleSetting", "AutoNext", true)
            Request:InvokeServer("BattleSetting", "AutoReplay", false)
        end)
    else
        autoNextBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
        autoNextBtn.Text = "⏩ Auto-Next (ลุยด่านถัดไปอัตโนมัติเมื่อชนะ): [ ปิด ]"
        pcall(function() Request:InvokeServer("BattleSetting", "AutoNext", false) end)
    end
    queueSave()
end)

-- ปุ่ม Low Graphics
lowGfxBtn = Instance.new("TextButton", farmScroll)
lowGfxBtn.Size = UDim2.new(1, -6, 0, 32)
lowGfxBtn.BackgroundColor3 = _G.AnimeAshura_AutoFarm.LowGraphics and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(45, 42, 55)
lowGfxBtn.Font = Enum.Font.GothamSemibold
lowGfxBtn.Text = string.format("💨 โหมดลดแล็ก (Low Detail & ปิดเอฟเฟกต์): [ %s ]", _G.AnimeAshura_AutoFarm.LowGraphics and "เปิด" or "ปิด")
lowGfxBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
lowGfxBtn.TextSize = 11.5
local lgc = Instance.new("UICorner", lowGfxBtn)
lgc.CornerRadius = UDim.new(0, 6)
lowGfxBtn.Activated:Connect(function()
    _G.AnimeAshura_AutoFarm.LowGraphics = not _G.AnimeAshura_AutoFarm.LowGraphics
    if _G.AnimeAshura_AutoFarm.LowGraphics then
        lowGfxBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
        lowGfxBtn.Text = "💨 โหมดลดแล็ก (Low Detail & ปิดเอฟเฟกต์): [ เปิด ]"
        pcall(function()
            Request:InvokeServer("BattleSetting", "LowDetail", true)
            Request:InvokeServer("BattleSetting", "NoVfx", true)
            Request:InvokeServer("BattleSetting", "NoNumbers", true)
        end)
    else
        lowGfxBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
        lowGfxBtn.Text = "💨 โหมดลดแล็ก (Low Detail & ปิดเอฟเฟกต์): [ ปิด ]"
        pcall(function()
            Request:InvokeServer("BattleSetting", "LowDetail", false)
            Request:InvokeServer("BattleSetting", "NoVfx", false)
            Request:InvokeServer("BattleSetting", "NoNumbers", false)
        end)
    end
    queueSave()
end)

-- ปุ่ม Solo Room
local soloToggleBtn = Instance.new("TextButton", farmScroll)
soloToggleBtn.Size = UDim2.new(1, -6, 0, 32)
soloToggleBtn.BackgroundColor3 = _G.AnimeAshura_AutoFarm.Solo and Color3.fromRGB(39, 174, 96) or Color3.fromRGB(45, 42, 55)
soloToggleBtn.Font = Enum.Font.GothamSemibold
soloToggleBtn.Text = string.format("🔒 ล็อกเล่นคนเดียว (Solo Mode - ปิดห้อง): [ %s ]", _G.AnimeAshura_AutoFarm.Solo and "เปิด" or "ปิด")
soloToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
soloToggleBtn.TextSize = 11.5
local sc = Instance.new("UICorner", soloToggleBtn)
sc.CornerRadius = UDim.new(0, 6)
soloToggleBtn.Activated:Connect(function()
    _G.AnimeAshura_AutoFarm.Solo = not _G.AnimeAshura_AutoFarm.Solo
    if _G.AnimeAshura_AutoFarm.Solo then
        soloToggleBtn.BackgroundColor3 = Color3.fromRGB(39, 174, 96)
        soloToggleBtn.Text = "🔒 ล็อกเล่นคนเดียว (Solo Mode - ปิดห้อง): [ เปิด ]"
    else
        soloToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
        soloToggleBtn.Text = "🔒 ล็อกเล่นคนเดียว (Solo Mode - ปิดห้อง): [ ปิด ]"
    end
    queueSave()
end)

-- ✨ ปุ่มวนลูป Auto Farm (ปรับปรุงให้มี Re-entry Loop จริง)
farmLoopBtn = Instance.new("TextButton", farmScroll)
farmLoopBtn.Size = UDim2.new(1, -6, 0, 34)
farmLoopBtn.BackgroundColor3 = _G.AnimeAshura_AutoFarm.Enabled and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(45, 42, 55)
farmLoopBtn.Font = Enum.Font.GothamBold
farmLoopBtn.Text = string.format("🔁 วนลูป Auto Farm (เข้าด่าน → เล่น → เข้าซ้ำ): [ %s ]", _G.AnimeAshura_AutoFarm.Enabled and "เปิด" or "ปิด")
farmLoopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
farmLoopBtn.TextSize = 11.5
local flc = Instance.new("UICorner", farmLoopBtn)
flc.CornerRadius = UDim.new(0, 6)
farmLoopBtn.Activated:Connect(function()
    _G.AnimeAshura_AutoFarm.Enabled = not _G.AnimeAshura_AutoFarm.Enabled
    if _G.AnimeAshura_AutoFarm.Enabled then
        farmLoopBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        farmLoopBtn.Text = "🔁 วนลูป Auto Farm (เข้าด่าน → เล่น → เข้าซ้ำ): [ เปิด ]"
        notify("⚔️ Auto Farm", "เปิดวนลูป Auto Farm! กำลังเข้าห้องและเริ่มด่าน...", 3)
        enterAndStartAutoPlay()
    else
        farmLoopBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
        farmLoopBtn.Text = "🔁 วนลูป Auto Farm (เข้าด่าน → เล่น → เข้าซ้ำ): [ ปิด ]"
        notify("⚔️ Auto Farm", "ปิดวนลูป Auto Farm เรียบร้อย", 2)
    end
    queueSave()
end)

-- ปุ่ม เริ่มทันที
local startNowBtn = Instance.new("TextButton", farmScroll)
startNowBtn.Size = UDim2.new(1, -6, 0, 40)
startNowBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
startNowBtn.Font = Enum.Font.GothamBold
startNowBtn.Text = "🚀 เริ่ม Auto Play เดี๋ยวนี้ (เข้าห้อง & ลุยด่านทันที)"
startNowBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
startNowBtn.TextSize = 13
local snc = Instance.new("UICorner", startNowBtn)
snc.CornerRadius = UDim.new(0, 8)
startNowBtn.Activated:Connect(function()
    enterAndStartAutoPlay()
end)

-- ปุ่ม ออกจากห้อง
local leaveBtn = Instance.new("TextButton", farmScroll)
leaveBtn.Size = UDim2.new(1, -6, 0, 32)
leaveBtn.BackgroundColor3 = Color3.fromRGB(60, 55, 70)
leaveBtn.Font = Enum.Font.GothamSemibold
leaveBtn.Text = "🚪 ออกจากห้องเดิม (Leave Current Room)"
leaveBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
leaveBtn.TextSize = 12
local lbc = Instance.new("UICorner", leaveBtn)
lbc.CornerRadius = UDim.new(0, 6)
leaveBtn.Activated:Connect(function()
    leaveCurrentRoom()
end)

updateFarmInfoText()

-- ==========================================
-- Background Tasks
-- ==========================================

-- ✨ Task 1: Lobby Auto Re-entry Loop (ตรวจจับตลอดเวลาว่าอยู่ Lobby + Farm เปิดอยู่)
task.spawn(function()
    -- รอตัวละครโหลดเสร็จ
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(3)

    -- ✨ ถ้ามี restock ค้าง → ซื้อของก่อนเข้าด่าน
    if _restockPending then
        _restockPending = false
        notify("🛒 Restock", "กลับมาที่ Lobby แล้ว! กำลังซื้อของ...", 3)
        task.wait(2)
        runMerchantAutoBuy(false)
        task.wait(0.5)
        runCurrencyShopAutoBuy(false)
        task.wait(1)
    end

    -- ✨ ถ้าบันทึกไว้ว่าเปิด Auto Farm อยู่ ให้เริ่มเข้าห้องทันที
    if _G.AnimeAshura_AutoFarm and _G.AnimeAshura_AutoFarm.Enabled then
        if game.PlaceId == 81532592154280 then
            print("[AutoFarm Loop] บันทึกไว้ว่าเปิดอยู่ → กำลังเข้าห้องอัตโนมัติ...")
            enterAndStartAutoPlay()
        end
    end

    -- ✨ Lobby Re-entry Loop: ตรวจจับทุก 5 วินาทีว่าอยู่ Lobby + Farm เปิด → เข้าด่านอัตโนมัติ
    while true do
        task.wait(5)
        if _G.AnimeAshura_AutoFarm and _G.AnimeAshura_AutoFarm.Enabled then
            -- ต้องอยู่ใน Lobby Place (ไม่ใช่ Battle Place)
            if game.PlaceId == 81532592154280 then
                -- ต้องไม่กำลังเข้าห้องอยู่แล้ว
                if not isStartingRoom then
                    print("[AutoFarm Loop] ตรวจพบอยู่ใน Lobby + Farm เปิดอยู่ → เข้าห้องอัตโนมัติ")
                    enterAndStartAutoPlay()
                end
            end
        end
    end
end)

-- Task 2: Battle Place auto-skills & button clicker
task.spawn(function()
    while true do
        task.wait(2)
        local placeId = game.PlaceId
        if placeId == 112575319532871 then
            if _G.AnimeAshura_AutoFarm and _G.AnimeAshura_AutoFarm.AutoSkills then
                pcall(function() Request:InvokeServer("TeamAuto", true) end)
            end

            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            if pGui then
                for _, g in ipairs(pGui:GetChildren()) do
                    if g:IsA("ScreenGui") and g.Enabled then
                        for _, btn in ipairs(g:GetDescendants()) do
                            if btn:IsA("TextButton") and btn.Visible then
                                local txt = string.lower(btn.Text)
                                if string.find(txt, "replay") or string.find(txt, "vote") or string.find(txt, "again") or string.find(txt, "next") then
                                    -- ✨ ถ้ามี restock pending → กดปุ่มกลับ lobby แทน
                                    if _restockPending then
                                        if string.find(txt, "lobby") or string.find(txt, "return") or string.find(txt, "leave") or string.find(txt, "exit") then
                                            pcall(function() firesignal(btn.Activated) end)
                                        end
                                    else
                                        pcall(function() firesignal(btn.Activated) end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ✨ Task 3: Restock Exit Watcher (ระบบเฝ้าดูเวลารีเซ็ตร้านค้า)
runRestockExitWatcher()

-- ----------------- MAIN FRAME BUTTONS -----------------

-- 1. ปุ่มรับเควสทันที
createButton("ClaimBtn", "🎁 รับเควส / รางวัลทั้งหมด", UDim2.fromOffset(12, 45), Color3.fromRGB(52, 152, 219), function()
    claimAllEverything()
end)

-- 2. ปุ่มวนลูป Auto Claim
loopClaimBtn = createButton("LoopClaimBtn", string.format("⏳ วนลูป Auto Claim: [ %s ]", isAutoClaimLoop and "เปิด" or "ปิด"), UDim2.fromOffset(12, 88), isAutoClaimLoop and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(45, 42, 55), function()
    setAutoClaimLoop(not isAutoClaimLoop)
    queueSave()
    if isAutoClaimLoop then
        notify("🎁 Auto Claim", "เปิดระบบวนลูปกดรับเควสอัตโนมัติ!", 2)
    else
        notify("🎁 Auto Claim", "ปิดระบบวนลูปกดรับเควสแล้ว", 2)
    end
end)

-- 3. ปุ่มใส่โค้ด
createButton("RedeemBtn", "🏷️ ใส่โค้ดทั้งหมด (Redeem All)", UDim2.fromOffset(12, 131), Color3.fromRGB(230, 126, 34), function()
    redeemAllCodes()
end)

-- 4. ปุ่มใช้น้ำยา Luck 1 ขวด
createButton("UseLuckBtn", "🧪 ใช้น้ำยา Luck (1 ขวด)", UDim2.fromOffset(12, 174), Color3.fromRGB(156, 39, 176), function()
    useOneLuckPotion()
end)

-- 5. ปุ่ม Auto Summon 10x (Skip)
summonBtn = createButton("SummonBtn", "🎰 Auto Summon 10x (Skip): [ ปิด ]", UDim2.fromOffset(12, 217), Color3.fromRGB(45, 42, 55), function()
    if isAutoSummoning then
        stopAutoSummon()
    else
        startAutoSummonLoop()
    end
end)

-- 6. ปุ่มสลับหยุดเมื่อได้ Mythic
stopToggleBtn = createButton("StopToggleBtn", string.format("🛑 หยุดเมื่อได้ Mythic: [ %s ]", stopOnMythicOrSecret and "เปิด" or "ปิด"), UDim2.fromOffset(12, 260), stopOnMythicOrSecret and Color3.fromRGB(155, 89, 182) or Color3.fromRGB(45, 42, 55), function()
    stopOnMythicOrSecret = not stopOnMythicOrSecret
    if stopOnMythicOrSecret then
        stopToggleBtn.Text = "🛑 หยุดเมื่อได้ Mythic: [ เปิด ]"
        stopToggleBtn.BackgroundColor3 = Color3.fromRGB(155, 89, 182)
    else
        stopToggleBtn.Text = "🛑 หยุดเมื่อได้ Mythic: [ ปิด ]"
        stopToggleBtn.BackgroundColor3 = Color3.fromRGB(45, 42, 55)
    end
    queueSave()
end)

-- 7. ปุ่มเปิดหน้าระบบร้านค้า
createButton("ShopBtn", "🛒 ระบบร้านค้า (Merchant / Currency)", UDim2.fromOffset(12, 303), Color3.fromRGB(255, 150, 50), function()
    shopFrame.Visible = not shopFrame.Visible
    if shopFrame.Visible then
        fetchMerchantInfo()
        renderMerchantCards()
        renderCurrencyShopCards()
    end
end)

-- 8. ปุ่มเปิดหน้าระบบ Auto Play & Auto Farm
createButton("AutoFarmBtn", "⚔️ ระบบ Auto Play (เข้าฟาม)", UDim2.fromOffset(12, 346), Color3.fromRGB(231, 76, 60), function()
    autoFarmFrame.Visible = not autoFarmFrame.Visible
    if autoFarmFrame.Visible then
        updateFarmInfoText()
    end
end)

-- 9. ปุ่มปิดเมนู
createButton("CloseBtn", "ปิดเมนู (X)", UDim2.fromOffset(12, 389), Color3.fromRGB(30, 26, 35), function()
    screenGui:Destroy()
end)

-- ✨ บันทึกค่าเริ่มต้นเฉพาะเมื่อยังไม่เคยมีไฟล์ save
if not savedData then
    persistCurrentSettings()
end

local loadMsg = savedData and "โหลดการตั้งค่าที่บันทึกไว้เรียบร้อย! 💾" or "พร้อมใช้งาน! ตั้งค่าแล้วจะ auto-save 💾"
notify("Anime Ashura Hub v2.0", loadMsg, 4)
