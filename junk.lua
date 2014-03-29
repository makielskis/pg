interface_junk = {}
interface_junk["module"] = "Plunder"
interface_junk["active"] = { input_type = "toggle", display_name = "Plunder aktualisiern" }

function run_junk()
  return http.get_path("/stock/plunder/", function(looting_page)
    return get_loot(looting_page, function(err, loot_map)
        return on_finish(86400, 86400)
    end)
  end)
end
