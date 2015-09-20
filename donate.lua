status_donate = {}
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
    return login_page(page, function(err, page)
      if err then
        return callback("not logged in", nil)
      end

      local link = util.get_by_xpath(page, '//input[@name="reflink"]/@value')

      local count_text = util.get_by_xpath(page, '//ul[.//input[@name="reflink"]]/li[last() - 1]')
      local count_match = string.gmatch(count_text, "%d+")
      local current = tonumber(count_match(1))
      local needed = tonumber(count_match(2))
      local total = current + needed

      util.log_debug("link: " .. link)
      util.log("donations: " .. current .. "/" .. total)

      if link == "" then
        return callback("no donate link", nil, nil)
      else
        return callback(err, link, needed)
      end
    end)
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

function donate(link, donation_count, needed)
  if needed == 0 then
    util.log("all donations requested")
    return on_finish(30, 180)
  else
    util.log(needed .. " donations to request")
    return http.post("http://spenden.hitfaker.net/proxy.php", "url=".. link .. "&i=" .. donation_count .. "&count=240", function(not_used)
      util.log("donation " .. donation_count .. " confirmed")
      donate(link, donation_count + 1, needed - 1)
    end)
  end
end

function run_donate()
  return get_link(function(err, link, needed)
    if err then
      util.log_error(err)
      return on_finish(30, 180)
    end

    if needed == 0 then
      util.log("no donations needed, retry in ~1h")
      return on_finish(3300, 3900)
    end

    return clean(function()
      return equip(status_donate["loot"], false, function(err)
        return donate(link, 0, needed * 2)
      end)
    end)
  end)
end

function finally_donate()
  return loot_done(function()
    return on_finish()
  end)
end
