dofile('packages/pg/base.lua')

status_fight = {}
status_fight["victims"] = ""

interface_fight = {}
interface_fight["module"] = "Kämpfen"
interface_fight["active"] = { input_type = "toggle", display_name = "Kämpfen starten" }
interface_fight["victims"] = { input_type = "list_textfield", display_name = "Gegner" }

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

function run_fight()
  -- get victims from staus
  local victims = explode(",", status_fight["victims"])
  if victims[1] == "" then
    -- stop module
    m_log("no victims set")
    return -1
  end

  -- start fight
  local next_victim = victims[1]
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
    set_next_victim(victims)
    return timer + 10, timer + 100
  end

  -- fight was not started
  m_log("fight not started")
  if retry then
    return 20, 60
  else
    set_next_victim(victims)
  end

  -- not started -> go for the next one
  return 10, 60
end
