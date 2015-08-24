status_donate = {}
status_donate["timestamp"] = "0"
status_donate["donation_count"] = "0"
status_donate["loot"] = "-"
status_donate["wash"] = "0"
status_donate["loot_from"] = "$loot_from"

interface_donate = {}
interface_donate['module'] = "Spenden"
interface_donate["active"] = { input_type = "toggle", display_name = "Spenden starten" }
interface_donate["wash"] = { input_type = "checkbox", display_name = "Waschen" }
interface_donate["loot"] = { input_type = "dropdown", display_name = "Plunder" }

max_donations = 12

function get_next_donation_time()
  return tonumber(status_donate["timestamp"])
end

function set_current_donations(donation_count)
  util.log_debug("current donations: " .. tostring(donation_count))
  local current_donations_str = tostring(donation_count)
  util.set_status("donation_count", current_donations_str)
  status_donate["donation_count"] = current_donations_str
end

function is_first_donation_time()
  return status_donate["timestamp"] == "0"
end

function get_current_donations()
  return tonumber(status_donate["donation_count"])
end

function sleep_until_next_time()
  local nexttime = tonumber(status_donate["timestamp"]) - os.time()
  return on_finish(nexttime + 10, nexttime + 60)
end

function check_donation_needed()
  local now = os.time()
  local next_donation_time = get_next_donation_time()
  local overdue = now > next_donation_time
  util.log_debug("now=" .. now .. ", next=" .. next_donation_time .. ", overdue=" .. tostring(overdue))

  local current_donations = get_current_donations()
  local enough = current_donations >= max_donations
  util.log_debug(current_donations .. "/" .. max_donations .. ", enough=" .. tostring(enough))

  if enough then
    util.log("enough donations, next donations in 24h")
    util.set_status("timestamp", tostring(os.time() + 86400))
    set_current_donations(0)
  end

  return overdue and not enough
end

function get_link(callback)
  util.log("getting link")
  return http.get_path("/overview/", function(page)
    return login_page(page, function(err, page)
      if err then
        return callback("not logged in", nil)
      end
      local link = util.get_by_xpath(page, '//input[@name="reflink"]/@value')
      if link == "" then
        return callback("no donate link", nil)
      else
        return callback(err, link)
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

function donate(link)
  local donation_count = get_current_donations()
  if not check_donation_needed() then
    util.log("no donation required")
    return sleep_until_next_time()
  else
    util.log(donation_count .. "/" .. max_donations .. " donations - requesting")
    return http.post("http://spenden.hitfaker.net/proxy.php", "url=".. link .. "&i=" .. donation_count .. "&count=240", function(not_used)
      util.log("donation " .. donation_count .. "/" .. max_donations .. " confirmed")
      set_current_donations(donation_count + 1)
      donate(link)
    end)
  end
end

function run_donate()
  if check_donation_needed() then
    return get_link(function(err, link)
      if err then
        util.log_error(err)
        return on_finish(30, 180)
      end

      return clean(function()
        return equip(status_donate["loot"], false, function(err)
          return donate(link, 0)
        end)
      end)
    end)
  else
    return sleep_until_next_time()
  end
end

function finally_donate()
  return loot_done(function()
    return on_finish()
  end)
end
