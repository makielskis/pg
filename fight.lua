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

function get_fighttimer()
  return tonumber(get_pennerbar("kampftimer"))
end

function empty_cart()
  local page = m_request_path("/activities/")
	-- empty cart
	if (m_get_by_xpath(page, "//input[@name = 'bottlecollect_pending']/@value") == "True") then
		m_log("clearing cart")
		m_submit_form(page, "//form[contains(@action, 'bottle')]")
	end
end

function set_next_victim()
  local pos = string.find(status_fight["victims"], ",")
  if pos ~= nil then
    local new_status = string.sub(status_fight["victims"], pos + 1)
    m_set_status("victims", new_status)
  else
    m_set_status("victims", "")
  end
end

function get_downfight_victim(fightpage)
  -- get fight values
  local att = tonumber(m_get_by_xpath(fightpage, "//div[@class = 'box_att']/span[@class = 'fight_num']"))
  local def = tonumber(m_get_by_xpath(fightpage, "//div[@class = 'box_def']/span[@class = 'fight_num']"))

  -- get highscore limits
  local highscore_link = m_get_by_xpath(fightpage, "//a[contains(@href, '/highscore/user/?min=')]/@href")
  local matches = m_get_all_by_regex(highscore_link, "=([\\d]*)")
  local min_score = tonumber(matches[1][1])
  local max_score = tonumber(matches[2][1])

  -- get city
  local city_code = m_get_by_xpath(fightpage, "//meta[@name = 'language']/@content")
  if string.sub(city_code, -2) ~= "DE" then
    m_log("downfight not available for this city")
    return false
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
    m_log("DF-API: " .. url)

    local df_page = m_request(url)
    local names = m_get_all_by_regex(df_page, "<name>([^<]*)</name>")
    local profiles = m_get_all_by_regex(df_page, "<profil>([^<]*)</profil>")

    for i,v in ipairs(names) do
      if not is_blocked(v[1]) then
        --m_request(profiles[i][1])
        m_log("downfight victim: " .. v[1]);
        return v[1]
      end
    end
  else
    m_log("could not read all fight values")
  end
end

function is_blocked(check_name)
  print("checking blocklist")
  local new_blocklist = ""
  local matches = m_get_all_by_regex(status_fight["blocklist"], "([^,]*),")

  local found = false
  for i1,v1 in ipairs(matches) do
    for i2,entry in ipairs(v1) do
      if entry ~= "" then
        print(entry)
        local pos = entry:find("|")
        local name = entry:sub(0, pos - 1)
        local time = tonumber(entry:sub(pos + 1))
        if os.time() < time then
          -- readd entry
          new_blocklist = new_blocklist .. entry .. ","

          -- found it!
          if name == check_name then
            found = true
            m_log(name .. " is blocked")
          end
        end
      end
    end
  end

  if not found then
    new_blocklist = new_blocklist .. check_name .. "|" .. os.time()  .. ","
  end

  m_set_status("blocklist", new_blocklist)
  return found
end

function run_fight()
  -- get victims
  local next_victim
  if status_fight["auto"] == "1" then
    next_victim = get_downfight_victim(m_request_path("/fight/"))
    if next_victim == nil then
      m_log("no victims in downfight")
      return 900, 1200
    end
  else
    victims = explode(",", status_fight["victims"])
    if victims[1] == "" then
      -- stop module
      m_log("no victims set")
      return -1
    end

    next_victim = victims[1]
  end

  -- start fight
  m_log("next victim: " .. next_victim)
  m_log("getting fight page")
  local page = m_request_path("/fight/?to=" .. next_victim)

  -- check timers
  local fight_timer = get_fighttimer()
  local activity_timer = get_activity_time(page)
  local timer = math.max(fight_timer, activity_timer)

  if timer > 0 then
    m_log("wait for running activity to finish")
    return timer + 10, timer + 60
  end

  -- start fight
  m_log("starting fight")
  page = m_submit_form(page, "//input[@name = 'Submit2']")

  -- check
  local url = m_get_by_xpath(page, "//meta[@name = 'location']/@content")
  local status = m_get_by_regex(url, "=([a-z]*)$")
  local retry = false
  if status == "limitexceed" then
    m_log("victim not in point range")
  elseif status == "notfound" then
    m_log("victim dosn't exist")
  elseif status == "locked36h" then
    m_log("victim has 36h protection")
  elseif status == "holiday" then
    m_log("victim hast holiday protection")
  elseif status == "erroractivity" then
    empty_cart()
    retry = true
  elseif status == "success" then
    m_log("fight started")
    timer = get_fighttimer()
    set_next_victim()
    return timer + 10, timer + 100
  end

  -- fight was not started
  m_log("fight not started")
  if retry then
    return 20, 60
  else
    set_next_victim()
  end

  -- not started -> go for the next one
  return 10, 60
end
