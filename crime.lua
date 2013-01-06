dofile('packages/pg/base.lua')

status_crime = {}
status_crime["crime"] = ""
status_crime["crime_from"] = ""

interface_crime = {}
interface_crime["module"] = "Verbrechen"
interface_crime["active"] = { input_type = "toggle", display_name = "Verbrechen begehen" }
interface_crime["crime"] = { input_type = "dropdown", display_name = "Verbrechen" }

function trim(s)
  return s:match "^%s*(.-)%s*$"
end

function commit_crime(id, callback)
  return http.get_path('/activities/crime/?start_crime=' .. id, function(page)
    return callback(false, page)
  end)
end

function get_crimes(page)
  util.log("reading crimes")

  -- get crime names
  local crime_array = {}
  local crimes = util.get_all_by_xpath(page, "//span[@class = 'crime_headline']/child::text()")
  for k,v in pairs(crimes) do
    table.insert(crime_array, string.sub(v, 0, string.len(v)))
  end

  -- get crime ids
  local crime_id_array = {}
  local crime_ids = util.get_all_by_regex(page, "start_crime\\((\\d*)\\)")
  for i, match_table in ipairs(crime_ids) do
    table.insert(crime_id_array, match_table[1])
  end

  -- merge names with ids to a mapping from name to id
  -- iterate over ids because these are crimes that can be commited
  local mapping = {}
  for i = 1, #crime_id_array do
    mapping[trim(crime_array[i])] = crime_id_array[i]
  end

  -- update status
  local crime_from = "-"
  for k,v in pairs(mapping) do
    crime_from = crime_from .. "," .. k
  end
  util.set_status("crime_from", crime_from)

  return mapping
end

function run_crime()
  -- get crime page
  util.log("getting crime page")
  return http.get_path("/activities/crime/", function(page)
    -- read crimes
    local crimes = get_crimes(page)

    -- check for activity
    local activity = tonumber(get_activity_time(page))
    if activity > 0 then
      util.log("already active for " .. activity .. "s")
      return on_finish(activity + 60, activity + 120)
    end

    -- check if crime is set
    if status_crime["crime"] == "" or status_crime["crime"] == "-" then
      util.log_error("no crime set - exiting")
      return on_finish(-1)
    end

    -- start selected crime
    util.log("starting " .. status_crime["crime"])
    if not crimes[status_crime["crime"]] then
      util.log_error("\"" .. status_crime["crime"] .. "\" not found")
      for k, v in pairs(crimes) do
        util.log_error("\"" .. k .. "\"")
      end
      return on_finish(-1)
    end

    commit_crime(crimes[status_crime["crime"]], function(err, page)
      -- read activity time
      activity = tonumber(get_activity_time(page))
      util.log("blocked for " .. activity)
      return on_finish(activity, activity + 180)
    end)
  end)
end
