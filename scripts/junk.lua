status_junk = {}
status_junk["defaultloot"] = "^defaultloot"
status_junk["defaultloot_from"] = "$loot_from"

interface_junk = {}
interface_junk["module"] = "Plunder"
interface_junk["active"] = { input_type = "toggle", display_name = "Plunder aktualisieren" }
interface_junk["defaultloot"] = { input_type = "dropdown", display_name = "Standart Plunder" }

function run_junk()
  get_loot_page(function(err, looting_page)
    if err then
      util.log_err(err)
      return callback(err, nil)
    end
    return get_loot(looting_page, function(err, loot_map)
      return on_finish(86400, 86400)
    end)
  end)
end
