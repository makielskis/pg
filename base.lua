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

function trim(s)
  return s:match "^%s*(.-)%s*$"
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

-- Looting functions --

function get_loot(looting_page, callback)
  local xpath = "//ul[@id='plundertab']/li/a[contains(@href, 'c=')]"
  local loot_paths = util.get_all_by_xpath(looting_page, xpath)

  local index = 3 -- Reloaded
  if #loot_paths <= 3 then
    index = 1 -- Legacy
  end

  local loot_path = util.get_by_xpath(loot_paths[index], "a/@href")
  if loot_path == "" then
    return callback("could not get loot list")
  end

  local timestamp = os.time() * 1000 + math.random(0, 999)
  loot_path = loot_path .. '&' .. timestamp

  util.log("getting loot list")
  return http.get_path(loot_path, function(ajax_page)
    local map = {}
    local loot = util.get_all_by_xpath(ajax_page, "//a[contains(@href, 'change_stuff')]")
    for i, v in ipairs(loot) do
      id = util.get_by_regex(v, [[change_stuff\('([0-9]+)']])
      name = util.get_by_xpath(v, "/a/strong/text()")
      map[trim(name)] = tonumber(id)
    end

    local loot_list = "-"
    for k,v in pairs(map) do
      if trim(k) ~= "" then
        loot_list = loot_list .. "," .. k
      end
    end
    util.set_global("loot_from", loot_list)

    return callback(false, map)
  end)
end

function is_equipped(page, loot)
  local xpath = "//a[contains(@href, 'unarmPlunder')]/strong/text()"
  local equipped = util.get_all_by_xpath(page, xpath)
  for i, v in ipairs(equipped) do
    local eqi = trim(v)
    util.log_debug("equipped: " .. eqi)
    if eqi == trim(loot) then
      return true
    end
  end
  return false
end

function isset(value)
  return value ~= "" and value ~= "-"
end

function equip(loot, callback)
  http.get_path("/stock/plunder/", function(looting_page)
    return get_loot(looting_page, function(err, loot_map)
      if err then
        return callback(err)
      end

      if not isset(loot) then
        return callback(false)
      end

      if is_equipped(looting_page, loot) then
        util.log(loot .. " is already equipped")
        return callback(false)
      end

      local loot_id = loot_map[loot]
      if loot_id == nil then
        return callback("loot id of " .. loot .. " not known")
      end

      util.log("equipping " .. loot)
      local params = { f_plunder = tostring(loot_id), from_f = "0" }
      return http.submit_form(looting_page, "//form[@id = 'form_skip']", params, function(page)
        local success = is_equipped(page, loot)
        if not success then
          return callback("failed to equip " .. loot)
        else
          return callback(false)
        end
      end)
    end)
  end)
end