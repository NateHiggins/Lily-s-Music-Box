extends Logger
var errors: Array[String]=[]
var guard:=Mutex.new()
func _log_error(_function: String,file: String,line: int,code: String,
		rationale: String,_editor_notify: bool,error_type: int,
		_script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type==Logger.ERROR_TYPE_WARNING: return
	guard.lock()
	errors.append("%s:%d %s %s"%[file,line,code,rationale])
	guard.unlock()
