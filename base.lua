function login(username, password)
  util.log("getting start page")
  return http.get_path("/", function(page)
    if string.find(page, 'action="/logout/"', 0, true) then
      util.log("already logged in")
      return on_finish(true)
    end

    util.log("logging in")
    local param = {}
    param["username"] = username
    param["password"] = password
    return http.submit_form(page, "//input[@name = 'submitForm']", param, function(page)
      if string.find(page, 'action="/logout/', 0, true) then
        util.log("logged in")
        return on_finish(true)
      else
        util.log_error("not logged in")
        return on_finish(false)
      end
    end)
  end)
end

function chain(funs, err, param, callback)
  if #funs == 0 then
    return callback(err, param)
  else
    local call_me = funs[1]
    return call_me(err, param, function(err, param)
      table.remove(funs, 1)
      return chain(funs, err, param, callback)
    end)
  end
end

function get_pennerbar(entry, callback)
  util.log("getting pennerbar")
  return http.get_path("/pennerbar.xml", function(page)
    return callback(false, get_pennerbar_info(page, entry))
  end)
end

function get_pennerbar_info(pennerbar, entry)
  return util.get_by_xpath(pennerbar, "//" .. entry .. "/@value")
end

function get_activity_time(page)
  local timer = util.get_by_xpath(page, "//div[@id = 'active_process2']")
  if timer ~= "" then
    return util.get_by_regex(timer, "counter\\((-?[0-9]*)\\)")
  else
    return "0"
  end
end

function clear_cart(page, callback)
  if (util.get_by_xpath(page, "//input[@name = 'bottlecollect_pending']/@value") == "True") then
    util.log("clearing cart")
    return http.submit_form(page, "//form[contains(@action, 'bottle')]", function(page)
      return callback(false, page)
    end)
  else
    return callback(false, page)
  end
end

function explode(d,p)
  local t, ll, l
  t={}
  ll=0
  if(#p == 1) then return {p} end
    while true do
      l=string.find(p,d,ll,true) -- find the next d in the string
      if l~=nil then -- if "not not" found then..
        local element = string.sub(p, ll, l-1)
        if element ~= "" then
          table.insert(t, element) -- Save it in our array.
        end
        ll=l+1 -- save just after where we found it for searching next time.
      else
        local element = string.sub(p, ll)
        if element ~= "" then
          table.insert(t, element) -- Save what's left in our array.
        end
        break -- Break at end, as it should be, according to the lua manual.
      end
    end
  return t
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end
