import("Library.SCPLib", "SCPLib", 45);
require("scp.nut");

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

	last_announcement_tick = 0;
	restart_at_tick = null;
	restart_annoucement_number = null;
	restart_annoucement_intervals = [30, 20, 10, 5, 3, 2, 1];
	announce_interval = GSController.GetSetting("announce_interval"); // seconds

	ms_per_tick = 27;

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
		AnnounceRankings();
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
			break;
		default:
			break;
	}
}

function CompanyValue::DeclareWinner(company_id) {
	this.goal_reached = true;
	this.goal_company.goal_value = GSCompany.GetQuarterlyCompanyValue(company_id, GSCompany.CURRENT_QUARTER);
	this.goal_company.c_id = company_id;
	// this.goal_company.days_taken = GSController.GetCurrentDay();

	local seconds_until_restart = 30;
	this.restart_at_tick = GSController.GetTick() + seconds_until_restart * (1000 / this.ms_per_tick);
	this.restart_annoucement_number = 0;

    local company_name = GSCompany.GetName(company_id);
    local msg = company_name + " has reached the goal and won the game!";
	GSAdmin.Send({type = "send_global", message = msg});
	GSNews.Create(GSNews.NT_GENERAL, msg, GSCompany.COMPANY_INVALID);
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
				DeclareWinner(rank_list[0].id);
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
