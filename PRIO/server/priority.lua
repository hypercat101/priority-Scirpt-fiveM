local priorities = {}
local playerCooldowns = {}

for zone, data in pairs(Config.Zones) do
    priorities[zone] = { 
        status = data.defaultStatus, 
        cooldown = data.defaultCooldown 
    }
end

function AddNewZone(zoneName, label)
    if not Config.Zones[zoneName] then
        Config.Zones[zoneName] = {
            label = label,
            defaultStatus = 'Available',
            defaultCooldown = 0
        }
        priorities[zoneName] = {
            status = 'Available',
            cooldown = 0
        }
        return true
    end
    return false
end

local function zoneExists(location)
    return priorities[location] ~= nil
end

--[[ 
    EXAMPLE: How to add a new zone status
    
    1. First add your new zone in config.lua:
    Config.Zones['prison'] = {
        label = 'Bolingbroke Prison',
        defaultStatus = 'Available',
        defaultCooldown = 0
    }

    2. The system will automatically initialize it with these statuses:
    priorities['prison'] = {
        status = 'Available',
        cooldown = 0
    }

    3. Status types available by default:
    - 'Available'     (Ready for priority)
    - 'In Progress'   (Active priority)
    - 'Cooldown'      (In cooldown period)

    4. To add custom status types, modify the updatePriorityStatus function calls:
    Example usage:
    updatePriorityStatus('prison', 'Lockdown', 30) -- Custom status with 30min cooldown
    updatePriorityStatus('prison', 'Available', 0)  -- Reset to available
]]

local webhookUrl = Config.Webhook.url 

local discordIDs = {
    ['license:1234567890abcdef'] = '123456789012345678' -- Outdated Not needed anymore
}

local function checkPlayerCooldown(source)
    local currentTime = os.time()
    if playerCooldowns[source] and currentTime - playerCooldowns[source] < Config.CommandCooldownTime then
        local remainingTime = Config.CommandCooldownTime - (currentTime - playerCooldowns[source])
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Command Cooldown',
            description = string.format(Config.Messages.cooldownActive, remainingTime),
            type = 'error'
        })
        return false
    end
    
    playerCooldowns[source] = currentTime
    return true
end

local function updatePriorityStatus(location, status, cooldown)
    if not zoneExists(location) then 
        print('^1[ERROR]^7 Attempted to update non-existent zone: ' .. location)
        return 
    end
    
    priorities[location].status = status
    priorities[location].cooldown = cooldown
    TriggerClientEvent('priority:updateStatus', -1, location, status, cooldown)
end

local function startCooldown(location)
    if not priorities[location] then return end

    priorities[location].status = 'Cooldown'
    priorities[location].cooldown = Config.PriorityCooldownTime
    
    TriggerClientEvent('priority:updateStatus', -1, location, 'Cooldown', Config.PriorityCooldownTime)
    
    CreateThread(function()
        local timer = Config.PriorityCooldownTime
        while timer > 0 do
            Wait(60000) -- 1 minute
            timer = timer - 1
            priorities[location].cooldown = timer
            
            TriggerClientEvent('priority:updateStatus', -1, location, 'Cooldown', timer)
            
            if timer <= 0 then
                priorities[location].status = Config.Zones[location].defaultStatus
                priorities[location].cooldown = Config.Zones[location].defaultCooldown
                TriggerClientEvent('priority:updateStatus', -1, location, Config.Zones[location].defaultStatus, Config.Zones[location].defaultCooldown)
            end
        end
    end)
end

local function sendToDiscord(player, action, location)
    if Config.Webhook.url == '' then 
        print('Webhook URL not set!')
        return 
    end
    
    local identifiers = GetPlayerIdentifiers(player)
    local discordPing = ''
    
    for _, identifier in pairs(identifiers) do
        if string.find(identifier, "discord:") then
            discordPing = string.format('<@%s>', string.gsub(identifier, "discord:", ""))
            break
        end
    end
    
    local message = {
        content = discordPing,
        embeds = {
            {
                title = '🚨 Priority System',
                description = string.format('**Player:** %s\n**Action:** %s\n**Location:** %s', 
                    GetPlayerName(player),
                    action, 
                    Config.Zones[location].label
                ),
                color = Config.Webhook.embedColor,
                footer = {
                    text = os.date('%Y-%m-%d %H:%M:%S')
                },
                fields = {
                    {
                        name = 'Location',
                        value = Config.Zones[location].label,
                        inline = true
                    },
                    {
                        name = 'Action',
                        value = action,
                        inline = true
                    }
                }
            }
        },
        username = Config.Webhook.botName,
        avatar_url = Config.Webhook.avatarUrl
    }
    
    PerformHttpRequest(Config.Webhook.url, function(err, text, headers)
        if err then
            print('Webhook Error:', err)
        end
    end, 'POST', json.encode(message), { ['Content-Type'] = 'application/json' })
end

RegisterNetEvent('priority:start')
AddEventHandler('priority:start', function(location)
    local source = source
    if not IsPlayerAceAllowed(source, Config.AcePermission) then return end
    
    if not zoneExists(location) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'ERROR',
            description = 'Invalid zone: ' .. location,
            type = 'error'
        })
        return
    end

    if priorities[location].status ~= 'Available' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'ERROR',
            description = Config.Messages.areaUnavailable,
            type = 'error'
        })
        return
    end
    
    updatePriorityStatus(location, 'In Progress', 0)
    sendToDiscord(source, "Started Priority", location)
end)

RegisterNetEvent('priority:remove')
AddEventHandler('priority:remove', function(location)
    local source = source
    if not IsPlayerAceAllowed(source, Config.AcePermission) then return end
    
    if not priorities[location] then return end
    
    if priorities[location].status == 'Available' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'ERROR',
            description = Config.Messages.noPriorityActive,
            type = 'error'
        })
        return
    end
    
    startCooldown(location)
    
    sendToDiscord(source, "Ended Priority", location)
end)

RegisterNetEvent('priority:checkPermission')
AddEventHandler('priority:checkPermission', function(action)
    local source = source
    if not IsPlayerAceAllowed(source, Config.AcePermission) then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'ERROR',
            description = Config.Messages.noPermission,
            type = 'error'
        })
        return
    end

    if not checkPlayerCooldown(source) then
        return
    end

    TriggerClientEvent('priority:showDialog', source, action)
end)

RegisterNetEvent('priority:forceCooldown')
AddEventHandler('priority:forceCooldown', function(location)
    local source = source
    if not IsPlayerAceAllowed(source, Config.AcePermission) then return end
    
    if not priorities[location] then return end
    
    startCooldown(location)
    
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Priority System',
        description = string.format(Config.Messages.forcedCooldown, location),
        type = 'inform'
    })
    
    sendToDiscord(source, "Forced Cooldown", location)
end)
