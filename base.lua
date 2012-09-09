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
