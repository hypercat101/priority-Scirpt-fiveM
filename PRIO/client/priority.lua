local priorities = {
    blaine = { status = 'Available', cooldown = 0 },
    ls = { status = 'Available', cooldown = 0 },
    fz = { status = 'Available', cooldown = 0 }
}

local function drawText(text)
    SetTextScale(0.40, 0.40)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    SetTextCentre(false)
    SetTextRightJustify(true)
    SetTextWrap(0.0, 0.885)
    AddTextComponentString(text)
    DrawText(0.885, 0.035)
end

CreateThread(function()
    while true do
        Wait(0)
        local blaineStatus = '~g~Available'
        local lsStatus = '~g~Available'
        local fzStatus = '~g~Available'

        -- Blaine County Status
        if priorities.blaine.status == 'In Progress' then
            blaineStatus = '~o~In Progress'
        elseif priorities.blaine.cooldown > 0 then
            blaineStatus = ('~r~Cooldown: %d MIN'):format(priorities.blaine.cooldown)
        end

        -- Los Santos Status
        if priorities.ls.status == 'In Progress' then
            lsStatus = '~o~In Progress'
        elseif priorities.ls.cooldown > 0 then
            lsStatus = ('~r~Cooldown: %d MIN'):format(priorities.ls.cooldown)
        end

        -- FZ Status
        if priorities.fz.status == 'In Progress' then
            fzStatus = '~o~In Progress'
        elseif priorities.fz.cooldown > 0 then
            fzStatus = ('~r~Cooldown: %d MIN'):format(priorities.fz.cooldown)
        end

        drawText(('~b~Blaine County: %s\n~b~Los Santos: %s\n~b~FZ: %s'):format(blaineStatus, lsStatus, fzStatus))
    end
end)

lib.registerContext({
    id = 'priority_menu',
    title = 'Priority Menu',
    options = {
        {
            title = 'Blaine County',
            description = 'Status: Available',
            metadata = {
                {label = 'Current Status', value = 'Available'}
            }
        },
        {
            title = 'Los Santos',
            description = 'Status: Available',
            metadata = {
                {label = 'Current Status', value = 'Available'}
            }
        },
        {
            title = 'FZ',
            description = 'Status: Available',
            metadata = {
                {label = 'Current Status', value = 'Available'}
            }
        }
    }
})

RegisterCommand('priority', function()
    TriggerServerEvent('priority:checkPermission', 'start')
end)

RegisterCommand('removepriority', function()
    TriggerServerEvent('priority:checkPermission', 'remove')
end)

RegisterCommand('prioritycd', function()
    TriggerServerEvent('priority:checkPermission', 'cooldown')
end)

RegisterNetEvent('priority:showDialog')
AddEventHandler('priority:showDialog', function(action)
    local input = lib.inputDialog('Priority System', {
        {
            type = 'select',
            label = 'Select Location',
            options = {
                { value = 'blaine', label = 'Blaine County' },
                { value = 'ls', label = 'Los Santos' },
                { value = 'fz', label = 'FZ' }
            }
        }
    })

    if not input then return end
    if action == 'start' then
        TriggerServerEvent('priority:start', input[1])
    elseif action == 'remove' then
        TriggerServerEvent('priority:remove', input[1])
    elseif action == 'cooldown' then
        TriggerServerEvent('priority:forceCooldown', input[1])
    end
end)

RegisterNetEvent('priority:updateStatus')
AddEventHandler('priority:updateStatus', function(location, status, cooldown)
    if priorities[location] then
        priorities[location].status = status
        priorities[location].cooldown = cooldown or 0
        
        lib.notify({
            title = 'Priority System',
            description = string.format('%s: %s', location, status),
            position = 'top-center',
            duration = 5000
        })
    end
end)

SetTimeout(1000, function()
    lib.notify({
        id = 'priority_style',
        position = 'top-center',
        duration = 5000,
        style = {
            backgroundColor = '#0d1117',  -- GitHub dark blue background
            color = '#ffffff',           -- White text
            ['.description'] = {
                color = '#e1e1e1'        -- Slightly dimmed description text
            }
        }
    })
end) 
