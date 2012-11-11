dofile('packages/pg/base.lua')

status_crime = {}
status_crime["crime"] = ""
status_crime["crime_from"] = ""

interface_crime = {}
interface_crime["module"] = "Verbrechen"
interface_crime["active"] = { input_type = "toggle", display_name = "Verbrechen begehen" }
interface_crime["crime"] = { input_type = "dropdown", display_name = "Verbrechen" }

function commit_crime(id)
  return m_request_path('/activities/crime/?start_crime=' .. id)
end

function get_crimes(page)
  m_log("reading crimes")

  -- get crime names
  local crime_array = {}
  local crimes = m_get_all_by_xpath(page, "//span[@class = 'crime_headline']/child::text()")
  for k,v in pairs(crimes) do
    table.insert(crime_array, string.sub(v, 0, string.len(v) - 1))
  end

  -- get crime ids
  local crime_id_array = {}
  local crime_ids = m_get_all_by_regex(page, "start_crime\\((\\d*)\\)")
  for i, match_table in ipairs(crime_ids) do
    table.insert(crime_id_array, match_table[1])
  end

  -- merge names with ids to a mapping from name to id
  -- iterate over ids because these are crimes that can be commited
  local mapping = {}
  for i = 1, #crime_id_array do
    mapping[crime_array[i]] = crime_id_array[i]
  end

  -- update status
  local crime_from = "-"
  for k,v in pairs(mapping) do
    crime_from = crime_from .. "," .. k
  end
  crime_from = string.sub(crime_from, 0, string.len(crime_from) - 1)
  m_set_status("crime_from", crime_from)

  return mapping
end

function get_activity_time(page)
  local timer = m_get_by_xpath(page, "//div[@id = 'active_process2']")
  if timer ~= "" then
    return m_get_by_regex(timer, "counter\\((-?[0-9]*)\\)")
  else
    return "0"
  end
end

function run_crime()
  -- get crime page
  m_log("getting crime page")
  local page = m_request_path("/activities/crime/")

  -- read crimes
  local crimes = get_crimes(page)

  -- check for activity
  local activity = tonumber(get_activity_time(page))
  if activity > 0 then
    m_log("already active for " .. activity .. "s")
    return activity + 60, activity + 120
  end

  -- check if crime is set
  if status_crime["crime"] == "" or status_crime["crime"] == "-" then
    m_log_error("no crime set - exiting")
    return
  end

  -- start selected crime
  m_log("starting " .. status_crime["crime"])
  if not crimes[status_crime["crime"]] then
    m_log_error(status_crime["crime"] .. " not found")
    return
  end
  page = commit_crime(crimes[status_crime["crime"]])

  -- read activity time
  activity = tonumber(get_activity_time(page))
  m_log("blocked for " .. activity)

  return activity, activity + 180
end
