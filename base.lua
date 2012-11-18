function login(username, password)
  m_log("getting start page")
  local response = m_request_path("/")
  if string.find(response, 'action="/logout/"', 0, true) then
    m_log("already logged in")
    return true
  end

  local param = {}
  param["username"] = username
  param["password"] = password
  m_log("logging in")
  response = m_submit_form(response, "//input[@name = 'submitForm']", param)

  if string.find(response, 'action="/logout/"', 0, true) then
    m_log("logged in")
    return true
  else
    m_log_error("not logged in")
    return false
  end
end

function get_pennerbar(entry)
  m_log("getting pennerbar")
  local pennerbar = m_request_path("/pennerbar.xml")
  local value = m_get_by_xpath(pennerbar, "//" .. entry .. "/@value")
  return value
end

function get_pennerbar_page(pennerbar, entry)
  local value = m_get_by_xpath(pennerbar, "//" .. entry .. "/@value")
  return value
end

function get_activity_time(page)
  local timer = m_get_by_xpath(page, "//div[@id = 'active_process2']")
  if timer ~= "" then
    return m_get_by_regex(timer, "counter\\((-?[0-9]*)\\)")
  else
    return "0"
  end
end

function concat_keys(t, delimiter)
  local s = ""
  local i = 0
  for k, v in pairs(t) do
    if i == 0 then
      s = v
      i = 1
    else
      s = s .. "," .. k
    end
  end
  return s
end

function explode(d,p)
  local t, ll
  t={}
  ll=0
  if(#p == 1) then return {p} end
    while true do
      l=string.find(p,d,ll,true) -- find the next d in the string
      if l~=nil then -- if "not not" found then..
        table.insert(t, string.sub(p,ll,l-1)) -- Save it in our array.
        ll=l+1 -- save just after where we found it for searching next time.
      else
        table.insert(t, string.sub(p,ll)) -- Save what's left in our array.
        break -- Break at end, as it should be, according to the lua manual.
      end
    end
  return t
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end
