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
interface_stray["location"] = { input_type = "list_list", display_name = "Richtung" }

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

  return missions
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
  local stray_time = tonumber(util.get_by_regex(link, "counter\\((-?[0-9]*)\\)"))
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
  local slots = util.get_all_by_xpath(page, "//select[@name = 'area_id']/option/node()")
  for i, location in ipairs(slots) do
    if i == location_translation[status_stray["location"]] then
      return split(location)[1]
    end
  end
  return ""
end

function run_stray()
  return http.get_path("/pet/", function(page)
    -- read list of pets
    find_pets(page)

    -- check activity
	  local stray_time = get_stray_time(page)
    if stray_time > 0 then
	    util.log("already roaming " .. stray_time)
      return on_finish(stray_time, stray_time + 180)
    end

    -- get pets from status
    local pets = explode(",", status_stray["pets"])
    if pets[1] == "" then
      -- stop module
      util.log("no pets set")
      return on_finish(-1)
    end

    -- start from begin if index is out of rage
    local pet_index = tonumber(status_stray["pets_index"])
    if pet_index >= #pets then
      util.log("restarting from begin")
      training_index = 1
      util.set_status("pet_index", "1")
    end

    -- start training
    local next_pet = pets[pet_index]
    util.log("next pet: " .. next_pet)
    return get_form(page, function(err, page)
      if err then
        util.log_error(err)
        return on_finish(10, 20)
      else
        local location = get_location(page)
        if location == "" then
          util.log("location not found")
          return on_finish(60, 180)
        end

        local parameters = {
          area_id = "2,Robust,1",
          route_length = 10,
          pet_id = pets[next_pet]
        }

        return http.submit_form(page, "//form[@action = '/pet/pet_action/']", parameters, function(page)
          -- next time -> next pet
          util.set_status("pet_index", tostring(pet_index + 1))
          return on_finish(10, 20)
        end)
      end
    end)
  end)
end
