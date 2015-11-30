MODULE SQLite3;

IMPORT
	SYSTEM, Modules, KernelLog, DLL;
	
TYPE
	Database* = LONGINT;
	String* = ARRAY OF CHAR;

VAR
	mod: DLL.TLibInfo;
	
	LibraryLoaded-: BOOLEAN;

	aggregate_context-: PROCEDURE {WINAPI} ();
	aggregate_count-: PROCEDURE {WINAPI} ();
	auto_extension-: PROCEDURE {WINAPI} ();
	bind_blob-: PROCEDURE {WINAPI} ();
	bind_double-: PROCEDURE {WINAPI} ();
	bind_int-: PROCEDURE {WINAPI} ();
	bind_int64-: PROCEDURE {WINAPI} ();
	bind_null-: PROCEDURE {WINAPI} ();
	bind_parameter_count-: PROCEDURE {WINAPI} ();
	bind_parameter_index-: PROCEDURE {WINAPI} ();
	bind_parameter_name-: PROCEDURE {WINAPI} ();
	bind_text-: PROCEDURE {WINAPI} ();
	bind_text16-: PROCEDURE {WINAPI} ();
	bind_value-: PROCEDURE {WINAPI} ();
	bind_zeroblob-: PROCEDURE {WINAPI} ();
	blob_bytes-: PROCEDURE {WINAPI} ();
	blob_close-: PROCEDURE {WINAPI} ();
	blob_open-: PROCEDURE {WINAPI} ();
	blob_read-: PROCEDURE {WINAPI} ();
	blob_write-: PROCEDURE {WINAPI} ();
	busy_handler-: PROCEDURE {WINAPI} ();
	busy_timeout-: PROCEDURE {WINAPI} ();
	changes-: PROCEDURE {WINAPI} ();
	clear_bindings-: PROCEDURE {WINAPI} ();
	
	close-: PROCEDURE {WINAPI} (db: Database);
	
	collation_needed-: PROCEDURE {WINAPI} ();
	collation_needed16-: PROCEDURE {WINAPI} ();
	column_blob-: PROCEDURE {WINAPI} ();
	column_bytes-: PROCEDURE {WINAPI} ();
	column_bytes16-: PROCEDURE {WINAPI} ();
	column_count-: PROCEDURE {WINAPI} ();
	column_decltype-: PROCEDURE {WINAPI} ();
	column_decltype16-: PROCEDURE {WINAPI} ();
	column_double-: PROCEDURE {WINAPI} ();
	column_int-: PROCEDURE {WINAPI} ();
	column_int64-: PROCEDURE {WINAPI} ();
	column_name-: PROCEDURE {WINAPI} ();
	column_name16-: PROCEDURE {WINAPI} ();
	column_text-: PROCEDURE {WINAPI} ();
	column_text16-: PROCEDURE {WINAPI} ();
	column_type-: PROCEDURE {WINAPI} ();
	column_value-: PROCEDURE {WINAPI} ();
	commit_hook-: PROCEDURE {WINAPI} ();
	complete-: PROCEDURE {WINAPI} ();
	complete16-: PROCEDURE {WINAPI} ();
	context_db_handle-: PROCEDURE {WINAPI} ();
	create_collation-: PROCEDURE {WINAPI} ();
	create_collation16-: PROCEDURE {WINAPI} ();
	create_collation_v2-: PROCEDURE {WINAPI} ();
	create_function-: PROCEDURE {WINAPI} ();
	create_function16-: PROCEDURE {WINAPI} ();
	create_module-: PROCEDURE {WINAPI} ();
	create_module_v2-: PROCEDURE {WINAPI} ();
	data_count-: PROCEDURE {WINAPI} ();
	db_handle-: PROCEDURE {WINAPI} ();
	declare_vtab-: PROCEDURE {WINAPI} ();
	enable_load_extension-: PROCEDURE {WINAPI} ();
	enable_shared_cache-: PROCEDURE {WINAPI} ();
	errcode-: PROCEDURE {WINAPI} ();
	errmsg-: PROCEDURE {WINAPI} ();
	errmsg16-: PROCEDURE {WINAPI} ();
	
	exec-: PROCEDURE {WINAPI} (db: Database; sql: String; callback: PROCEDURE; param: LONGINT; VAR errmsg: LONGINT);
	
	expired-: PROCEDURE {WINAPI} ();
	extended_result_codes-: PROCEDURE {WINAPI} ();
	file_control-: PROCEDURE {WINAPI} ();
	finalize-: PROCEDURE {WINAPI} ();
	free-: PROCEDURE {WINAPI} ();
	free_table-: PROCEDURE {WINAPI} ();
	get_autocommit-: PROCEDURE {WINAPI} ();
	get_auxdata-: PROCEDURE {WINAPI} ();
	get_table-: PROCEDURE {WINAPI} ();
	global_recover-: PROCEDURE {WINAPI} ();
	interrupt-: PROCEDURE {WINAPI} ();
	last_insert_rowid-: PROCEDURE {WINAPI} ();
	libversion-: PROCEDURE {WINAPI} ();
	libversion_number-: PROCEDURE {WINAPI} ();
	limit-: PROCEDURE {WINAPI} ();
	load_extension-: PROCEDURE {WINAPI} ();
	malloc-: PROCEDURE {WINAPI} ();
	memory_alarm-: PROCEDURE {WINAPI} ();
	memory_highwater-: PROCEDURE {WINAPI} ();
	memory_used-: PROCEDURE {WINAPI} ();
	mprintf-: PROCEDURE {WINAPI} ();
	mutex_alloc-: PROCEDURE {WINAPI} ();
	mutex_enter-: PROCEDURE {WINAPI} ();
	mutex_free-: PROCEDURE {WINAPI} ();
	mutex_held-: PROCEDURE {WINAPI} ();
	mutex_leave-: PROCEDURE {WINAPI} ();
	mutex_notheld-: PROCEDURE {WINAPI} ();
	mutex_try-: PROCEDURE {WINAPI} ();
	
	open-: PROCEDURE {WINAPI} (filename: String; VAR db: Database);
	
	open16-: PROCEDURE {WINAPI} ();
	open_v2-: PROCEDURE {WINAPI} ();
	overload_function-: PROCEDURE {WINAPI} ();
	prepare-: PROCEDURE {WINAPI} ();
	prepare16-: PROCEDURE {WINAPI} ();
	prepare16_v2-: PROCEDURE {WINAPI} ();
	prepare_v2-: PROCEDURE {WINAPI} ();
	profile-: PROCEDURE {WINAPI} ();
	progress_handler-: PROCEDURE {WINAPI} ();
	randomness-: PROCEDURE {WINAPI} ();
	realloc-: PROCEDURE {WINAPI} ();
	release_memory-: PROCEDURE {WINAPI} ();
	reset-: PROCEDURE {WINAPI} ();
	reset_auto_extension-: PROCEDURE {WINAPI} ();
	result_blob-: PROCEDURE {WINAPI} ();
	result_double-: PROCEDURE {WINAPI} ();
	result_error-: PROCEDURE {WINAPI} ();
	result_error16-: PROCEDURE {WINAPI} ();
	result_error_code-: PROCEDURE {WINAPI} ();
	result_error_nomem-: PROCEDURE {WINAPI} ();
	result_error_toobig-: PROCEDURE {WINAPI} ();
	result_int-: PROCEDURE {WINAPI} ();
	result_int64-: PROCEDURE {WINAPI} ();
	result_null-: PROCEDURE {WINAPI} ();
	result_text-: PROCEDURE {WINAPI} ();
	result_text16-: PROCEDURE {WINAPI} ();
	result_text16be-: PROCEDURE {WINAPI} ();
	result_text16le-: PROCEDURE {WINAPI} ();
	result_value-: PROCEDURE {WINAPI} ();
	result_zeroblob-: PROCEDURE {WINAPI} ();
	rollback_hook-: PROCEDURE {WINAPI} ();
	set_authorizer-: PROCEDURE {WINAPI} ();
	set_auxdata-: PROCEDURE {WINAPI} ();
	sleep-: PROCEDURE {WINAPI} ();
	snprintf-: PROCEDURE {WINAPI} ();
	soft_heap_limit-: PROCEDURE {WINAPI} ();
	sql-: PROCEDURE {WINAPI} ();
	step-: PROCEDURE {WINAPI} ();
	test_control-: PROCEDURE {WINAPI} ();
	thread_cleanup-: PROCEDURE {WINAPI} ();
	threadsafe-: PROCEDURE {WINAPI} ();
	total_changes-: PROCEDURE {WINAPI} ();
	trace-: PROCEDURE {WINAPI} ();
	transfer_bindings-: PROCEDURE {WINAPI} ();
	update_hook-: PROCEDURE {WINAPI} ();
	user_data-: PROCEDURE {WINAPI} ();
	value_blob-: PROCEDURE {WINAPI} ();
	value_bytes-: PROCEDURE {WINAPI} ();
	value_bytes16-: PROCEDURE {WINAPI} ();
	value_double-: PROCEDURE {WINAPI} ();
	value_int-: PROCEDURE {WINAPI} ();
	value_int64-: PROCEDURE {WINAPI} ();
	value_numeric_type-: PROCEDURE {WINAPI} ();
	value_text-: PROCEDURE {WINAPI} ();
	value_text16-: PROCEDURE {WINAPI} ();
	value_text16be-: PROCEDURE {WINAPI} ();
	value_text16le-: PROCEDURE {WINAPI} ();
	value_type-: PROCEDURE {WINAPI} ();
	version-: PROCEDURE {WINAPI} ();
	vfs_find-: PROCEDURE {WINAPI} ();
	vfs_register-: PROCEDURE {WINAPI} ();
	vfs_unregister-: PROCEDURE {WINAPI} ();
	vmprintf-: PROCEDURE {WINAPI} ();

PROCEDURE GetProcAddress(CONST hModule: DLL.TLibInfo; VAR adr: LONGINT; CONST procName: ARRAY OF CHAR);
BEGIN
	IF LibraryLoaded THEN
		DLL.GetProcAddress(hModule, procName, adr);
		KernelLog.String(procName); KernelLog.String(": "); KernelLog.Int(adr, 0); KernelLog.Ln
	END
END GetProcAddress;

PROCEDURE TermMod;
BEGIN
	IF LibraryLoaded THEN
		DLL.FreeLibrary(mod);
	END
END TermMod;

PROCEDURE Init;
VAR
	str: ARRAY 12 OF CHAR;
BEGIN
	str := "SQLITE3.DLL"; 
	
	LibraryLoaded := FALSE;
	mod := DLL.LoadLibrary(str);
	IF mod # NIL THEN
		LibraryLoaded := TRUE
	END;

	GetProcAddress(mod, SYSTEM.VAL(LONGINT, aggregate_context), "sqlite3_aggregate_context");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, aggregate_count), "sqlite3_aggregate_count");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, auto_extension), "sqlite3_auto_extension");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_blob), "sqlite3_bind_blob");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_double), "sqlite3_bind_double");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_int), "sqlite3_bind_int");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_int64), "sqlite3_bind_int64");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_null), "sqlite3_bind_null");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_parameter_count), "sqlite3_bind_parameter_count");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_parameter_index), "sqlite3_bind_parameter_index");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_parameter_name), "sqlite3_bind_parameter_name");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_text), "sqlite3_bind_text");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_text16), "sqlite3_bind_text16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_value), "sqlite3_bind_value");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, bind_zeroblob), "sqlite3_bind_zeroblob");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, blob_bytes), "sqlite3_blob_bytes");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, blob_close), "sqlite3_blob_close");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, blob_open), "sqlite3_blob_open");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, blob_read), "sqlite3_blob_read");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, blob_write), "sqlite3_blob_write");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, busy_handler), "sqlite3_busy_handler");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, busy_timeout), "sqlite3_busy_timeout");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, changes), "sqlite3_changes");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, clear_bindings), "sqlite3_clear_bindings");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, close), "sqlite3_close");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, collation_needed), "sqlite3_collation_needed");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, collation_needed16), "sqlite3_collation_needed16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_blob), "sqlite3_column_blob");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_bytes), "sqlite3_column_bytes");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_bytes16), "sqlite3_column_bytes16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_count), "sqlite3_column_count");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_decltype), "sqlite3_column_decltype");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_decltype16), "sqlite3_column_decltype16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_double), "sqlite3_column_double");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_int), "sqlite3_column_int");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_int64), "sqlite3_column_int64");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_name), "sqlite3_column_name");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_name16), "sqlite3_column_name16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_text), "sqlite3_column_text");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_text16), "sqlite3_column_text16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_type), "sqlite3_column_type");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, column_value), "sqlite3_column_value");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, commit_hook), "sqlite3_commit_hook");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, complete), "sqlite3_complete");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, complete16), "sqlite3_complete16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, context_db_handle), "sqlite3_context_db_handle");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, create_collation), "sqlite3_create_collation");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, create_collation16), "sqlite3_create_collation16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, create_collation_v2), "sqlite3_create_collation_v2");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, create_function), "sqlite3_create_function");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, create_function16), "sqlite3_create_function16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, create_module), "sqlite3_create_module");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, create_module_v2), "sqlite3_create_module_v2");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, data_count), "sqlite3_data_count");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, db_handle), "sqlite3_db_handle");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, declare_vtab), "sqlite3_declare_vtab");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, enable_load_extension), "sqlite3_enable_load_extension");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, enable_shared_cache), "sqlite3_enable_shared_cache");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, errcode), "sqlite3_errcode");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, errmsg), "sqlite3_errmsg");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, errmsg16), "sqlite3_errmsg16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, exec), "sqlite3_exec");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, expired), "sqlite3_expired");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, extended_result_codes), "sqlite3_extended_result_codes");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, file_control), "sqlite3_file_control");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, finalize), "sqlite3_finalize");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, free), "sqlite3_free");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, free_table), "sqlite3_free_table");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, get_autocommit), "sqlite3_get_autocommit");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, get_auxdata), "sqlite3_get_auxdata");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, get_table), "sqlite3_get_table");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, global_recover), "sqlite3_global_recover");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, interrupt), "sqlite3_interrupt");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, last_insert_rowid), "sqlite3_last_insert_rowid");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, libversion), "sqlite3_libversion");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, libversion_number), "sqlite3_libversion_number");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, limit), "sqlite3_limit");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, load_extension), "sqlite3_load_extension");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, malloc), "sqlite3_malloc");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, memory_alarm), "sqlite3_memory_alarm");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, memory_highwater), "sqlite3_memory_highwater");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, memory_used), "sqlite3_memory_used");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, mprintf), "sqlite3_mprintf");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, mutex_alloc), "sqlite3_mutex_alloc");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, mutex_enter), "sqlite3_mutex_enter");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, mutex_free), "sqlite3_mutex_free");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, mutex_held), "sqlite3_mutex_held");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, mutex_leave), "sqlite3_mutex_leave");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, mutex_notheld), "sqlite3_mutex_notheld");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, mutex_try), "sqlite3_mutex_try");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, open), "sqlite3_open");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, open16), "sqlite3_open16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, open_v2), "sqlite3_open_v2");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, overload_function), "sqlite3_overload_function");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, prepare), "sqlite3_prepare");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, prepare16), "sqlite3_prepare16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, prepare16_v2), "sqlite3_prepare16_v2");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, prepare_v2), "sqlite3_prepare_v2");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, profile), "sqlite3_profile");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, progress_handler), "sqlite3_progress_handler");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, randomness), "sqlite3_randomness");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, realloc), "sqlite3_realloc");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, release_memory), "sqlite3_release_memory");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, reset), "sqlite3_reset");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, reset_auto_extension), "sqlite3_reset_auto_extension");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_blob), "sqlite3_result_blob");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_double), "sqlite3_result_double");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_error), "sqlite3_result_error");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_error16), "sqlite3_result_error16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_error_code), "sqlite3_result_error_code");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_error_nomem), "sqlite3_result_error_nomem");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_error_toobig), "sqlite3_result_error_toobig");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_int), "sqlite3_result_int");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_int64), "sqlite3_result_int64");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_null), "sqlite3_result_null");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_text), "sqlite3_result_text");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_text16), "sqlite3_result_text16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_text16be), "sqlite3_result_text16be");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_text16le), "sqlite3_result_text16le");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_value), "sqlite3_result_value");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, result_zeroblob), "sqlite3_result_zeroblob");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, rollback_hook), "sqlite3_rollback_hook");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, set_authorizer), "sqlite3_set_authorizer");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, set_auxdata), "sqlite3_set_auxdata");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, sleep), "sqlite3_sleep");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, snprintf), "sqlite3_snprintf");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, soft_heap_limit), "sqlite3_soft_heap_limit");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, sql), "sqlite3_sql");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, step), "sqlite3_step");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, test_control), "sqlite3_test_control");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, thread_cleanup), "sqlite3_thread_cleanup");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, threadsafe), "sqlite3_threadsafe");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, total_changes), "sqlite3_total_changes");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, trace), "sqlite3_trace");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, transfer_bindings), "sqlite3_transfer_bindings");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, update_hook), "sqlite3_update_hook");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, user_data), "sqlite3_user_data");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_blob), "sqlite3_value_blob");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_bytes), "sqlite3_value_bytes");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_bytes16), "sqlite3_value_bytes16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_double), "sqlite3_value_double");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_int), "sqlite3_value_int");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_int64), "sqlite3_value_int64");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_numeric_type), "sqlite3_value_numeric_type");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_text), "sqlite3_value_text");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_text16), "sqlite3_value_text16");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_text16be), "sqlite3_value_text16be");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_text16le), "sqlite3_value_text16le");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, value_type), "sqlite3_value_type");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, version), "sqlite3_version");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, vfs_find), "sqlite3_vfs_find");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, vfs_register), "sqlite3_vfs_register");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, vfs_unregister), "sqlite3_vfs_unregister");
	GetProcAddress(mod, SYSTEM.VAL(LONGINT, vmprintf), "sqlite3_vmprintf");
	
	Modules.InstallTermHandler(TermMod)

END Init;
BEGIN
	Init()
END SQLite3.