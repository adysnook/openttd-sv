class CompanyValue extends GSController
{
	companies = null;
	goal_reached = false;
	goal_company = {
		c_id = null,
		goal_value = null,
		days_taken = null
	};
	goal_value = GSController.GetSetting("goal_value") * 1000;
	max_year = GSController.GetSetting("max_year");
	
	no_companies_since_tick = GSController.GetTick();

	restart_inactivity_days = 365;
	last_announcement_tick = 0;
	restart_at_tick = null;
	restart_annoucement_number = null;
	restart_annoucement_intervals = [30, 20, 10, 5, 3, 2, 1];
	restart_seconds_after_goal_reached = 30;
	announce_interval = GSController.GetSetting("announce_interval"); // seconds

	ms_per_tick = 27;
	ticks_per_day = 74;

	function Start();
}

function CompanyValue::Start()
{
	while (this.Sleep(1)) {
		while (GSEventController.IsEventWaiting()) {
			local e = GSEventController.GetNextEvent();
			if (e.GetEventType() == GSEvent.ET_ADMIN_PORT) {
				local adminEvent = GSEventAdminPort.Convert(e);
				local adminCommand = adminEvent.GetObject();

				this.OnAdminCommand(adminCommand);
			}
		}
		CheckForInactivity();
		AnnounceRankings();
	}
}

function CompanyValue::CheckForInactivity(){
	local current_tick = GSController.GetTick();
	if (GSDate.GetYear(GSDate.GetCurrentDate()) > this.max_year) {
		GSGame.Pause();
		GSAdmin.Send({type = "send_global", message = "Max year " + this.max_year.tostring() + " has been reached. Restarting the map!"});
		GSAdmin.Send({type = "restart_map"});
		return;
	}
	
	if (getNumCompanies() == 0) {
		if (this.no_companies_since_tick == null) {
			this.no_companies_since_tick = current_tick;
		} else {
			local ticks_since_no_companies = current_tick - this.no_companies_since_tick;
			local days_since_no_companies = ticks_since_no_companies / this.ticks_per_day;
			if (days_since_no_companies >= this.restart_inactivity_days) {
				GSGame.Pause();
				GSAdmin.Send({type = "send_global", message = "No companies have been created for " + this.restart_inactivity_days.tostring() + " days. Restarting the map!"});
				GSAdmin.Send({type = "restart_map"});
			}
		}
	} else {
		this.no_companies_since_tick = null;
	}
}


function CompanyValue::OnAdminCommand(adminCommand) {
	if(typeof adminCommand != "table") return;
	if(!("type" in adminCommand)) return;
	local type = adminCommand.type;

	switch (type) {
		case "player_joined":
			local player_id = adminCommand.player_id;
			if (GSClient.ResolveClientID(player_id) == GSClient.CLIENT_INVALID) break;
			local player_name = GSClient.GetName(player_id);
			GSAdmin.Send({type = "send_private", player_id = player_id, message = "Welcome " + player_name + " to the server! The goal is to reach a company value of " + this.FormatMoney(this.goal_value, "EUR") + "!"});
			GSAdmin.Send({type = "send_private", player_id = player_id, message = "Warning! Base costs are modified!"});
			break;
		default:
			break;
	}
}

function CompanyValue::DeclareWinner(company_id, reached_goal) {
	this.goal_reached = true;
	this.goal_company.goal_value = GSCompany.GetQuarterlyCompanyValue(company_id, GSCompany.CURRENT_QUARTER);
	this.goal_company.c_id = company_id;
	// this.goal_company.days_taken = GSController.GetTick() / this.ticks_per_day - company_creation_tick / this.ticks_per_day;

	this.restart_at_tick = GSController.GetTick() + this.restart_seconds_after_goal_reached * (1000 / this.ms_per_tick);
	this.restart_annoucement_number = 0;

    local company_name = GSCompany.GetName(company_id);
	local msg = "";
	if (reached_goal) {
		msg = company_name + " has reached the goal of " + this.FormatMoney(this.goal_value, "EUR") + " with " + this.FormatMoney(this.goal_company.goal_value, "EUR") + "!";
	} else {
		msg = "Max year " + this.max_year.tostring() + " has been reached. Winner is " + company_name + " with " + this.FormatMoney(this.goal_company.goal_value, "EUR") + "!";
	}
	GSAdmin.Send({type = "send_global", message = msg});
	GSNews.Create(GSNews.NT_GENERAL, msg, GSCompany.COMPANY_INVALID);

	msg = "The map will restart in " + this.restart_seconds_after_goal_reached.tostring() + " seconds!";
	GSAdmin.Send({type = "send_global", message = msg});
}


function CompanyValue::AnnounceRankings() {
	local tick_curent = GSController.GetTick();

	if(this.goal_reached == true) 
	{
		if(this.restart_at_tick - tick_curent <= 0) {
			GSAdmin.Send({type = "restart_map"});
			return;
		}

		local seconds_remaining = (this.restart_at_tick - tick_curent) / (1000 / this.ms_per_tick);

		if(this.restart_annoucement_number < this.restart_annoucement_intervals.len() && seconds_remaining <= this.restart_annoucement_intervals[this.restart_annoucement_number]) {
			GSAdmin.Send({type = "send_global", message = "The map will restart in " + seconds_remaining.tostring() + " seconds!"});
			this.restart_annoucement_number++;
		}
		
	}else{
		local rank_list = [];
		for (local c_id = GSCompany.COMPANY_FIRST; c_id < GSCompany.COMPANY_LAST; c_id++) {
			if (GSCompany.ResolveCompanyID(c_id) != GSCompany.COMPANY_INVALID) {
				local c_value = GSCompany.GetQuarterlyCompanyValue(c_id, GSCompany.CURRENT_QUARTER);
				local name = GSCompany.GetName(c_id);
				rank_list.push({ id = c_id, name = name, value = c_value });
			}
		}

		if (rank_list.len() > 0) {
			rank_list.sort(function(a, b) {
				if (a.value > b.value) return -1;
				if (a.value < b.value) return 1;
				return 0;
			});

			if(rank_list[0].value > this.goal_value) {
				DeclareWinner(rank_list[0].id, true);
				return;
			}

			if (GSDate.GetYear(GSDate.GetCurrentDate()) > this.max_year) {
				DeclareWinner(rank_list[0].id, false);
				return;
			}
		}

		local interval_sleep = this.announce_interval * this.ms_per_tick;
		if(tick_curent - this.last_announcement_tick < interval_sleep) 
		{
			return;
		}
		this.last_announcement_tick = tick_curent;
		
		
		GSAdmin.Send({type = "send_global", message = "--- First company to reach the goal of " + this.FormatMoney(this.goal_value, "EUR") + " wins the game! ---"});
		for (local i = 0; i < rank_list.len(); i++) {
			GSAdmin.Send({type = "send_global", message = "- (" + (rank_list[i].value * 100 / this.goal_value).tostring() + "%) Rank #" + (i + 1) + " is " + rank_list[i].name + " with " + this.FormatMoney(rank_list[i].value, "EUR")});
		}
	}	
}

function CompanyValue::FormatMoney(value, currency) {
	if (currency == "EUR") value = value * 2;

	local msg = " " + currency;

	while (value >= 1000) {
		msg = "," + padLeft(value % 1000, 3, "0") + msg;
		value /= 1000;
	}
	msg = value.tostring() + msg;

	return msg;
}

function padLeft(str, targetLength, padChar = " ") {
    str = str.tostring(); 
    
    while (str.len() < targetLength) {
        str = padChar + str;
    }
    return str;
}

function getNumCompanies() {
	local count = 0;
	for (local c_id = GSCompany.COMPANY_FIRST; c_id < GSCompany.COMPANY_LAST; c_id++) {
		if (GSCompany.ResolveCompanyID(c_id) != GSCompany.COMPANY_INVALID) {
			count++;
		}
	}
	return count;
}