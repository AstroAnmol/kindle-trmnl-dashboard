--[[--
    TRMNL Dashboard Screensaver Plugin for KOReader

    Fetches e-ink dashboard PNG from your home server and automatically
    sets it as KOReader's sleep screen wallpaper with periodic Active Sleep refresh.
--]]--

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local Device = require("device")
local NetworkMgr = require("ui/network/networkmgr")
local logger = require("logger")
local _ = require("gettext")

local TrmnlPlugin = WidgetContainer:extend{
    name = "trmnl",
    is_doc_only = false,
}

function TrmnlPlugin:init()
    self.server_url = G_reader_settings:readSetting("trmnl_server_url") or "http://10.0.0.219:5055/api/display/image"
    self.auto_update_on_sleep = G_reader_settings:isTrue("trmnl_auto_update_on_sleep", true)
    self.periodic_interval = G_reader_settings:readSetting("trmnl_periodic_interval") or 900 -- default 15 min

    -- Standard KOReader screensavers path on Kindle
    self.screensaver_dir = "/mnt/us/koreader/screensavers"
    self.screensaver_file = self.screensaver_dir .. "/dashboard.png"

    -- Ensure directory exists safely
    pcall(function()
        local lfs = require("libs/libkoreader-lfs")
        lfs.mkdir(self.screensaver_dir)
    end)
    pcall(function()
        os.execute("mkdir -p /mnt/us/koreader/screensavers 2>/dev/null")
    end)

    -- Configure KOReader screensaver
    self:configureKOReaderScreensaver()

    -- Start background periodic refresh timer if configured
    self:schedulePeriodicRefresh()

    -- Register into KOReader Main Menu
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
end

function TrmnlPlugin:configureKOReaderScreensaver()
    pcall(function()
        G_reader_settings:saveSetting("screensaver_type", "random_image")
        G_reader_settings:saveSetting("screensaver_dir", self.screensaver_dir)
        if G_reader_settings.flush then
            G_reader_settings:flush()
        end
    end)
end

function TrmnlPlugin:downloadDashboard(callback)
    local url = self.server_url
    logger.info("TRMNL: Starting download from: " .. tostring(url))

    -- Ensure Wi-Fi is connected via NetworkMgr
    NetworkMgr:runWhenOnline(function()
        local ok, result = pcall(function()
            local socket = require("socket")
            local http = require("socket.http")
            local ltn12 = require("ltn12")

            local sink = {}
            local req = {
                url = url,
                sink = ltn12.sink.table(sink),
                headers = {
                    ["User-Agent"] = "KOReader-TRMNL/1.0",
                    ["Accept"] = "image/png,image/*",
                },
                create = function()
                    local tcp = socket.tcp()
                    if tcp then
                        tcp:settimeout(15)
                    end
                    return tcp
                end,
            }

            -- Request with error safety
            local _, code, headers, status = http.request(req)
            logger.info("TRMNL: HTTP response code: " .. tostring(code))

            if code == 200 and #sink > 0 then
                local image_bytes = table.concat(sink)
                if #image_bytes > 500 then
                    local f, err = io.open(self.screensaver_file, "wb")
                    if f then
                        f:write(image_bytes)
                        f:close()
                        logger.info("TRMNL: Successfully saved dashboard (" .. #image_bytes .. " bytes)")
                        return true
                    else
                        logger.warn("TRMNL: Failed to write to file: " .. tostring(err))
                        return false, "Write error: " .. tostring(err)
                    end
                else
                    return false, "Image response too small"
                end
            else
                return false, "HTTP " .. tostring(code or status or "timeout")
            end
        end)

        local success = false
        local err_msg = "Unknown error"
        if ok and result == true then
            success = true
        elseif not ok then
            err_msg = tostring(result)
        elseif type(result) == "string" then
            err_msg = result
        else
            err_msg = tostring(result)
        end

        if callback then
            callback(success, err_msg)
        end
    end)
end

function TrmnlPlugin:updateNow(show_feedback)
    if show_feedback then
        UIManager:show(InfoMessage:new{
            text = _("Connecting to Wi-Fi and downloading dashboard..."),
            timeout = 3,
        })
    end

    UIManager:scheduleIn(0.1, function()
        self:downloadDashboard(function(success, err_msg)
            if success then
                self:configureKOReaderScreensaver()
                if show_feedback then
                    UIManager:show(InfoMessage:new{
                        text = _("Dashboard updated successfully!\nWill show as screensaver when sleeping."),
                        timeout = 4,
                    })
                end
            else
                if show_feedback then
                    UIManager:show(InfoMessage:new{
                        text = _("Failed to download dashboard:\n") .. tostring(err_msg) .. _("\nCheck Wi-Fi and URL: ") .. tostring(self.server_url),
                        timeout = 6,
                    })
                end
            end
        end)
    end)
end

function TrmnlPlugin:schedulePeriodicRefresh()
    if self.periodic_task then
        UIManager:unschedule(self.periodic_task)
        self.periodic_task = nil
    end

    if not self.periodic_interval or self.periodic_interval <= 0 then
        return
    end

    self.periodic_task = function()
        pcall(function()
            self:downloadDashboard(function(ok)
                if ok then
                    self:configureKOReaderScreensaver()
                    if Device.screen_saver_mode then
                        pcall(function()
                            local Screensaver = require("ui/screensaver")
                            Screensaver:show()
                        end)
                    end
                end
            end)
        end)
        -- Re-schedule next execution
        if self.periodic_interval > 0 then
            UIManager:scheduleIn(self.periodic_interval, self.periodic_task)
        end
    end

    UIManager:scheduleIn(self.periodic_interval, self.periodic_task)
end

-- Hook into KOReader power suspend event
function TrmnlPlugin:onSuspend()
    if self.auto_update_on_sleep then
        pcall(function()
            self:downloadDashboard(function(ok)
                if ok then
                    self:configureKOReaderScreensaver()
                end
            end)
        end)
    end

    -- Schedule Active Sleep RTC wakeup if supported on Kindle
    if self.periodic_interval and self.periodic_interval > 0 and Device.wakeup_mgr then
        pcall(function()
            Device.wakeup_mgr:addTask(self.periodic_interval, function()
                logger.info("TRMNL: Active Sleep RTC wakeup triggered")
                self:downloadDashboard(function(ok)
                    if ok then
                        self:configureKOReaderScreensaver()
                        if Device.screen_saver_mode then
                            pcall(function()
                                require("ui/screensaver"):show()
                            end)
                        end
                    end
                end)
            end)
        end)
    end
end

function TrmnlPlugin:addToMainMenu(menu_items)
    menu_items.trmnl_dashboard = {
        text = _("TRMNL Dashboard"),
        sorting_hint = "more_tools",
        sub_item_table = {
            {
                text = _("Update Dashboard Now"),
                callback = function()
                    self:updateNow(true)
                end,
            },
            {
                text = _("Periodic Refresh (Active Sleep)"),
                sub_item_table = {
                    {
                        text = _("Off"),
                        checked_func = function() return self.periodic_interval == 0 end,
                        callback = function()
                            self.periodic_interval = 0
                            G_reader_settings:saveSetting("trmnl_periodic_interval", 0)
                            self:schedulePeriodicRefresh()
                        end,
                    },
                    {
                        text = _("Every 10 minutes"),
                        checked_func = function() return self.periodic_interval == 600 end,
                        callback = function()
                            self.periodic_interval = 600
                            G_reader_settings:saveSetting("trmnl_periodic_interval", 600)
                            self:schedulePeriodicRefresh()
                        end,
                    },
                    {
                        text = _("Every 15 minutes (Default)"),
                        checked_func = function() return self.periodic_interval == 900 end,
                        callback = function()
                            self.periodic_interval = 900
                            G_reader_settings:saveSetting("trmnl_periodic_interval", 900)
                            self:schedulePeriodicRefresh()
                        end,
                    },
                    {
                        text = _("Every 30 minutes"),
                        checked_func = function() return self.periodic_interval == 1800 end,
                        callback = function()
                            self.periodic_interval = 1800
                            G_reader_settings:saveSetting("trmnl_periodic_interval", 1800)
                            self:schedulePeriodicRefresh()
                        end,
                    },
                    {
                        text = _("Every 1 hour"),
                        checked_func = function() return self.periodic_interval == 3600 end,
                        callback = function()
                            self.periodic_interval = 3600
                            G_reader_settings:saveSetting("trmnl_periodic_interval", 3600)
                            self:schedulePeriodicRefresh()
                        end,
                    },
                },
            },
            {
                text = _("Auto-update on Sleep"),
                checked_func = function()
                    return self.auto_update_on_sleep
                end,
                callback = function()
                    self.auto_update_on_sleep = not self.auto_update_on_sleep
                    G_reader_settings:saveSetting("trmnl_auto_update_on_sleep", self.auto_update_on_sleep)
                end,
            },
            {
                text = _("Change Server URL"),
                help_text = self.server_url,
                callback = function()
                    local dialog
                    dialog = InputDialog:new{
                        title = _("TRMNL Server URL"),
                        input = self.server_url,
                        buttons = {
                            {
                                {
                                    text = _("Cancel"),
                                    callback = function()
                                        UIManager:close(dialog)
                                    end,
                                },
                                {
                                    text = _("Save"),
                                    is_action = true,
                                    callback = function()
                                        local new_url = dialog:getInputText()
                                        if new_url and new_url ~= "" then
                                            self.server_url = new_url
                                            G_reader_settings:saveSetting("trmnl_server_url", new_url)
                                        end
                                        UIManager:close(dialog)
                                    end,
                                },
                            },
                        },
                    }
                    UIManager:show(dialog)
                    dialog:onShowKeyboard()
                end,
            },
        },
    }
end

return TrmnlPlugin
