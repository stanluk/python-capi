from cpython cimport bool

cdef extern from "stdlib.h" nogil:
    void *malloc(size_t size)
    void free(void *ptr)

cdef extern from "time.h" nogil:
    cdef struct tm:
        int tm_sec
        int tm_min
        int tm_hour
        int tm_mday
        int tm_mon
        int tm_year
        int tm_wday
        int tm_yday
        int tm_isdst

cdef extern from "string.h" nogil:
    void *memcpy(void *dst, void *src, int n)
    void *memset(void *mem, int val, size_t size)

cdef extern from "app.h":

    ctypedef struct service_h:
        pass

    ctypedef enum app_error_e:
        APP_ERROR_NONE
        APP_ERROR_INVALID_PARAMETER
        APP_ERROR_OUT_OF_MEMORY
        APP_ERROR_INVALID_CONTEXT
        APP_ERROR_NO_SUCH_FILE
        APP_ERROR_ALREADY_RUNNING

    ctypedef enum service_error_e:
        SERVICE_ERROR_NONE
        SERVICE_ERROR_INVALID_PARAMETER
        SERVICE_ERROR_OUT_OF_MEMORY
        SERVICE_ERROR_APP_NOT_FOUND
        SERVICE_ERROR_KEY_NOT_FOUND
        SERVICE_ERROR_KEY_REJECTED
        SERVICE_ERROR_INVALID_DATA_TYPE
        SERVICE_ERROR_LAUNCH_REJECTED

    ctypedef enum service_result_e:
        SERVICE_RESULT_SUCCEEDED
        SERVICE_RESULT_FAILED
        SERVICE_RESULT_CANCELED

    ctypedef enum app_device_orientation_e:
        APP_DEVICE_ORIENTATION
        APP_DEVICE_ORIENTATION_90
        APP_DEVICE_ORIENTATION_180
        APP_DEVICE_ORIENTATION_270

    ctypedef bool (*app_create_cb)(void *user_data)
    ctypedef void (*app_pause_cb)(void *user_data)
    ctypedef void (*app_resume_cb)(void *user_data)
    ctypedef void (*app_terminate_cb)(void *user_data)
    ctypedef void (*app_service_cb)(service_h service, void *user_data)
    ctypedef void (*app_low_memory_cb)(void *user_data)
    ctypedef void (*app_low_battery_cb)(void *user_data)
    ctypedef void (*app_device_orientation_cb)(app_device_orientation_e orientation, void *user_data)
    ctypedef void (*app_language_change_cb)(void *user_data)
    ctypedef void (*app_region_format_changed_cb)(void *user_data)

    ctypedef struct app_event_callback_s:
        app_create_cb create
        app_terminate_cb terminate
        app_pause_cb pause
        app_resume_cb resume
        app_service_cb service
        app_low_memory_cb low_memory
        app_low_battery_cb low_battery
        app_device_orientation_cb device_orientation
        app_language_change_cb language_changed
        app_region_format_changed_cb region_format_changed

    void app_efl_exit()
    int app_efl_main(int *argc, char ***argv, app_event_callback_s *callback, void *userd_data) nogil
    int app_get_package(char **package)
    int app_get_id(char **id)
    int app_get_name(char **name)
    int app_get_version(char **version)
    char* app_get_resource(const char *resource, char *buffer, int size)
    char* app_get_data_directory(char *buffer, int size)
    app_device_orientation_e app_get_device_orientation()
    void app_set_reclaiming_system_cache_on_pause(bool enable)


cdef extern from "app_service.h":
    ctypedef enum service_result_e:
        SERVICE_RESULT_SUCCEEDED
        SERVICE_RESULT_FAILED
        SERVICE_RESULT_CANCELED

    ctypedef bool (*service_app_matched_cb)(service_h service, const char *appid, void *user_data)
    ctypedef void (*service_reply_cb)(service_h request, service_h reply, service_result_e result, void *user_data)

    ctypedef bool (*service_extra_data_cb)(service_h service, const char *key, void *user_data)

    int service_set_app_id(service_h service, const char *app_id)
    int service_get_app_id(service_h service, char **app_id)
    int service_set_category(service_h service, const char *category)
    int service_get_category(service_h service, char **category)
    int service_get_mime(service_h service, char **mime)
    int service_set_mime(service_h service, const char *mime)
    int service_set_operation(service_h service, const char *operation)
    int service_get_operation(service_h service, char **operation)
    int service_get_uri(service_h service, char **uri)
    int service_set_uri(service_h service, const char *uri)
    int service_set_window(service_h service, unsigned int id)
    int service_get_window(service_h service, unsigned int *id)
    int service_get_caller(service_h service, char **id)
    int service_is_reply_requested(service_h service, int *requested)
    int service_reply_to_launch_request(service_h reply, service_h request, service_result_e result)
    int service_send_launch_request(service_h service, service_reply_cb callback, void *user_data)
    int service_foreach_app_matched(service_h service, service_app_matched_cb callback, void *user_data)
    int service_foreach_extra_data(service_h service, service_extra_data_cb callback, void *user_data)
    int service_is_extra_data_array(service_h service, const char *key, int *array)
    int service_get_extra_data_array(service_h service, const char *key, char ***value, int *length)
    int service_get_extra_data(service_h service, const char *key, char **value)
    int service_add_extra_data(service_h service, const char *key, const char *value)
    int service_add_extra_data_array(service_h service, const char *key, const char* value[], int length)
    int service_remove_extra_data(service_h service, const char *key)
    int service_create(service_h *service)
    int service_destroy(service_h service)
    int service_clone(service_h *clone, service_h service)

cdef extern from "app_alarm.h":
    ctypedef enum alarm_error_e:
        ALARM_ERROR_NONE
        ALARM_ERROR_INVALID_PARAMETER
        ALARM_ERROR_INVALID_TIME
        ALARM_ERROR_INVALID_DATE
        ALARM_ERROR_CONNECTION_FAIL
        ALARM_ERROR_OUT_OF_MEMORY

    ctypedef enum alarm_week_flag_e:
        ALARM_WEEK_FLAG_SUNDAY
        ALARM_WEEK_FLAG_MONDAY
        ALARM_WEEK_FLAG_TUESDAY
        ALARM_WEEK_FLAG_WEDNESDAY
        ALARM_WEEK_FLAG_THURSDAY
        ALARM_WEEK_FLAG_FRIDAY
        ALARM_WEEK_FLAG_SATURDAY

    ctypedef bool (*alarm_registered_alarm_cb)(int alarm_id, void *user_data)

    int alarm_cancel(int alarm_id)
    int alarm_cancel_all()
    int alarm_foreach_registered_alarm(alarm_registered_alarm_cb callback, void *user_data)
    int alarm_get_scheduled_date(int alarm_id, tm *date)
    int alarm_get_scheduled_period(int alarm_id, int *period)
    int alarm_get_scheduled_recurrence_week_flag(int alarm_id, int *week_flag)
    int alarm_get_service(int alarm_id, service_h *service)
    int alarm_schedule_after_delay(service_h service, int delay, int period, int *alarm_id)
    int alarm_schedule_at_date(service_h service, tm *date, int period, int *alarm_id)
    int alarm_schedule_with_recurrence_week_flag(service_h service, tm *date, int week_flag,int *alarm_id)
