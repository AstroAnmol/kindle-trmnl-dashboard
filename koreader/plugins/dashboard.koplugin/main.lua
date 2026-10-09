--[[--
    Kindle Dashboard Screensaver Plugin for KOReader
    Tailored for Kindle WP63GW (7th Gen Basic, firmware 5.12.2.2)

    Fetches e-ink dashboard PNG (600x800) from home server and automatically
    sets it as KOReader's sleep screen wallpaper with periodic Active Sleep refresh.
--]]--

local WidgetContainer = require("ui/widget/container/widgetcontainer")

-- Safe requires
local UIManager
pcall(function() UIManager = require("ui/uimanager") end)

local InfoMessage
pcall(function() InfoMessage = require("ui/widget/infomessage") end)

local InputDialog
pcall(function() InputDialog = require("ui/widget/inputdialog") end)

local Device
pcall(function() Device = require("device") end)

local NetworkMgr
pcall(function() NetworkMgr = require("ui/networkmgr") end)
if not NetworkMgr then
    pcall(function() NetworkMgr = require("networkmgr") end)
end

local logger
pcall(function() logger = require("logger") end)

local _ = function(str) return str end
pcall(function()
    local gettext = require("gettext")
    if gettext then _ = gettext end
end)

local function log_info(msg)
    if logger and logger.info then
        logger.info("DASHBOARD: " .. tostring(msg))
    end
end

local function log_warn(msg)
    if logger and logger.warn then
        logger.warn("DASHBOARD: " .. tostring(msg))
    end
end

local function show_notification(text, timeout)
    if UIManager and InfoMessage then
        pcall(function()
            UIManager:show(InfoMessage:new{
                text = text,
                timeout = timeout or 4,
            })
        end)
    end
end

local DashboardPlugin = WidgetContainer:extend{
    name = "dashboard",
    is_doc_only = false,
}

function DashboardPlugin:init()
    -- Read persistent settings
    self.server_url = "http://10.0.0.219:5055/api/display/image"
    pcall(function()
        if G_reader_settings then
            self.server_url = G_reader_settings:readSetting("dashboard_server_url")
                or G_reader_settings:readSetting("trmnl_server_url")
                or "http://10.0.0.219:5055/api/display/image"
            self.auto_update_on_sleep = G_reader_settings:isTrue("dashboard_auto_update_on_sleep", true)
            self.periodic_interval = G_reader_settings:readSetting("dashboard_periodic_interval") or 900
        end
    end)

    if self.auto_update_on_sleep == nil then self.auto_update_on_sleep = true end
    if not self.periodic_interval then self.periodic_interval = 900 end

    -- Screensaver locations
    self.screensaver_dir = "/mnt/us/koreader/screensavers/dashboard"
    self.screensaver_file = self.screensaver_dir .. "/dashboard.png"
    self.screensaver_root_file = "/mnt/us/koreader/screensavers/dashboard.png"

    -- Ensure directories exist safely
    pcall(function()
        local ok_lfs, lfs = pcall(require, "lfs")
        if ok_lfs and lfs then
            lfs.mkdir("/mnt/us/koreader/screensavers")
            lfs.mkdir(self.screensaver_dir)
        end
    end)
    pcall(function()
        os.execute("mkdir -p /mnt/us/koreader/screensavers/dashboard 2>/dev/null")
    end)

    -- Configure KOReader screensaver
    self:configureKOReaderScreensaver()

    -- Schedule background periodic refresh (KOReader + hardware daemon)
    self:schedulePeriodicRefresh()
    self:syncScheduler()

    -- Register into KOReader Main Menu system
    if self.ui and self.ui.menu and self.ui.menu.registerToMainMenu then
        pcall(function() self.ui.menu:registerToMainMenu(self) end)
    end
end

function DashboardPlugin:syncScheduler()
    pcall(function()
        local conf_dir = "/mnt/us/koreader/settings"
        local conf_file = conf_dir .. "/dashboard_config.env"
        local script_path = "/mnt/us/koreader/plugins/dashboard.koplugin/scheduler.sh"

        os.execute("mkdir -p " .. conf_dir .. " 2>/dev/null")

        local f = io.open(conf_file, "w")
        if f then
            f:write(string.format('INTERVAL=%d\nURL="%s"\n', self.periodic_interval or 900, self.server_url or "http://10.0.0.219:5055/api/display/image"))
            f:close()
        end

        os.execute("chmod +x " .. script_path .. " 2>/dev/null")

        if self.periodic_interval and self.periodic_interval > 0 then
            log_info("Starting hardware background scheduler with interval: " .. tostring(self.periodic_interval))
            os.execute("sh " .. script_path .. " restart >/dev/null 2>&1 &")
        else
            log_info("Stopping hardware background scheduler")
            os.execute("sh " .. script_path .. " stop >/dev/null 2>&1")
        end
    end)
end

function DashboardPlugin:onMenuPrepare(menu)
    if menu and menu.registerToMainMenu then
        pcall(function() menu:registerToMainMenu(self) end)
    end
end

function DashboardPlugin:configureKOReaderScreensaver()
    pcall(function()
        if G_reader_settings then
            G_reader_settings:saveSetting("screensaver_type", "random_image")
            G_reader_settings:saveSetting("screensaver_dir", self.screensaver_dir)
            if G_reader_settings.flush then
                G_reader_settings:flush()
            end
        end
    end)
end

function DashboardPlugin:getBatteryTelemetry()
    local battery_level = nil
    local is_charging = 0

    pcall(function()
        if Device and Device.power then
            if Device.power.getCapacity then
                battery_level = Device.power:getCapacity()
            end
            if Device.power.isCharging and Device.power:isCharging() then
                is_charging = 1
            end
        elseif Device and Device.battery then
            if Device.battery.getCapacity then
                battery_level = Device.battery:getCapacity()
            end
        end
    end)

    -- Fallback to Linux / Kindle sysfs
    if not battery_level then
        pcall(function()
            local paths = {
                "/sys/class/power_supply/battery/capacity",
                "/sys/devices/system/yoshi_battery/battery_capacity",
                "/sys/devices/platform/pmic_battery.1/power_supply/pmic_battery/capacity",
            }
            for _, path in ipairs(paths) do
                local f = io.open(path, "r")
                if f then
                    local val = f:read("*all")
                    f:close()
                    if val then
                        battery_level = tonumber(val:match("(%d+)"))
                        if battery_level then break end
                    end
                end
            end
        end)
    end

    if is_charging == 0 then
        pcall(function()
            local f = io.open("/sys/class/power_supply/battery/status", "r")
            if f then
                local st = f:read("*all")
                f:close()
                if st and st:find("Charging") then
                    is_charging = 1
                end
            end
        end)
    end

    return battery_level, is_charging
end

function DashboardPlugin:refreshScreen()
    -- Direct hardware paint on Kindle using eips
    pcall(function()
        local is_kindle = (Device and Device.isKindle and Device:isKindle()) or os.execute("test -x /usr/sbin/eips") == 0
        if is_kindle and self.screensaver_file then
            os.execute("/usr/sbin/eips -f -g " .. self.screensaver_file .. " 2>/dev/null")
        end
    end)

    -- KOReader screensaver redraw
    pcall(function()
        if Device and Device.screen_saver_mode then
            local ok_ss, Screensaver = pcall(require, "ui/screensaver")
            if ok_ss and Screensaver and Screensaver.show then
                Screensaver:show()
            end
        end
    end)

    -- Dirty UIManager full-screen refresh
    pcall(function()
        if UIManager and UIManager.setDirty then
            UIManager:setDirty(nil, "full")
        end
    end)
end

function DashboardPlugin:downloadDashboard(callback)
    local url = self.server_url
    local b_level, b_charging = self:getBatteryTelemetry()

    if b_level then
        local sep = url:find("%?") and "&" or "?"
        url = url .. sep .. "batteryLevel=" .. tostring(b_level) .. "&isCharging=" .. tostring(b_charging)
    end

    log_info("Starting download from: " .. tostring(url))

    local function execute_http_fetch()
        local ok, result = pcall(function()
            local socket = require("socket")
            local http = require("socket.http")
            local ltn12 = require("ltn12")

            local sink = {}
            local req = {
                url = url,
                sink = ltn12.sink.table(sink),
                headers = {
                    ["User-Agent"] = "KOReader-Dashboard/1.0 (Kindle WP63GW)",
                    ["Accept"] = "image/png,image/*",
                },
                create = function()
                    local tcp = socket.tcp()
                    if tcp then
                        tcp:settimeout(20)
                    end
                    return tcp
                end,
            }

            local _, code, headers, status = http.request(req)
            log_info("HTTP response code: " .. tostring(code))

            if code == 200 and #sink > 0 then
                local image_bytes = table.concat(sink)
                if #image_bytes > 500 then
                    -- Save to dedicated dashboard folder
                    local f, err = io.open(self.screensaver_file, "wb")
                    if f then
                        f:write(image_bytes)
                        f:close()

                        -- Mirror to screensavers root
                        pcall(function()
                            local f2 = io.open(self.screensaver_root_file, "wb")
                            if f2 then
                                f2:write(image_bytes)
                                f2:close()
                            end
                        end)

                        log_info("Successfully saved dashboard (" .. #image_bytes .. " bytes)")
                        return true
                    else
                        log_warn("Failed to write image: " .. tostring(err))
                        return false, "Write error: " .. tostring(err)
                    end
                else
                    return false, "Image response too small (" .. #image_bytes .. " bytes)"
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
    end

    -- Run with NetworkMgr if online, or fallback to direct fetch
    if NetworkMgr and NetworkMgr.runWhenOnline then
        NetworkMgr:runWhenOnline(execute_http_fetch)
    else
        execute_http_fetch()
    end
end

function DashboardPlugin:updateNow(show_feedback, redraw_immediately)
    if show_feedback then
        show_notification(_("Connecting to Wi-Fi and downloading dashboard..."), 3)
    end

    local execute_update = function()
        self:downloadDashboard(function(success, err_msg)
            if success then
                self:configureKOReaderScreensaver()
                if redraw_immediately then
                    self:refreshScreen()
                end
                if show_feedback then
                    show_notification(_("Dashboard updated successfully!\nSaved to sleep screen."), 4)
                end
            else
                if show_feedback then
                    show_notification(_("Failed to download dashboard:\n") .. tostring(err_msg) .. _("\nCheck Wi-Fi & URL: ") .. tostring(self.server_url), 6)
                end
            end
        end)
    end

    if UIManager and UIManager.scheduleIn then
        UIManager:scheduleIn(0.1, execute_update)
    else
        execute_update()
    end
end

function DashboardPlugin:schedulePeriodicRefresh()
    if self.periodic_task and UIManager and UIManager.unschedule then
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
                    self:refreshScreen()
                end
            end)
        end)
        if self.periodic_interval > 0 and UIManager and UIManager.scheduleIn then
            UIManager:scheduleIn(self.periodic_interval, self.periodic_task)
        end
    end

    if UIManager and UIManager.scheduleIn then
        pcall(function()
            UIManager:scheduleIn(self.periodic_interval, self.periodic_task)
        end)
    end
end

-- Hook into KOReader power suspend event
function DashboardPlugin:onSuspend()
    -- Sync and arm hardware background scheduler before sleeping
    self:syncScheduler()

    if self.auto_update_on_sleep then
        pcall(function()
            self:downloadDashboard(function(ok)
                if ok then
                    self:configureKOReaderScreensaver()
                end
            end)
        end)
    end
end

function DashboardPlugin:addToMainMenu(menu_items)
    menu_items.dashboard = {
        text = _("Kindle Dashboard"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text = _("Update & Display on Screen Now"),
                callback = function()
                    self:updateNow(true, true)
                end,
            },
            {
                text = _("Update Screensaver Only"),
                callback = function()
                    self:updateNow(true, false)
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
                            if G_reader_settings then
                                G_reader_settings:saveSetting("dashboard_periodic_interval", 0)
                            end
                            self:schedulePeriodicRefresh()
                            self:syncScheduler()
                        end,
                    },
                    {
                        text = _("Every 10 minutes"),
                        checked_func = function() return self.periodic_interval == 600 end,
                        callback = function()
                            self.periodic_interval = 600
                            if G_reader_settings then
                                G_reader_settings:saveSetting("dashboard_periodic_interval", 600)
                            end
                            self:schedulePeriodicRefresh()
                            self:syncScheduler()
                        end,
                    },
                    {
                        text = _("Every 15 minutes (Default)"),
                        checked_func = function() return self.periodic_interval == 900 end,
                        callback = function()
                            self.periodic_interval = 900
                            if G_reader_settings then
                                G_reader_settings:saveSetting("dashboard_periodic_interval", 900)
                            end
                            self:schedulePeriodicRefresh()
                            self:syncScheduler()
                        end,
                    },
                    {
                        text = _("Every 30 minutes"),
                        checked_func = function() return self.periodic_interval == 1800 end,
                        callback = function()
                            self.periodic_interval = 1800
                            if G_reader_settings then
                                G_reader_settings:saveSetting("dashboard_periodic_interval", 1800)
                            end
                            self:schedulePeriodicRefresh()
                            self:syncScheduler()
                        end,
                    },
                    {
                        text = _("Every 1 hour"),
                        checked_func = function() return self.periodic_interval == 3600 end,
                        callback = function()
                            self.periodic_interval = 3600
                            if G_reader_settings then
                                G_reader_settings:saveSetting("dashboard_periodic_interval", 3600)
                            end
                            self:schedulePeriodicRefresh()
                            self:syncScheduler()
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
                    if G_reader_settings then
                        G_reader_settings:saveSetting("dashboard_auto_update_on_sleep", self.auto_update_on_sleep)
                    end
                end,
            },
            {
                text = _("Change Server URL"),
                help_text = self.server_url,
                callback = function()
                    if not InputDialog or not UIManager then return end
                    local dialog
                    dialog = InputDialog:new{
                        title = _("Dashboard Server URL"),
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
                                            if G_reader_settings then
                                                G_reader_settings:saveSetting("dashboard_server_url", new_url)
                                            end
                                            self:syncScheduler()
                                        end
                                        UIManager:close(dialog)
                                    end,
                                },
                            },
                        },
                    }
                    UIManager:show(dialog)
                    if dialog.onShowKeyboard then
                        dialog:onShowKeyboard()
                    end
                end,
            },
            {
                text = _("Device Diagnostics"),
                callback = function()
                    local b_lvl, b_chg = self:getBatteryTelemetry()
                    local pid = "None"
                    pcall(function()
                        local f = io.open("/tmp/kindle_dashboard_scheduler.pid", "r")
                        if f then
                            pid = f:read("*all"):gsub("%s+", "")
                            f:close()
                        end
                    end)
                    local diag = string.format(
                        "Battery: %s%%\nCharging: %s\nInterval: %dm\nHardware Scheduler PID: %s\nURL: %s",
                        tostring(b_lvl or "Unknown"),
                        (b_chg == 1 and "Yes" or "No"),
                        math.floor((self.periodic_interval or 900) / 60),
                        pid,
                        self.server_url
                    )
                    show_notification(diag, 6)
                end,
            },
        },
    }
    -- Also register under more_tools so it appears in both locations regardless of menu config
    menu_items.dashboard_more = {
        text = _("Kindle Dashboard"),
        sorting_hint = "more_tools",
        sub_item_table = menu_items.dashboard.sub_item_table,
    }
end

return DashboardPlugin
