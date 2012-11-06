dofile('packages/kv/base.lua')

status_study = {}
status_study["trainings"] = ","
status_study["trainings_from"] = "att,def,agi,sprechen,musik,sozkontakte,konzentration,pickpocket"

interface_study = {}
interface_study["module"] = "Weiterbildungen"
interface_study["active"] = { input_type = "toggle", display_name = "Weiterbildungen starten" }
interface_study["trainings"] = { input_type = "list_list", display_name = "Weiterbildungen" }

training_index = 1

function start_training(page, training)
  -- get taining name + mystery number
  m_log("reading mystery id")
  local btn_id = m_get_by_xpath(page, "//form[@action = '/itemsale/transaction/buy/']/input[starts-with(@id, '" .. training .. "')]/@id")

  if btn_id == "" then
    m_log("training not startable")
    return false
  end

  -- "setup form"
    m_log("starting training: " .. training)
  local action = "/skill/upgrade/" .. btn_id .. "/"
  page = m_submit_form(page, "//form[@name = 'starten']", {}, action)

  -- success?
  local url = m_get_by_xpath(page, "//meta[@name = 'location']/@content")
  if string.find(url, "success") == nil then
    return false
  end

  return true
end

function get_timer() 
  m_log("getting pennerbar")
  local pennerbar = m_request_path("/pennerbar.xml")
  local timer = m_get_by_xpath(pennerbar, "//timer/@value")
  return tonumber(timer)
end

function run_study()
  -- get trainings from staus
  local trainings = explode(",", status_study["trainings"])
  if trainings[1] == "" then
    -- stop module
    m_log("no trainings set")
    return -1
  end

  -- start from begin if couter is impossible
  if training_index >= #trainings then
    m_log("restarting from begin")
    training_index = 1
  end

  -- check timer
  local timer = get_timer()

  if timer >= 0 then
    m_log("wait for running training to finish")
    return timer + 10, timer + 60
  end

  -- start training
  local next_training = trainings[training_index]
  m_log("next training: " .. next_training)

  m_log("getting study page")
  local page = m_request_path("/skills/")
  local result = start_training(page, next_training)

  -- next time -> next training
  training_index = training_index + 1

  -- evaluate result
  if result then
    timer = get_timer()
    if timer >= 0 then
      return timer + 10, timer + 60
    end
  end

  -- training not started go for the next one
  return 10, 60
end
