from cpython cimport bool

cdef extern from "string.h":
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
        app_pause_cb pause
        app_resume_cb resume
        app_service_cb service
        app_low_memory_cb low_memory
        app_low_battery_cb low_battery
        app_device_orientation_cb device_orientation
        app_language_change_cb language_changed
        app_region_format_changed_cb region_format_changed

    void app_efl_exit()
    int app_efl_main(int *argc, char ***argv, app_event_callback_s *callback, void *userd_data)

