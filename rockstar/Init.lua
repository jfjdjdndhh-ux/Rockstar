-- Глобальная таблица чита
shared.Rockstar = {
    Config = {
        AccentColor = Color3.fromRGB(170, 90, 255),
        
        ChinaHatEnabled = false,
        JumpCircleEnabled = false,
        ArrowsEnabled = false,
        
        ArrowsRadius = 120,
        ArrowsSize = 14,
        ArrowsShowPlayers = true,
        ArrowsShowFriends = true,
        
        ChinaHatScale = Vector3.new(2, 1, 2),
        ColorShiftSpeed = 2
    },
    BaseUrl = "https://raw.githubusercontent.com/jfjdjdndhh-ux/Rockstar/main/rockstar/"
}

local Rockstar = shared.Rockstar

-- Функция подгрузки файлов с АНТИ-КЭШЕМ
local function loadRockstarFile(path)
    -- tick() добавляет текущее время в конец ссылки. 
    -- Это заставляет Роблокс скачивать новый файл каждый раз, а не брать старый из памяти.
    local fileUrl = Rockstar.BaseUrl .. path .. "?nocache=" .. tostring(tick())
    
    local success, content = pcall(game.HttpGet, game, fileUrl)
    
    if success and content then
        local func, err = loadstring(content)
        if func then
            task.spawn(func)
        else
            warn("[Rockstar] Ошибка компиляции " .. path .. ": " .. tostring(err))
        end
    else
        warn("[Rockstar] Ошибка скачивания: " .. fileUrl)
    end
end

-- Загружаем главное меню
loadRockstarFile("gui/gui.lua")
