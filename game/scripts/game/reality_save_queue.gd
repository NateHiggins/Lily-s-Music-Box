extends RefCounted
## Main-thread FIFO scheduler for RealityState's existing storage transaction.
## Workers own only immutable bytes, path and a private storage/validator instance.
const Storage := preload("res://scripts/game/reality_save_storage.gd")
const Document := preload("res://scripts/game/reality_save_document.gd")
var _thread: Thread
var _pending: Array[Dictionary] = []
var _active: Dictionary = {}
var _immediate: Array[Dictionary] = []
var _next_id := 0

func submit(path: String, bytes: PackedByteArray, version: int) -> int:
	assert(Thread.is_main_thread())
	_next_id+=1
	_pending.append({"id":_next_id,"path":path,"bytes":bytes,"version":version})
	return _next_id

func pending_count() -> int:
	return _pending.size()+int(_thread!=null)+_immediate.size()

func start_next() -> void:
	assert(Thread.is_main_thread())
	if _thread!=null or _pending.is_empty() or not _immediate.is_empty():return
	_active=_pending.pop_front()
	_thread=Thread.new()
	var error:=_thread.start(_write.bind(_active.path,_active.bytes,_active.version))
	if error!=OK:
		# Resource exhaustion must not silently drop progress. The rare fallback
		# uses the identical transaction synchronously and is reported as such.
		_thread=null
		var result:=_write(_active.path,_active.bytes,_active.version)
		_immediate.append({"id":_active.id,"path":_active.path,"result":result})
		_active={}

func take_completed(wait := false) -> Array[Dictionary]:
	assert(Thread.is_main_thread())
	var completed: Array[Dictionary]=_immediate
	_immediate=[]
	if _thread!=null and (wait or not _thread.is_alive()):
		var result: Dictionary=_thread.wait_to_finish()
		_thread=null
		completed.append({"id":_active.id,"path":_active.path,"result":result})
		_active={}
	return completed

func discard_pending() -> int:
	assert(Thread.is_main_thread())
	var count:=_pending.size();_pending.clear();return count

static func _write(path: String, bytes: PackedByteArray, version: int) -> Dictionary:
	var started:=Time.get_ticks_usec()
	var storage:=Storage.new();storage.path=path
	storage.validate_document=func(candidate: Dictionary):return Document.validate(candidate,version)
	var result: Dictionary=storage.write_snapshot(bytes)
	result["worker_main_thread"]=Thread.is_main_thread()
	result["worker_started_usec"]=started
	result["worker_finished_usec"]=Time.get_ticks_usec()
	result["worker_usec"]=int(result.worker_finished_usec)-started
	return result
