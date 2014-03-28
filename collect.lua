status_collect = {}
status_collect["start_loot"] = ""
status_collect["end_loot"] = "Dose \"Dr. Penner\""

interface_collect = {}
interface_collect["module"] = "Flaschen sammeln"
interface_collect["active"] = { input_type = "toggle", display_name = "Sammeln gehen" }
interface_collect["start_loot"] = { input_type = "dropdown", display_name = "Start-Plunder" }
interface_collect["end_loot"] = { input_type = "dropdown", display_name = "Einkaufswagen-Plunder" }

function get_collect_time(page)
  local link = util.get_by_xpath(page, "//a[@href = '/activities/' and @class= 'ttip']")
  local collect_time = tonumber(util.get_by_regex(link, "counter\\((-?[0-9]*)"))
  if collect_time >= 0 then
    util.log("collecting " .. collect_time)
  end
	return collect_time
end

function run_collect()
	util.log("getting collect page")
	return http.get_path("/activities/", function(page)
	  -- check for activity
	  local collect_time = get_collect_time(page)
	  return get_pennerbar("kampftimer", function(err, fight_time)
	    if collect_time > 0 then
		    util.log("already collecting " .. collect_time)
	      return on_finish(collect_time, collect_time + 180)
	    elseif tonumber(fight_time) > 0 then
		    util.log("fighting" .. fight_time)
	      return on_finish(fight_time, fight_time + 180)
	    else
	      -- equip pre clear cart junk
        return equip(status_collect["end_loot"], function(err)
          -- empty cart
          return clear_cart(page, function(err, page)
		        -- check preset collect time
		        return http.get_path("/activities/", function(page)
		          local selected = util.get_by_xpath(page, "//select[@name = 'time']/option[@selected = 'selected']/@value")
		          local parameters = {}
		          parameters["sammeln"] = selected
              -- equip pre start collection junk
              return equip(status_collect["start_loot"], function(err)
		            -- start collection
		            util.log("starting to collect - collect time " .. selected)
		            return http.submit_form(page, "//form[contains(@name, 'starten')]", parameters, "/activities/bottle/", function(page)
		              -- get collect time and sleep
		              collect_time = get_collect_time(page)
	                return on_finish(collect_time, collect_time + 180)
                end)
              end)
            end)
          end)
        end)
	    end
    end)
  end)
end
