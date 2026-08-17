import time
import json
import threading
import socket
from pyopenttdadmin import Admin, AdminUpdateType, openttdpacket as p, Auth

print("[Bot     ] Starting bot...")


class AdminGameScriptPacket(p.Packet):
    # Tipul pachetului pentru direcția Bot -> GameScript
    # Dacă PacketType.ADMIN_GAMESCRIPT nu există, poți folosi direct valoarea 12 (ID-ul oficial din protocol)
    packet_type = getattr(p.PacketType, "ADMIN_GAMESCRIPT", 12) 
    
    def __init__(self, json_string: str):
        self.json = json_string
        
    def __repr__(self) -> str:
        return f"AdminGameScriptPacket({self.json})"
        
    def to_bytes(self) -> bytes:
        # Codificăm string-ul în UTF-8 și adăugăm terminatorul null (\x00) specific OpenTTD
        return self.json.encode('utf-8') + b'\x00'

def send_to_gamescript(self, data):
    """
    Transformă datele în JSON și le trimite către GameScript,
    declanșând pe server evenimentul GSEvent.ET_ADMIN_PORT.
    """
    # Dacă primește un dicționar sau o listă, le transformăm în string JSON
    if isinstance(data, (dict, list)):
        json_string = json.dumps(data)
    else:
        json_string = str(data)
        
    # În protocolul OpenTTD, pachetul trimis de client către GameScript
    # se instanțiază, de regulă, cu clasa ClientGameScript
    packet = AdminGameScriptPacket(json_string)
    
    # Trimitem pachetul folosind metoda internă a clasei Admin
    # (Dacă librăria folosește altă denumire, poți încerca self.send(packet))
    self._send(packet)
Admin.send_gamescript = send_to_gamescript



password = "parola_sv"
ip_address = "openttd-server"
port_number = 3977
timeout_total = 60
    
auth = Auth(name="MUNTY-Bot", version="15.0", password=password)
bot = None
start_time = time.time()
while True:
    if time.time() - start_time > timeout_total:
        print("[Bot     ] Connection timed out")
        exit(1)
        
    try:
        print(f"[Bot     ] Connecting to OpenTTD server at ({ip_address}:{port_number})")
        bot = Admin(ip=ip_address, port=port_number, auth=auth)

        bot.subscribe(AdminUpdateType.CLIENT_INFO)
        bot.subscribe(AdminUpdateType.CHAT)
        bot.subscribe(AdminUpdateType.CONSOLE)
        bot.subscribe(AdminUpdateType.CMD_LOGGING)
        bot.subscribe(AdminUpdateType.GAMESCRIPT)


        @bot.add_handler(p.ChatPacket)
        def chat_packet(bot: Admin, packet: p.ChatPacket):
            print(f'[Chat    ] {packet.id}: {packet.message} ({packet.action})')

        @bot.add_handler(p.AdminJoinPacket)
        def admin_join(bot: Admin, packet: p.AdminJoinPacket):
            print(f"[Admin   ] Admin {packet.name} connnected with version {packet.version}.")

        @bot.add_handler(p.WelcomePacket)
        def welcome(bot: Admin, packet: p.WelcomePacket):
            print(f"[Admin   ] Welcome from {packet.server_name}!")

        @bot.add_handler(p.ErrorPacket)
        def error(bot: Admin, packet: p.ErrorPacket):
            print(f"[Error   ] {packet.message}")

        @bot.add_handler(p.GameScriptPacket)
        def gamescript_packet(bot: Admin, packet: p.GameScriptPacket):
            print(f"[Script  ] Update ({len(packet.json)} bytes): {packet.json}")
            data = json.loads(packet.json[:-1])
            if data.get("type") == "restart_map":
                bot.send_rcon("restart")
            if data.get("type") == "send_global":
                bot.send_global(data.get("message", ""))
            if data.get("type") == "send_private":
                player_id = data.get("player_id")
                message = data.get("message", "")
                if player_id is not None:
                    bot.send_private(message, player_id)

        @bot.add_handler(p.ConsolePacket)
        def console_packet(bot: Admin, packet: p.ConsolePacket):
            print(f"[Console ] {packet.origin}: {packet.message}")

        @bot.add_handler(p.ClientJoinPacket)
        def client_join(bot: Admin, packet: p.ClientJoinPacket):
            print(f"[Client  ] Client {packet.id} joined the game.")
            bot.send_gamescript({
                "type": "player_joined",
                "player_id": packet.id
            })

        bot.run()
        print("[Bot     ] End")
        
    except Exception as e:
        print(f"[Bot     ] Connection timed out. {e}")
        
    print("[Bot     ] Waiting 5 seconds")
    time.sleep(5)

print("[Bot     ] Connected")

