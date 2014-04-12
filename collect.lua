status_collect = {}
status_collect["startloot"] = "-"
status_collect["startloot_from"] = "$loot_from"
status_collect["endloot"] = "-"
status_collect["endloot_from"] = "$loot_from"

interface_collect = {}
interface_collect["module"] = "Flaschen sammeln"
interface_collect["active"] = { input_type = "toggle", display_name = "Sammeln gehen" }
interface_collect["startloot"] = { input_type = "dropdown", display_name = "Start-Plunder" }
interface_collect["endloot"] = { input_type = "dropdown", display_name = "Einkaufswagen-Plunder" }

function get_collect_time(page)
  local link = util.get_by_xpath(page, "//a[@href = '/activities/' and @class= 'ttip']")
  local collect_time = tonumber(util.get_by_regex(link, "counter\\((-?[0-9]*)"))
  if collect_time >= 0 then
    util.log("collecting " .. collect_time)
  end
	return collect_time
end

function run_collect()
  local cart_junk_lock_id = 0
  local start_junk_lock_id = 0

  chain({
    -- get activity page
    function(not_used_0, not_used_1, callback)
      return http.get_path("/activities/", function(page)
        return callback(false, page)
      end)
    end,

    -- check for running activities
    function(not_used, page, callback)
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
    function(not_used, page, callback)
      return equip(status_collect["endloot"], false, function(err)
        if err then
          util.log(err)
          return callback("loot")
        end

        return callback(false, page)
      end)
    end,

    -- clear cart
    function(not_used, page, callback)
      return clear_cart(page, callback)
    end,

    -- equip start loot
    function(not_used_0, not_used_1, callback)

      return equip(status_collect["startloot"], false, function(err)
        if err then
          util.log(err)
          return callback("loot")
        end

        return callback(false)
      end)
    end,

    -- reload page
    function(not_used_0, not_used_1, callback)
      return http.get_path("/activities/", function(page)
        return callback(false, page)
      end)
    end,

    -- start collecting
    function(not_used, page, callback)
      local selected = util.get_by_xpath(page, "//select[@name = 'time']/option[@selected = 'selected']/@value")
      local parameters = {}
      parameters["sammeln"] = selected

      util.log("starting to collect - collect time " .. selected)

      return http.submit_form(page, "//form[contains(@name, 'starten')]", parameters, "/activities/bottle/", function(page)
        collect_time = get_collect_time(page)
        return callback(false, collect_time)
      end)
    end,
  }, false, nil, function(err, time)
    if err == "blocked" or err == false then
      return on_finish(time, time + 180)
    end

    return on_finish(60, 180)
  end)
end

function finally_collect()
  return loot_done(function()
    return on_finish()
  end)
end
