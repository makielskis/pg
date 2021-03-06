function login()
  util.log("getting start page")
  return http.get_path("/", function(page)
    return login_page(page, function(err)
      return on_finish(not err)
    end)
  end)
end

function login_page(page, callback)
  if string.find(page, 'action="/logout/"', 0, true) then
    util.log("already logged in")
    return callback(false, page)
  end

  util.log("logging in")
  local param = {}
  param["username"] = util.username()
  param["password"] = util.password()
  return http.submit_form(page, "//input[@name = 'submitForm']", param, function(page)
    if string.find(page, 'action="/logout/', 0, true) then
      util.log("logged in")
      return callback(false, page)
    else
      util.log_error("not logged in")
      return callback(true, page)
    end
  end)
end

function chain(funs, err, param, callback)
  if #funs == 0 or err ~= false then
    return callback(err, param)
  else
    local call_me = funs[1]
    return call_me(param, function(err, param)
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
    util.set_shared("loot_from", loot_list)

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
  return value ~= "" and value ~= "-" and string.sub(value, 1, 1) ~= "$" and string.sub(value, 1, 1) ~= "^"
end

function lock_loot()
  local new_loot_locked_until = os.time() + 300
  util.set_shared("loot_locked_until", tostring(new_loot_locked_until))
  util.set_shared("loot_locked_by", __BOT_MODULE)
  util.log_debug("locked loot util " .. new_loot_locked_until)
end

function unlock_loot()
  util.log_debug("unlocking loot")
  local locker = util.get_shared("loot_locked_by")
  if locker == __BOT_MODULE or locker == "" then
    util.set_shared("loot_locked_until", "0")
    util.set_shared("loot_locked_by", "")
    util.log_debug("loot unlocked")
  else
    util.log_error("can't unlock loot: locked by '" .. locker .. "'")
  end
end

function try_lock_loot()
  util.log_debug("trying to lock loot")
  local locked_until = util.get_shared("loot_locked_until")
  local locker = util.get_shared("loot_locked_by")
  if locked_until == "" or os.time() > tonumber(locked_until) or locker == __BOT_MODULE then
    lock_loot()
    return true
  else
    util.log_error("lock failed: now=" .. os.time() .. ", lock=" .. locked_until .. ", locker=" .. locker)
    return false
  end
end

function get_loot_page(callback)
  return http.get_path("/stock/plunder/", function(looting_page)
    return login_page(looting_page, function(err, looting_page)
      if err then
        return callback("not logged in")
      end

      local loot_cats_switch_to_old = util.get_by_xpath(looting_page, "//a[contains(@href, 'rc=disable')]/@href")
      if loot_cats_switch_to_old ~= "" then
        util.log("requesting old layout: " .. loot_cats_switch_to_old)
        return http.get_path(loot_cats_switch_to_old, function(looting_page)
          return callback(false, looting_page)
        end)
      else
        return callback(false, looting_page)
      end
    end)
  end)
end

function equip(loot, no_lock, callback)
  util.log_debug("equip request for loot: " .. loot)

  if not isset(loot) then
    util.log("no loot selected")
    return callback(false, nil)
  end

  if no_lock then
    local locked = util.get_shared("loot_locked_by") ~= ""
    if locked then
      util.log_error("can't equip loot when locked")
      return callback(false, nil)
    end
  else
    local lock_success = try_lock_loot()
    if not lock_success then
      util.log_error("unable to lock loot")
      return callback(false, nil)
    end
  end

  get_loot_page(function(err, looting_page)
    if err then
      util.log_err(err)
      return callback(err, nil)
    end

    return get_loot(looting_page, function(err, loot_map)
      if err then
        unlock_loot()
        return callback(err, nil)
      end

      if is_equipped(looting_page, loot) then
        util.log(loot .. " is already equipped")
        return callback(false, nil)
      end

      local loot_id = loot_map[loot]
      if loot_id == nil then
        unlock_loot()
        return callback("loot id of " .. loot .. " not known", nil)
      end

      util.log("equipping " .. loot)
      local params = { f_plunder = tostring(loot_id), from_f = "0" }
      return http.submit_form(looting_page, "//form[@id = 'form_skip']", params, function(page)
        local success = is_equipped(page, loot)
        if not success then
          unlock_loot()
          return callback("failed to equip " .. loot, nil)
        else
          return callback(false, nil)
        end
      end)
    end)
  end)
end

function loot_done(callback)
  unlock_loot()
  util.log("equipping default loot")
  equip(util.get_shared("defaultloot"), true, callback)
end
