status_stray = {}
status_stray["pets"] = ""
status_stray["pets_from"] = ""
status_stray["pets_index"] = "1"
status_stray["location"] = "Nord"
status_stray["location_from"] = "Nord,Sued,Ost,West"

interface_stray = {}
interface_stray["module"] = "Streunen"
interface_stray["active"] = { input_type = "toggle", display_name = "Streunen" }
interface_stray["pets"] = { input_type = "list_list", display_name = "Haustiere" }
interface_stray["location"] = { input_type = "dropdown", display_name = "Richtung" }

location_translation = {}
location_translation["Nord"] = 2
location_translation["Sued"] = 3
location_translation["Ost"] = 4
location_translation["West"] = 5

function split(str)
  local out = {}
  local count = 1
  for i in string.gmatch(str, "%S+") do
    out[count] = i
    count = count + 1
  end
  return out
end

function find_pets(page)
  util.log("getting pets")
  local pets = {}
  local status = ""

  -- find all pet boxes
  local selector = "//div[starts-with(@id, 'pet') and contains(@class, 'petshell')]"
  local pet_boxes = util.get_all_by_xpath(page, selector)

  -- extract mission id and mission name for each mission box
  for i, pet_box in ipairs(pet_boxes) do
    local pet_id = tonumber(string.sub(util.get_by_xpath(pet_box, "/div/@id"), 4))
    local pet_name = util.get_by_xpath(pet_box, "//div[contains(@class, 'petname')]")
    pet_name = split(pet_name)[1] .. ' (Slot ' .. i .. ')'

    -- put it into pets table
    pets[pet_name] = pet_id

    -- append pet to status
    if status == '' then
      status = pet_name
    else
      status = status .. "," .. pet_name
    end
  end

  -- update status
  util.set_status("pets_from", status)

  return pets
end

function get_form(page, callback)
  local tablink = util.get_by_xpath(page, '//a[contains(@href, "/pet/tab/action/")]/@href')
  if tablink ~= '/pet/tab/action/' then
    util.log_error('tablink: ' .. tablink)
    return callback('tablink not found', nil)
  else
    local timestamp = os.time() * 1000 + math.random(0, 999)
    return http.get_path('/pet/tab/action/?' .. timestamp, function(page)
      return callback(nil, page)
    end)
  end
end

function get_stray_time(page)
	local link = util.get_by_xpath(page, "//span[@id = 'pet_roam_time']/script")
  local stray_time = tonumber(util.get_by_regex(link, "counter\\((-?[0-9]*)"))
  if stray_time == nil then
    util.log("pet not roaming")
    return 0
  end
  if stray_time >= 0 then
    util.log("pet roaming " .. stray_time)
  end
	return stray_time
end

function get_location(page)
  local slots = util.get_all_by_xpath(page, "//select[@name = 'area_id']/option")
  for i, location in ipairs(slots) do
    if i == location_translation[status_stray["location"]] then
      return util.get_by_regex(location, 'value="([^"]*)')
    end
  end
  return ""
end

function acknowledge(pet_page, ajax_page, callback)
  util.log("acknowledge check");
  local button = util.get_by_xpath(ajax_page, "//input[@id = 'get_reward_button']/@id");
  if button == "" then
    return callback(nil, false)
  end

  if string.find(pet_page, '/pet/get_roam_reward/', 0, true) then
    util.log("acknowledging")
    return http.get_path("/pet/get_roam_reward/", function(page)
      util.log("acknowledge done")
      return callback(nil, true)
    end)
  end

  return callback("acknowledge url problem", nil)
end

function energy_check(ajax_page, pet_id)
  local xpath = "//div[@id = 's_pet" .. pet_id .. "']//div[@class = 'pet_hp_mini_data']/text()"
  local energy = util.get_by_xpath(ajax_page, xpath)
  util.log("pet energy: " .. energy)
  return tonumber(energy)
end

function run_stray()
  return http.get_path("/pet/", function(pet_page)
    -- login
    return login_page(pet_page, function(err, page)
      if err then
        util.log_error("not logged in")
        return on_finish(30, 180)
      end
      -- read list of pets
      local pet_map = find_pets(pet_page)

      -- check activity
	    local stray_time = get_stray_time(pet_page)
      if stray_time > 0 then
	      util.log("already roaming " .. stray_time)
        return on_finish(stray_time, stray_time + 180)
      end

      -- get pets from status
      if status_stray["pets"] == "" then
        -- stop module
        util.log("no pets set")
        return on_finish(-1)
      end
      local pets = explode(",", status_stray["pets"])

      -- start from begin if index is out of rage
      local pet_index = tonumber(status_stray["pets_index"])
      if pet_index > #pets then
        util.log("restarting from begin")
        pet_index = 1
        util.set_status("pets_index", "1")
      end

      -- start training
      local next_pet = pets[pet_index]
      util.log("next pet: " .. next_pet)
      return get_form(pet_page, function(err, ajax_page)
        if err then
          util.log_error(err)
          return on_finish(10, 20)
        else
          return acknowledge(pet_page, ajax_page, function(ack_err, ack_done)
            if ack_err then
              util.log_error(ack_err)
              return on_finish(60, 180)
            end

            if ack_done then
              return on_finish(10, 20)
            end

            if energy_check(ajax_page, pet_map[next_pet]) < 10 then
              util.log("energy low")
              util.set_status("pets_index", tostring(pet_index + 1))
              return on_finish(30, 180)
            end

            local location = get_location(ajax_page)
            if location == "" then
              util.log("location not found")
              return on_finish(60, 180)
            end

            local parameters = {
              area_id = location,
              route_length = "10",
              pet_id = tostring(pet_map[next_pet])
            }

            util.log("sending pet to roam: " .. next_pet)
            return http.submit_form(ajax_page, "//form[@action = '/pet/pet_action/']", parameters, function(page)
              -- next time -> next pet
              util.set_status("pets_index", tostring(pet_index + 1))
              local stray_time = get_stray_time(page)
              return on_finish(stray_time, stray_time + 180)
            end)
          end)
        end
      end)
    end)
  end)
end
