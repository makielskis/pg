status_donate = {}
status_donate["timestamp"] = "0"
status_donate["loot"] = "-"
status_donate["wash"] = "0"
status_donate["loot_from"] = "$loot_from"

interface_donate = {}
interface_donate['module'] = "Spenden"
interface_donate["active"] = { input_type = "toggle", display_name = "Spenden starten" }
interface_donate["wash"] = { input_type = "checkbox", display_name = "Waschen" }
interface_donate["loot"] = { input_type = "dropdown", display_name = "Plunder" }


function get_link(callback)
  util.log("getting link")
  return http.get_path("/overview/", function(page)
    local link = util.get_by_xpath(page, '//input[@name="reflink"]/@value')
    local err = link == ""
    return callback(err, link)
  end)
end

function clean(callback)
  if status_donate["wash"] ~= "1" then
    return callback(false)
  end

  util.log("cleaning")
  return http.get_path("/city/washhouse/", function(page)
    http.submit_form(page, '//table[@class="tieritemB"]//input[@type="submit"]', function(page_result)
      return callback(false)
    end)
  end)
end

function run_donate()
  if os.time() > tonumber(status_donate["timestamp"]) or status_donate["timestamp"] == "0" then
    return get_link(function(err, link)
      if err then
        util.log("no donate link")
        return on_finish(86400 + 10, 86400 + 60) -- 24h
      end

      return clean(function()
        return equip(status_donate["loot"], function(err)
          util.log("requesting donations")
          util.set_status("timestamp", tostring(os.time() + 86400))
          return http.post("http://pennerga.me/donate.php", "url=".. link, function(not_used)
            -- will not execute because page is to slow
            return on_finish(86400 + 10, 86400 + 60) -- 24h
          end)
        end)
      end)
    end)
  else
    local nexttime = tonumber(status_donate["timestamp"]) - os.time()
    return on_finish(nexttime + 10, nexttime + 60)
  end
end

function finally_donate()
  unlock_loot()
end
