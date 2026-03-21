extends Control

@onready var btn_connect = $VBoxContainer/GridContainer/ConnectWalletBtn
@onready var btn_disconnect = $VBoxContainer/GridContainer/DisconnectBtn
@onready var btn_reconnect = $VBoxContainer/GridContainer/ReconnectBtn
@onready var btn_sign_msg = $VBoxContainer/GridContainer/SignMessageBtn
@onready var btn_sign_tx = $VBoxContainer/GridContainer/SignTransactionBtn
@onready var btn_sign_send = $VBoxContainer/GridContainer/SignAndSendBtn
@onready var btn_capabilities = $VBoxContainer/GridContainer/GetCapabilitiesBtn
@onready var btn_clear_cache = $VBoxContainer/GridContainer/ClearCacheBtn
@onready var lbl_status = $VBoxContainer/StatusPanel
@onready var txt_log = $VBoxContainer/ResultsLog

var mwa

func _ready():
	SolanaService.set_rpc_cluster(SolanaService.RpcCluster.DEVNET)
	
	_log("Checking for SolanaService.wallet.WalletAdapter...")
	await get_tree().process_frame
	if SolanaService.wallet == null or not SolanaService.wallet.has_node("WalletAdapter"):
		_log("Error: Could not find SolanaService WalletAdapter!")
		return
		
	var mwa_script = load("res://addons/SolanaSDK/Optional/SolanaService/Scripts/WalletAdapter/mobile_wallet_adapter.gd")
	mwa = mwa_script.new()
	mwa.name = "MobileWalletAdapter"
	add_child(mwa)
	
	mwa.wallet_adapter = SolanaService.wallet.get_node("WalletAdapter")
	
	# Connect signals
	mwa.authorized.connect(_on_authorized)
	mwa.authorization_failed.connect(_on_auth_failed)
	mwa.disconnected.connect(_on_disconnected)
	mwa.connected.connect(_on_connected)
	mwa.capabilities_ready.connect(_on_capabilities_ready)
	mwa.capabilities_failed.connect(_on_capabilities_failed)
	mwa.transactions_signed.connect(_on_txs_signed)
	mwa.messages_signed.connect(_on_msgs_signed)
	mwa.signing_failed.connect(_on_signing_failed)

	# Connect buttons
	btn_connect.pressed.connect(_on_btn_connect)
	btn_disconnect.pressed.connect(_on_btn_disconnect)
	btn_reconnect.pressed.connect(_on_btn_reconnect)
	btn_sign_msg.pressed.connect(_on_btn_sign_msg)
	btn_sign_tx.pressed.connect(_on_btn_sign_tx)
	btn_sign_send.pressed.connect(_on_btn_sign_send)
	btn_capabilities.pressed.connect(_on_btn_capabilities)
	btn_clear_cache.pressed.connect(_on_btn_clear_cache)
	
	_update_status()

func _update_status():
	var active_token = ""
	var address = ""
	if mwa.is_logged_in() and mwa.auth_cache != null:
		var cache = mwa.auth_cache.load_token()
		if cache.has("auth_token"):
			active_token = cache["auth_token"].substr(0, 10) + "..."
		if cache.has("account_address"):
			address = cache["account_address"].substr(0, 10) + "..."
			
	lbl_status.text = "Status: %s\nAddress: %s\nToken: %s" % [
		"Connected" if mwa.is_logged_in() else "Disconnected",
		address if address != "" else "None",
		active_token if active_token != "" else "None"
	]

func _set_busy(busy: bool, label: String = "") -> void:
	var buttons = [btn_connect, btn_disconnect, btn_reconnect, btn_sign_msg,
					btn_sign_tx, btn_sign_send, btn_capabilities, btn_clear_cache]
	for btn in buttons:
		btn.disabled = busy
	if busy:
		lbl_status.text = "Status: Waiting for wallet...\n" + (label if label != "" else "Please respond in your wallet app.")
	else:
		_update_status()

func _log(msg: String):
	txt_log.text += msg + "\n"
	print(msg)

func _on_authorized(token: String, address: String):
	_log("Signal: Authorized as " + address)
	_update_status()

func _on_auth_failed(err: String):
	_log("Signal: Auth failed: " + err)
	_update_status()

func _on_disconnected():
	_log("Signal: Disconnected")
	_update_status()

func _on_connected(token: String, address: String):
	_log("Signal: Connected as " + address)
	_update_status()

func _on_capabilities_ready(caps: Dictionary):
	_log("Signal: Capabilities ready: " + JSON.stringify(caps))

func _on_capabilities_failed(err: String):
	_log("Signal: Capabilities failed: " + err)

func _on_txs_signed(signed_txs: Array):
	_log("Signal: Signed %d transactions" % signed_txs.size())
	for tx in signed_txs:
		_log("- Size: " + str((tx as PackedByteArray).size()) + " bytes")

func _on_msgs_signed(signed_msgs: Array, addresses: Array):
	_log("Signal: Signed %d messages" % signed_msgs.size())
	for sig in signed_msgs:
		_log("- Signature size: " + str((sig as PackedByteArray).size()) + " bytes")

func _on_signing_failed(err: String):
	_log("Signal: Signing failed: " + err)

# BUTTON ACTIONS

func _on_btn_connect():
	_log("Calling authorize() interactively...")
	_set_busy(true, "Connect your wallet in the wallet app.")
	var res = await mwa.authorize("Godot MWA Example", "https://godotengine.org", mwa.Chain.DEVNET, "")
	_set_busy(false)
	if res.has("error") and res["error"] == "user_cancelled":
		_log("Connect cancelled by user.")
	else:
		_log("Authorize result: " + JSON.stringify(res))

func _on_btn_disconnect():
	_log("Calling disconnect_session()...")
	_set_busy(true, "Disconnecting...")
	var res = await mwa.disconnect_session()
	_set_busy(false)
	_log("Disconnect result: " + str(res))

func _on_btn_reconnect():
	_log("Calling reconnect()...")
	_set_busy(true, "Reconnecting (checking cache)...")
	var res = await mwa.reconnect("Godot MWA Example", "https://godotengine.org", mwa.Chain.DEVNET)
	_set_busy(false)
	if res.has("error") and res["error"] == "user_cancelled":
		_log("Reconnect cancelled by user.")
	else:
		_log("Reconnect result: " + JSON.stringify(res))

func _on_btn_sign_msg():
	_log("Calling signMessages()...")
	_set_busy(true, "Sign the message in your wallet app.")
	var msg_bytes = "Hello Solana!".to_utf8_buffer()
	var res = await mwa.signMessages([msg_bytes])
	_set_busy(false)
	if res.has("error") and res["error"] == "user_cancelled":
		_log("Sign message cancelled by user.")
	else:
		_log("SignMessage result: " + JSON.stringify(res))

func _get_connected_pubkey() -> Pubkey:
	if mwa.is_logged_in() and mwa.auth_cache != null:
		var cache = mwa.auth_cache.load_token()
		if cache.has("account_address") and cache["account_address"] != "":
			return Pubkey.new_from_string(cache["account_address"])
	return SolanaService.wallet.get_pubkey()

func _on_btn_sign_tx():
	_log("Building transaction for signTransactions()...")
	var kp = SolanaService.generate_keypair()
	var sender = _get_connected_pubkey()
	var inst = SystemProgram.transfer(sender, kp.to_pubkey(), 1000)
	var tx = Transaction.new()
	tx.add_instruction(inst)
	tx.set_payer(sender)
	await SolanaService.transaction_manager.update_blockhash(tx)
	_set_busy(true, "Approve the transaction in your wallet app.")
	var payload = tx.serialize()
	_log("Calling signTransactions with payload size: " + str(payload.size()))
	var res = await mwa.signTransactions([payload])
	_set_busy(false)
	if res.is_empty() or (res.size() == 1 and res[0] is Dictionary and res[0].has("error") and res[0]["error"] == "user_cancelled"):
		_log("Sign transaction cancelled by user.")
	else:
		_log("signTransactions result total signed counts: " + str(res.size()))

func _on_btn_sign_send():
	_log("Building transaction for signAndSendTransactions()...")
	var sender = _get_connected_pubkey()
	var new_kp = Keypair.new_random()
	_log("Using Sender Payer: " + sender.to_string())
	print("Receiver (New KP): ", new_kp.get_public_string())
	
	# Minimum rent for a new account is 890,880 lamports. 
	# Send 1,000,000 lamports (0.001 SOL) to prevent "insufficient funds for rent" simulation error.
	var ix = SystemProgram.transfer(sender, new_kp.to_pubkey(), 1000000)
	var tx = Transaction.new()
	tx.add_instruction(ix)
	tx.set_unit_limit(800000)
	tx.set_unit_price(8000)
	tx.set_payer(sender)
	await SolanaService.transaction_manager.update_blockhash(tx)
	_set_busy(true, "Approve and send in your wallet app.")
	var payload = tx.serialize()
	_log("Payload size: " + str(payload.size()) + " bytes")
	
	# Add debug logs for payload contents
	_log("Payload Base64: " + Marshalls.raw_to_base64(payload))
	_log("Payload Hex: " + payload.hex_encode())
	
	var res = await mwa.signAndSendTransactions([payload])
	_set_busy(false)
	if res.has("error") and res["error"] == "user_cancelled":
		_log("Sign & send cancelled by user.")
	else:
		_log("signAndSendTransactions result: " + JSON.stringify(res))

func _on_btn_capabilities():
	_log("Calling getCapabilities()...")
	_set_busy(true, "Fetching wallet capabilities...")
	var res = await mwa.getCapabilities()
	_set_busy(false)
	if res.has("error") and res["error"] == "user_cancelled":
		_log("Get capabilities cancelled by user.")
	else:
		_log("Capabilities: " + JSON.stringify(res))

func _on_btn_clear_cache():
	_log("Clearing cache directly...")
	if mwa.auth_cache != null:
		mwa.auth_cache.clear_token()
	_update_status()
