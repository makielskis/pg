status_study = {}
status_study["trainings"] = ","
status_study["trainings_from"] = "att,def,agi,sprechen,bildungsstufe,musik,sozkontakte,konzentration,pickpocket"
status_study["alcohol"] = "0"
status_study["training_index"] = "1"
status_study["loot"] = "-"
status_study["loot_from"] = "$loot_from"

interface_study = {}
interface_study["module"] = "Weiterbildungen"
interface_study["active"] = { input_type = "toggle", display_name = "Weiterbildungen starten" }
interface_study["trainings"] = { input_type = "list_list", display_name = "Weiterbildungen" }
interface_study["alcohol"] = { input_type = "checkbox", display_name = "Betrinken" }
interface_study["loot"] = { input_type = "dropdown", display_name = "Plunder" }

function start_training(page, training, callback)
  -- get taining name + mystery number
  util.log("reading mystery id")
  local btn_id = util.get_by_xpath(page, "//form[@action = '/itemsale/transaction/buy/']/input[starts-with(@id, '" .. training .. "')]/@id")

  if btn_id == "" then
    return callback("training not startable", page)
  end

  return chain({
    -- equip selected junk item
    function(not_used_1, callback)
        return equip(status_study["loot"], false, callback)
    end,

    -- INCREASE ALCOHOL (IF ACTIVATED)
    function(not_used_1, callback)
      if status_study["alcohol"] == "1" then
        return increase_alc(callback)
      else
        return callback(false, nil)
      end
    end,

    -- START TRAINING
    function(not_used_1, callback)
      util.log("starting training: " .. training)
      local action = "/skill/upgrade/" .. btn_id .. "/"
      return http.submit_form(page, "//form[@name = 'starten']", {}, action, function(page)
        return callback(false, page)
      end)
    end,

    -- DECREASE ALCOHOL (IF ACTIVATED)
    function(page, callback)
      if status_study["alcohol"] == "1" then
        -- make sure the form submit response is forwarded to the success check
        return eat_bread(9, function(not_used_0, not_used_1)
          return callback(false, page)
        end)
      else
        return callback(false, page)
      end
    end,

    -- CHECK SUCCESS
    function(page, callback)
      local url = util.get_by_xpath(page, "//meta[@name = 'location']/@content")
      if string.find(url, "success") == nil then
        return callback("return status != success", page)
      else
        return callback(false, page)
      end
    end
  }, false, page, callback)
end

function get_timer(page)
  local link = util.get_by_xpath(page, "//a[@href = '/skills/' and @class= 'ttip']")
  local time = tonumber(util.get_by_regex(link, "counter\\((-?[0-9]*)"))
  if time >= 0 then
    util.log("training active: " .. time)
  end
  return time
end

function buy_food(count, callback)
  util.log("buying " .. count .. " breads")

  local params = {}
  params["menge"] = count

  return http.get_path("/city/supermarket/food/", function(page)
    return http.submit_form(page, "//input[@id = 'submitForm0']", params, function(page)
      return callback(false, page)
    end)
  end)
end

function buy_beer(count, callback)
  util.log("buying " .. count .. " beers")

  local params = {}
  params["menge"] = count

  return http.get_path("/city/supermarket/", function(page)
    return http.submit_form(page, "//input[@id = 'submitForm0']", params, function(page)
      return callback(false, page)
    end)
  end)
end

function drink_beer(count, callback)
  util.log("drinking " .. count .. " beers")

  local params = {}
  params["menge"] = count

  return http.get_path("/stock/foodstuffs/", function(page)
    return http.submit_form(page, "//input[@id = 'drink_Bier']", params, function(page)
      return callback(false, page)
    end)
  end)
end

function eat_bread(count, callback)
  util.log("eating " .. count .. " breads")

  local params = {}
  params["menge"] = count

  return http.get_path("/stock/foodstuffs/food/", function(page)
    return http.submit_form(page, "//input[@id = 'drink_Brot']", params, function(page)
      return callback(false, page)
    end)
  end)
end

function increase_alc(callback)
  return http.get_path("/pennerbar.xml", function(pennerbar)
    local money = tonumber(get_pennerbar_info(pennerbar, "cash")) / 100
    local alc_level = tonumber(get_pennerbar_info(pennerbar, "promille"))
    local beerCount = round(((2.5 - alc_level) / 0.35) + 0.5)

    if money < 9 * 2.55 then
      util.log("not enough money for alcohol")
      return callback(true, nil)
    else
      return chain({
        function(not_used_1, callback)
          return buy_food(9, callback)
        end,

        function(not_used_1, callback)
          return buy_beer(beerCount, callback)
        end,

        function(not_used_1, callback)
          return drink_beer(beerCount, callback)
        end
      }, false, nil, callback)
    end
  end)
end

function run_study()
  -- get trainings from staus
  if status_study["trainings"] == "" then
    -- stop module
    util.log("no trainings set")
    return on_finish(-1)
  end

  local trainings = explode(",", status_study["trainings"])

  -- start from begin if index is out of rage
  local training_index = tonumber(status_study["training_index"])
  if training_index > #trainings then
    util.log("restarting from begin")
    training_index = 1
    util.set_status("training_index", "1")
  end

  return http.get_path("/skills/", function(page)
    -- login
    return login_page(page, function(err, page)
      if err then
        util.log_error("not logged in")
        return on_finish(30, 180)
      end

      -- check timer
      local timer = get_timer(page)
      if timer >= 0 then
        util.log("wait for running training to finish")
        return on_finish(timer + 10, timer + 60)
      end

      -- start training
      local next_training = trainings[training_index]
      util.log("next training: " .. next_training)

      util.log("getting study page")

      return start_training(page, next_training, function(err, page)
        -- next time -> next training
        util.set_status("training_index", tostring(training_index + 1))

        -- evaluate err
        if not err then
          local timer = get_timer(page)
          if timer >= 0 then
            -- training start
            return on_finish(timer + 10, timer + 60)
          else
            -- training not started go for the next one
            return on_finish(10, 60)
          end
        else
          -- training not started go for the next one
          util.log_error("training not started")
          util.log_error("error: " .. err)
          return on_finish(10, 60)
        end
      end)
    end)
  end)
end

function finally_study()
  return loot_done(function()
    return on_finish()
  end)
end
