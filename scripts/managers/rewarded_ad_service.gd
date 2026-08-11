extends Node

## Offline placeholder for a future rewarded-ad SDK integration.
signal reward_completed(gems: int)
const REWARD_GEMS: int = GameBalance.AD_GEM_REWARD

func is_available() -> bool:
	return false

func request_reward() -> bool:
	# A real SDK must emit reward_completed only after its verified callback.
	return false
