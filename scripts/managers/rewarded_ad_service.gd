extends Node

## Owns the platform-specific rewarded-ad lifecycle and exposes a small,
## verified callback to the game layer. Desktop and Web builds intentionally
## stay unavailable so tests can never mint gems without a native ad callback.
signal reward_completed(gems: int)
signal availability_changed(available: bool)

const REWARD_GEMS: int = GameBalance.AD_GEM_REWARD
const ADMOB_SCRIPT_PATH: String = "res://addons/AdmobPlugin/Admob.gd"
const ADMOB_CONFIG_PATH: String = "res://addons/AdmobPlugin/ios_export.cfg"
const RETRY_DELAY_SECONDS: float = 10.0

var _admob_node: Node
var _ad_initialized: bool = false
var _ad_loading: bool = false
var _rewarded_ad_id: String = ""
var _pending_reward: bool = false
var _reward_granted: bool = false
var _last_available: bool = false
var _retry_timer: Timer

var _use_real_ids: bool = false
var _debug_app_id: String = ""
var _real_app_id: String = ""
var _debug_rewarded_id: String = ""
var _real_rewarded_id: String = ""


func _ready() -> void:
	_load_config()
	if not OS.has_feature("ios"):
		return
	if _use_real_ids and (_real_app_id.is_empty() or _real_rewarded_id.is_empty()):
		push_warning("Rewarded ads are disabled until real AdMob IDs are configured.")
		return
	_initialize_admob()


func is_available() -> bool:
	return (
		_admob_node != null
		and _ad_initialized
		and not _ad_loading
		and not _pending_reward
		and not _rewarded_ad_id.is_empty()
		and bool(_admob_node.call("is_rewarded_ad_loaded"))
	)


func request_reward() -> bool:
	if not is_available():
		return false
	_pending_reward = true
	_reward_granted = false
	_admob_node.call("show_rewarded_ad", _rewarded_ad_id)
	_emit_availability_changed()
	return true


func _load_config() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(ADMOB_CONFIG_PATH) != OK:
		push_warning("Missing AdMob config; rewarded ads remain disabled.")
		return
	_use_real_ids = bool(config.get_value("General", "is_real", false))
	# Keep local/debug iOS builds on Google's test inventory even when the
	# exported Release configuration has been switched to the publisher IDs.
	# This prevents development clicks from creating invalid production traffic.
	if OS.is_debug_build():
		_use_real_ids = false
	_debug_app_id = str(config.get_value("Debug", "app_id", ""))
	_real_app_id = str(config.get_value("Release", "app_id", ""))
	_debug_rewarded_id = str(config.get_value("Rewarded", "debug_id", ""))
	_real_rewarded_id = str(config.get_value("Rewarded", "real_id", ""))


func _initialize_admob() -> void:
	if not ResourceLoader.exists(ADMOB_SCRIPT_PATH):
		push_warning("AdMob plugin script is not installed; rewarded ads remain disabled.")
		return
	var admob_script: Script = load(ADMOB_SCRIPT_PATH) as Script
	if admob_script == null:
		push_warning("AdMob plugin script could not be loaded; rewarded ads remain disabled.")
		return
	var instance: Variant = admob_script.new()
	if not instance is Node:
		push_warning("AdMob plugin did not create a Node; rewarded ads remain disabled.")
		return
	_admob_node = instance as Node
	_admob_node.name = "Admob"
	_admob_node.set("is_real", _use_real_ids)
	_admob_node.set("ios_debug_application_id", _debug_app_id)
	_admob_node.set("ios_real_application_id", _real_app_id)
	_admob_node.set("ios_debug_rewarded_id", _debug_rewarded_id)
	_admob_node.set("ios_real_rewarded_id", _real_rewarded_id)
	_admob_node.set("remove_rewarded_ads_after_displayed", true)
	_admob_node.set("remove_rewarded_ads_after_scene", false)
	add_child(_admob_node)

	if not _admob_node.has_signal("initialization_completed"):
		push_warning("AdMob plugin signals are unavailable; rewarded ads remain disabled.")
		return
	_admob_node.connect("initialization_completed", _on_admob_initialized)
	_admob_node.connect("rewarded_ad_loaded", _on_rewarded_ad_loaded)
	_admob_node.connect("rewarded_ad_failed_to_load", _on_rewarded_ad_failed_to_load)
	_admob_node.connect("rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_ad_failed_to_show)
	_admob_node.connect("rewarded_ad_dismissed_full_screen_content", _on_rewarded_ad_dismissed)
	_admob_node.connect("rewarded_ad_user_earned_reward", _on_rewarded_ad_user_earned_reward)
	_admob_node.call("initialize")


func _on_admob_initialized(_status_data: Variant) -> void:
	_ad_initialized = true
	_load_rewarded_ad()


func _load_rewarded_ad() -> void:
	if _admob_node == null or not _ad_initialized or _ad_loading or _pending_reward:
		return
	_ad_loading = true
	_rewarded_ad_id = ""
	_emit_availability_changed()
	_admob_node.call("load_rewarded_ad")


func _on_rewarded_ad_loaded(ad_info: Variant, _response_info: Variant) -> void:
	_ad_loading = false
	if ad_info != null and ad_info.has_method("get_ad_id"):
		_rewarded_ad_id = str(ad_info.call("get_ad_id"))
	_emit_availability_changed()


func _on_rewarded_ad_failed_to_load(_ad_info: Variant, _error_data: Variant) -> void:
	_ad_loading = false
	_rewarded_ad_id = ""
	_emit_availability_changed()
	_schedule_retry()


func _on_rewarded_ad_failed_to_show(_ad_info: Variant, _error_data: Variant) -> void:
	_pending_reward = false
	_reward_granted = false
	_rewarded_ad_id = ""
	_emit_availability_changed()
	_schedule_retry()


func _on_rewarded_ad_dismissed(_ad_info: Variant) -> void:
	_pending_reward = false
	_reward_granted = false
	_rewarded_ad_id = ""
	_emit_availability_changed()
	_load_rewarded_ad()


func _on_rewarded_ad_user_earned_reward(_ad_info: Variant, _reward_data: Variant) -> void:
	if not _pending_reward or _reward_granted:
		return
	_reward_granted = true
	# The native SDK callback is the proof that the user earned the reward. The
	# amount configured on an AdMob ad unit is deliberately not trusted as the
	# game's economy value; the game balance remains the single source of truth.
	reward_completed.emit(REWARD_GEMS)


func _schedule_retry() -> void:
	if _retry_timer != null and is_instance_valid(_retry_timer):
		return
	_retry_timer = Timer.new()
	_retry_timer.name = "RewardedAdRetryTimer"
	_retry_timer.one_shot = true
	_retry_timer.wait_time = RETRY_DELAY_SECONDS
	_retry_timer.timeout.connect(_on_retry_timeout)
	add_child(_retry_timer)
	_retry_timer.start()


func _on_retry_timeout() -> void:
	if _retry_timer != null and is_instance_valid(_retry_timer):
		_retry_timer.queue_free()
	_retry_timer = null
	_load_rewarded_ad()


func _emit_availability_changed() -> void:
	var current_available: bool = is_available()
	if current_available == _last_available:
		return
	_last_available = current_available
	availability_changed.emit(current_available)
