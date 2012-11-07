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
