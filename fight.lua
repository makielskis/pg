dofile('packages/pg/base.lua')

status_fight = {}
status_fight["victims"] = ""
status_fight["auto"] = "0"
status_fight["blocklist"] = ""

interface_fight = {}
interface_fight["module"] = "Kämpfen"
interface_fight["active"] = { input_type = "toggle", display_name = "Kämpfen starten" }
interface_fight["victims"] = { input_type = "list_textfield", display_name = "Gegner" }
interface_fight["auto"] = { input_type = "checkbox", display_name = "Downfight Gegner" }

function get_fighttimer(callback)
  return get_pennerbar("kampftimer", function(not_used, timer)
    return callback(not_used, tonumber(timer))
  end)
end

function set_next_victim()
  local pos = string.find(status_fight["victims"], ",")
  if pos ~= nil then
    local new_status = string.sub(status_fight["victims"], pos + 1)
    util.set_status("victims", new_status)
  else
    util.set_status("victims", "")
  end
end

function empty_cart(callback)
  return http.get_path("/activities/", function(page)
    -- empty cart
    if util.get_by_xpath(page, "//input[@name = 'bottlecollect_pending']/@value") == "True" then
      util.log("clearing cart")
      return http.submit_form(page, "//form[contains(@action, 'bottle')]", function(page)
        return callback(false, page)
      end)
    else
      return callback(false, page)
    end
  end)
end

function get_downfight_victim(fightpage, callback)
  -- get fight values
  local att = tonumber(util.get_by_xpath(fightpage, "//div[@class = 'box_att']/span[@class = 'fight_num']"))
  local def = tonumber(util.get_by_xpath(fightpage, "//div[@class = 'box_def']/span[@class = 'fight_num']"))

  -- get highscore limits
  local highscore_link = util.get_by_xpath(fightpage, "//a[contains(@href, '/highscore/user/?min=')]/@href")
  local matches = util.get_all_by_regex(highscore_link, "=([\\d]*)")
  local min_score = tonumber(matches[1][1])
  local max_score = tonumber(matches[2][1])

  -- get city
  local city_code = util.get_by_xpath(fightpage, "//meta[@name = 'language']/@content")
  if string.sub(city_code, -2) ~= "DE" then
    return callback("downfight not available for this city", nil)
  end

  if att ~= nil and def ~= nil and min_score ~= nil and max_score ~= nil then
    -- request downfight api
    local url = "http://downfight.de/api.php?"
    url = url .. "mydef=" .. def .. "&"
    url = url .. "myatt=" .. att .. "&"
    url = url .. "min=" .. min_score .. "&"
    url = url .. "max=" .. max_score .. "&"
    url = url .. "stadt=" .. city_code .. "&"
    url = url .. "foo=.xml"
    util.log("DF-API: " .. url)

    return http.get(url, function(df_page)
      local names = util.get_all_by_regex(df_page, "<name>([^<]*)</name>")
      local profiles = util.get_all_by_regex(df_page, "<profil>([^<]*)</profil>")

      for i,v in ipairs(names) do
        if not is_blocked(v[1]) then
          util.log("downfight victim: " .. v[1])
          return callback(false, v[1])
        end
      end
    end)
  else
    return callback("could not read all fight values", nil)
  end
end

function is_blocked(check_name)
  util.log("checking if " .. check_name .. " is blocked")
  local new_blocklist = ""
  local matches = util.get_all_by_regex(status_fight["blocklist"], "([^,]*),")

  local found = false
  for i1,v1 in ipairs(matches) do
    for i2,entry in ipairs(v1) do
      if entry ~= "" then
        local pos = entry:find("|")
        local name = entry:sub(0, pos - 1)
        local time = tonumber(entry:sub(pos + 1))
        if os.time() < time then
          -- readd entry
          new_blocklist = new_blocklist .. entry .. ","

          -- found it!
          if name == check_name then
            found = true
            util.log(name .. " is blocked")
          end
        end
      end
    end
  end

  if not found then
    new_blocklist = new_blocklist .. check_name .. "|" .. os.time()  .. ","
  end

  util.set_status("blocklist", new_blocklist)
  return found
end

function get_next_victim(callback)
  -- get victims
  if status_fight["auto"] == "1" then
    return http.get_path("/fight/", function(page)
      return get_downfight_victim(page, function(err, victim)
        if err then
          return callback("no_downfight_victim", nil)
        else
          return callback(false, victim)
        end
      end)
    end)
  else
    victims = explode(",", status_fight["victims"])
    if victims[1] == "" then
      return callback("no_victiutil.set", nil)
    else
      return callback(false, victims[1])
    end
  end
end

function get_block_time(page, callback)
  local activity_timer = get_activity_time(page)
  return get_fighttimer(function(not_used, fight_timer)
    return callback(false, math.max(fight_timer, activity_timer))
  end)
end

function run_fight()
  return get_next_victim(function(err, next_victim)
    if err and err == "no_downfight_victim" then
      util.log("no downfight victim in range")
      return on_finish(900, 1200)
    elseif err and err == "no_victiutil.set" then
      util.log("no victim set")
      return on_finish(-1)
    else
      -- start fight
      util.log("next victim: " .. next_victim)
      util.log("getting fight page")
      return http.get_path("/fight/?to=" .. next_victim, function(page)
        return get_block_time(page, function(err, timer)
          if timer > 0 then
            util.log("wait for running activity to finish")
            return on_finish(timer + 10, timer + 60)
          end

          -- start fight
          util.log("starting fight")
          return http.submit_form(page, "//input[@name = 'Submit2']", function(page)
            -- check
            local url = util.get_by_xpath(page, "//meta[@name = 'location']/@content")
            local status = util.get_by_regex(url, "=([a-z]*)$")
            if status == "limitexceed" then
              util.log("victim not in point range")
            elseif status == "notfound" then
              util.log("victim dosn't exist")
            elseif status == "locked36h" then
              util.log("victim has 36h protection")
            elseif status == "holiday" then
              util.log("victim hast holiday protection")
            elseif status == "erroractivity" then
              return empty_cart(function(err, page)
                return on_finish(20, 60)
              end)
            elseif status == "success" then
              util.log("fight started")
              set_next_victim()
              return get_fighttimer(function(not_used, timer)
                return on_finish(timer + 10, timer + 100)
              end)
            end

            -- fight was not started
            util.log("fight not started")
            set_next_victim()
            return on_finish(20, 60)
          end)
        end)
      end)
    end
  end)
end
