status_collect = {}
status_collect["startloot"] = "-"
status_collect["startloot_from"] = "$loot_from"
status_collect["endloot"] = "-"
status_collect["endloot_from"] = "$loot_from"
status_collect["collecttime"] = ""
status_collect["collecttime_from"] = ""
status_collect["collecttimeauto"] = "0"

interface_collect = {}
interface_collect["module"] = "Flaschen sammeln"
interface_collect["active"] = { input_type = "toggle", display_name = "Sammeln gehen" }
interface_collect["startloot"] = { input_type = "dropdown", display_name = "Start-Plunder" }
interface_collect["endloot"] = { input_type = "dropdown", display_name = "Einkaufswagen-Plunder" }
interface_collect["collecttime"] = { input_type = "dropdown", display_name = "Sammelzeit (in Minuten)" }
interface_collect["collecttimeauto"] = { input_type = "checkbox", display_name = "Sammelzeit automatisch erkennen" }

function get_collect_time(page)
  local link = util.get_by_xpath(page, "//a[@href = '/activities/' and @class= 'ttip']")
  local collect_time = tonumber(util.get_by_regex(link, "counter\\((-?[0-9]*)"))
  if collect_time >= 0 then
    util.log("collecting " .. collect_time)
  end
	return collect_time
end

function get_collect_times(page)
  util.log("reading collect times")
  local options = util.get_all_by_xpath(page, "//select[@name = 'time']/option")
  local collect_times = ""
  for k,v in pairs(options) do
    collect_times = collect_times .. "," .. util.get_by_regex(v, 'value="([^"]*)')
  end
  util.set_status("collecttime_from", collect_times)
  return
end

function run_collect()
  local cart_junk_lock_id = 0
  local start_junk_lock_id = 0

  chain({
    -- get activity page
    function(not_used_1, callback)
      return http.get_path("/activities/", function(page)
        get_collect_times(page)

        if not isset(status_collect["collecttime"]) and status_collect["collecttimeauto"] ~= "1" then
          util.log("no collect time set")
          return callback("stop", 0)
        end

        return callback(false, page)
      end)
    end,

    --login check
    login_page,

    -- check for running activities
    function(page, callback)
      -- return when collecting
      local collect_time = get_collect_time(page)
      if collect_time > 0 then
        util.log("already collecting")
        return callback("blocked", collect_time)
      end

      return get_pennerbar("kampftimer", function(err, fight_time)
        if err then
          util.log("cannot read fight timer")
          return callback(err)
        end

         -- return when fighting
        fight_time = tonumber(fight_time)
        if fight_time > 0 then
          util.log("fighting " .. fight_time)
          return callback("blocked", fight_time)
        end

        -- not blocked
        return callback(false, page)
      end)
    end,

    -- equip empty cart junk
    function(page, callback)
      return equip(status_collect["endloot"], false, function(err)
        if err then
          util.log(err)
          return callback("loot")
        end

        return callback(false, page)
      end)
    end,

    -- clear cart
    function(page, callback)
      return clear_cart(page, callback)
    end,

    -- equip start loot
    function(not_used_1, callback)
      return equip(status_collect["startloot"], false, function(err)
        if err then
          util.log(err)
          return callback("loot")
        end

        return callback(false)
      end)
    end,

    -- reload page
    function(not_used_1, callback)
      return http.get_path("/activities/", function(page)
        return callback(false, page)
      end)
    end,

    -- start collecting
    function(page, callback)
      local parameters = {}

      if status_collect["collecttimeauto"] == "1" then
        parameters["sammeln"] = util.get_by_xpath(page, "//select[@name = 'time']/option[@selected = 'selected']/@value")
      elseif isset(status_collect["collecttime"]) then
        parameters["sammeln"] = status_collect["collecttime"]
      else
        util.log("no collect time set [late]")
        return callback("stop", 0)
      end

      util.log("starting to collect - collect time " .. parameters["sammeln"])
      return http.submit_form(page, "//form[contains(@name, 'starten')]", parameters, "/activities/bottle/", function(page)
        collect_time = get_collect_time(page)
        return callback(false, collect_time)
      end)
    end,
  }, false, nil, function(err, time)
    if err == "stop" then
      util.log_debug("collect time missing - quit")
      return on_finish(-1)
    elseif err == "blocked" or err == false then
      return on_finish(time, time + 180)
    else
      return on_finish(60, 180)
    end
  end)
end

function finally_collect()
  return loot_done(function()
    return on_finish()
  end)
end
