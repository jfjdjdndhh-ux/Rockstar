-- =========================================================================
-- ROCKSTAR CLIENT INITIALIZER (DIRECT GITHUB PATH)
-- =========================================================================

-- Глобальная таблица чита для синхронизации настроек между всеми файлами
shared.Rockstar = {
    Config = {
        AccentColor = Color3.fromRGB(170, 90, 255), -- Фиолетовый
        
        -- Состояния функций (вкл/выкл)
        ChinaHat = false,
        Trails = false,
        JumpCircle = false,
        Arrows = false,
        
        -- Настройки конкретно для Arrows (Стрелочки)
        ArrowsRadius = 120,          -- Расстояние от центра экрана
        ArrowsSize = 14,            -- Размер треугольников
        ArrowsShowPlayers = true,   -- Показывать обычных игроков
        ArrowsShowFriends = true,   -- Показывать друзей
    },
    -- Прямой путь к твоим raw-файлам на GitHub
    BaseUrl = "https://raw.githubusercontent.com/jfjdjdndhh-ux/Rockstar/main/rockstar/"
}

local Rockstar = shared.Rockstar

-- Функция безопасной подгрузки файлов с твоего гитхаба
local function loadRockstarFile(path)
    local fileUrl = Rockstar.BaseUrl .. path
    local success, content = pcall(game.HttpGet, game, fileUrl)
    
    if success and content then
        local func, err = loadstring(content)
        if func then
            task.spawn(func)
        else
            warn("[Rockstar Error] Сбой компиляции файла: " .. path .. " | " .. tostring(err))
        end
    else
        warn("[Rockstar Error] Не удалось скачать файл по пути: " .. fileUrl)
    end
end

-- Загружаем интерфейс (Главное меню и HUD элементы из папки gui)
loadRockstarFile("gui/gui.lua")
loadRockstarFile("gui/hud.lua")

print("[Rockstar] Успешно запущен из репозитория jfjdjdndhh-ux!")
