dofile('packages/pg/base.lua')

status_study = {}
status_study["trainings"] = ","
status_study["trainings_from"] = "att,def,agi,sprechen,bildungsstufe,musik,sozkontakte,konzentration,pickpocket"
status_study["alcohol"] = "0"
status_study["training_index"] = "1"

interface_study = {}
interface_study["module"] = "Weiterbildungen"
interface_study["active"] = { input_type = "toggle", display_name = "Weiterbildungen starten" }
interface_study["trainings"] = { input_type = "list_list", display_name = "Weiterbildungen" }
interface_study["alcohol"] = { input_type = "checkbox", display_name = "Betrinken" }

function start_training(page, training)
  -- get taining name + mystery number
  m_log("reading mystery id")
  local btn_id = m_get_by_xpath(page, "//form[@action = '/itemsale/transaction/buy/']/input[starts-with(@id, '" .. training .. "')]/@id")

  if btn_id == "" then
    m_log("training not startable")
    return false
  end

  -- drink
  if tonumber(status_study["alcohol"]) == 1 then
    increase_alc()
  end

  -- "setup form"
  m_log("starting training: " .. training)
  local action = "/skill/upgrade/" .. btn_id .. "/"
  page = m_submit_form(page, "//form[@name = 'starten']", {}, action)

  -- drink
  if tonumber(status_study["alcohol"]) == 1 then
    decrease_alc()
  end

  -- success?
  local url = m_get_by_xpath(page, "//meta[@name = 'location']/@content")
  if string.find(url, "success") == nil then
    return false
  end

  return true
end

function get_timer()
  return tonumber(get_pennerbar("timer"))
end

function buy_food(count)
  m_log("buying " .. count .. " breads")

  local params = {}
  params["menge"] = count

  local page = m_request_path("/city/supermarket/food/")
  m_submit_form(page, "//input[@id = 'submitForm0']", params)
end

function buy_beer(count)
  m_log("buying " .. count .. " beers")

  local params = {}
  params["menge"] = count

  local page = m_request_path("/city/supermarket/")
  m_submit_form(page, "//input[@id = 'submitForm0']", params)
end

function drink_beer(count)
  m_log("drinking " .. count .. " beers")

  local params = {}
  params["menge"] = count

  local page = m_request_path("/stock/")
  m_submit_form(page, "//input[@id = 'drink_Bier']", params)
end

function eat_bread(count)
  m_log("eating " .. count .. " breads")

  local params = {}
  params["menge"] = count

  local page = m_request_path("/stock/foodstuffs/food/")
  m_submit_form(page, "//input[@id = 'drink_Brot']", params)
end

function increase_alc()
  local pennerbar = m_request_path("/pennerbar.xml")
  local money = tonumber(get_pennerbar_page(pennerbar, "cash")) / 100
  local alc_level = tonumber(get_pennerbar_page(pennerbar, "promille"))

  if money < 9 * 2.55 then
    m_log("not enough money for alcohol")
    return false
  end

  buy_food(9)
  local beerCount = round(((2.5 - alc_level) / 0.35) + 0.5)
  buy_beer(beerCount)
  drink_beer(beerCount)
end

function decrease_alc()
  eat_bread(9)
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
  local training_index = tonumber(status_study["training_index"])
  if training_index >= #trainings then
    m_log("restarting from begin")
    training_index = 1
    m_set_status("training_index", "1")
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
  m_set_status("training_index", tostring(training_index + 1))

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
