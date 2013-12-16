from cpython cimport PyMem_Malloc, PyMem_Free, Py_INCREF, Py_DECREF
from cpython cimport bool
from cython.operator cimport dereference as deref

import sys
import logging
from datetime import datetime
from time import mktime

logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger("capi")


STORAGE_STATES = {
    STORAGE_STATE_UNMOUNTABLE: "Unmountable",
    STORAGE_STATE_REMOVED: "Removed",
    STORAGE_STATE_MOUNTED: "Mounted",
    STORAGE_STATE_MOUNTED_READ_ONLY: "Mounte RO"
}

STORAGE_TYPES = {
    STORAGE_TYPE_INTERNAL: "Internal",
    STORAGE_TYPE_EXTERNAL: "External"
}


class TizenError(Exception):
    def __init__(self, msg):
        self.message = msg

    def __str__(self):
        return repr(self.message)


class TizenAppError(TizenError):
    TIZEN_APP_ERRORS = {
        APP_ERROR_NONE: "Successful",
        APP_ERROR_INVALID_PARAMETER: "Invalid parameter",
        APP_ERROR_OUT_OF_MEMORY: "Out of memory",
        APP_ERROR_INVALID_CONTEXT: "Invalid application context",
        APP_ERROR_NO_SUCH_FILE: "No such file or directory",
        APP_ERROR_ALREADY_RUNNING: "Application is already running"
    }

    def __init__(self, error):
        TizenError.__init__(self, TizenAppError.TIZEN_APP_ERRORS[error])
        self.error_code = error


class TizenAlarmError(TizenError):
    TIZEN_ALARM_ERRORS = {
        ALARM_ERROR_NONE: "Successful",
        ALARM_ERROR_INVALID_PARAMETER: "Invalid parameter",
        ALARM_ERROR_INVALID_TIME: "Invalid time",
        ALARM_ERROR_INVALID_DATE: "Invalid date",
        ALARM_ERROR_CONNECTION_FAIL: "The alarm service connection failed",
        ALARM_ERROR_OUT_OF_MEMORY: "Out of memory"
    }

    def __init__(self, error):
        TizenError.__init__(self, TizenAlarmError.TIZEN_ALARM_ERRORS[error])
        self.error_code = error


class TizenServiceError(TizenError):
    TIZEN_SERVICE_ERRORS = {
        SERVICE_ERROR_NONE: "Successful",
        SERVICE_ERROR_INVALID_PARAMETER: "Invalid parameter",
        SERVICE_ERROR_OUT_OF_MEMORY: "Out of memory",
        SERVICE_ERROR_APP_NOT_FOUND: "The application was not found",
        SERVICE_ERROR_KEY_NOT_FOUND: "Specified key not found",
        SERVICE_ERROR_KEY_REJECTED: "Not available key",
        SERVICE_ERROR_INVALID_DATA_TYPE: "Invalid data type",
        SERVICE_ERROR_LAUNCH_REJECTED: "Internal launch erro",
    }

    def __init__(self, error):
        TizenError.__init__(self, TizenAppError.TIZEN_APP_ERRORS[error])
        self.error_code = error


class TizenNotificationError(TizenError):
    TIZEN_NOTIFICATION_ERRORS = {
        UI_NOTIFICATION_ERROR_NONE: "Successful",
        UI_NOTIFICATION_ERROR_INVALID_PARAMETER: "Invalid parameter",
        UI_NOTIFICATION_ERROR_OUT_OF_MEMORY: "Out of memory",
        UI_NOTIFICATION_ERROR_DB_FAILED: "DB operation failed",
        UI_NOTIFICATION_ERROR_NO_SUCH_FILE: "No such file",
        UI_NOTIFICATION_ERROR_INVALID_STATE: "Invalid state"
    }

    def __init__(self, error):
        TizenError.__init__(self, TizenAppError.TIZEN_NOTIFICATION_ERRORS[error])
        self.error_code = error


class TizenStorageError(TizenError):
    TIZEN_STORAGE_ERRORS = {
        STORAGE_ERROR_NONE: "Successful",
        STORAGE_ERROR_INVALID_PARAMETER: "Invalid parameter",
        STORAGE_ERROR_OUT_OF_MEMORY: "Out of memory",
        STORAGE_ERROR_NOT_SUPPORTED: "Not supported storage",
    }

    def __init__(self, error):
        TizenError.__init__(self, TizenAppError.TIZEN_STORAGE_ERRORS[error])
        self.error_code = error


cdef inline char* _fruni(s):
    cdef char* c_string
    if isinstance(s, unicode):
        string = s.encode('UTF-8')
        c_string = string
    elif isinstance(s, str):
        c_string = s
    elif s is None:
        return NULL
    else:
        raise TypeError("Expected str or unicode object, got %s" % (type(s).__name__))
    return c_string


cdef unicode _ctouni(char *s):
    return s.decode('UTF-8', 'strict') if s else None


def _get_storage_attr(id):
    cdef int err
    cdef unsigned long long space
    cdef char *cstr
    cdef bytes pstr
    cdef storage_state_e state
    cdef storage_type_e stype
    info = {}

    info['id'] = id

    err = storage_get_available_space(id, &space)
    if err != STORAGE_ERROR_NONE:
        raise TizenStorageError(err)
    info['available_space'] = space

    err = storage_get_root_directory(id, &cstr)
    if err != STORAGE_ERROR_NONE:
        raise TizenStorageError(err)
    try:
        pstr = cstr
    finally:
        free(cstr)
    info['root_dir'] = pstr

    err = storage_get_state(id, &state)
    if err != STORAGE_ERROR_NONE:
        raise TizenStorageError(err)
    info['state'] = STORAGE_STATES[state]

    err = storage_get_total_space(id, &space)
    if err != STORAGE_ERROR_NONE:
        raise TizenStorageError(err)
    info['total_space'] = space

    err = storage_get_type(id, &stype)
    if err != STORAGE_ERROR_NONE:
        raise TizenStorageError(err)
    info['state'] = STORAGE_TYPES[state]

    return info

cdef bool on_create(void *cls) with gil:
    cdef object inst = <object>cls
    try:
        inst.create()
    except:
        inst._set_exception()
        inst.exit()
        return False
    return True


cdef void on_pause(void *cls) with gil:
    cdef object inst = <object>cls
    try:
        inst.pause()
    except:
        inst._set_exception()
        inst.exit()


cdef void on_resume(void *cls) with gil:
    cdef object inst = <object>cls
    try:
        inst.resume()
    except:
        inst._set_exception()
        inst.exit()


cdef void on_terminate(void *cls) with gil:
    cdef object inst = <object>cls
    try:
        inst.terminate()
    except:
        inst._set_exception()
        inst.exit()


cdef void on_service(service_h service, void *cls) with gil:
    cdef object inst = <object>cls
    try:
        srv = Service()
        Service._set_handle(srv, handle=service)
        inst.service(srv)
    except:
        inst._set_exception()
        inst.exit()


cdef void on_low_memory(void *cls) with gil:
    cdef object inst = <object>cls
    try:
        inst.low_memory()
    except:
        inst._set_exception()
        inst.exit()


cdef void on_low_battery(void *cls) with gil:
    cdef object inst = <object>cls
    try:
        inst.low_battery()
    except:
        inst._set_exception()
        inst.exit()


cdef void on_device_orientation_change(app_device_orientation_e orient, void *cls) with gil:
    cdef object inst = <object>cls
    try:
        inst.app_device_orientation_change(orient)
    except:
        inst._set_exception()
        inst.exit()


cdef void on_language_changed(void *cls) with gil:
    cdef object inst = <object>cls
    try:
        inst.language_changed()
    except:
        inst._set_exception()
        inst.exit()


cdef void on_region_format_changed(void *cls) with gil:
    cdef object inst = <object>cls
    try:
        inst.region_format_changed()
    except:
        inst._set_exception()
        inst.exit()


cdef class TizenEflApp:
    def __init__(self):
        self._exc = None

    def _set_exception(self):
        exc = sys.exc_info()
        if exc != (None, None, None):
            self._exc = exc

    def _raise_exception(self):
        if self._exc:
            raise self._exc[0], self._exc[1], self._exc[2]

    def create(self):
        raise NotImplementedError("TizenEflApp should at least implement "
                                  "create callback.")

    def pause(self):
        pass

    def resume(self):
        pass

    def terminate(self):
        pass

    def service(self, service):
        pass

    def low_memory(self):
        pass

    def low_battery(self):
        pass

    def device_orientation_change(self, orient):
        pass

    def language_changed(self):
        pass

    def region_format_changed(self):
        pass

    def run(self):
        cdef int argc, err, arg_len
        cdef char **argv, *arg
        cdef app_event_callback_s cbs
        cbs.create = on_create
        cbs.pause = on_pause
        cbs.resume = on_resume
        cbs.terminate = on_terminate
        cbs.service = on_service
        cbs.low_memory = on_low_memory
        cbs.low_battery = on_low_battery
        cbs.device_orientation = on_device_orientation_change
        cbs.language_changed = on_language_changed
        cbs.region_format_changed = on_region_format_changed
        argc = len(sys.argv)
        argv = <char **>PyMem_Malloc(argc * sizeof(char *))
        for i from 0 <= i < argc:
            arg = _fruni(sys.argv[i])
            arg_len = len(arg)
            argv[i] = <char *>PyMem_Malloc(arg_len + 1)
            memcpy(argv[i], arg, arg_len + 1)

        with nogil:
            err = app_efl_main(&argc, &argv, &cbs, <void*>self)
        # since all python exceptions are raised in
        # app_efl_main function execptions should be reraised.
        self._raise_exception()

        if err != APP_ERROR_NONE:
            raise TizenAppError(err)

    def exit(self):
        app_efl_exit()

    @property
    def package(self):
        cdef bytes pypackage
        cdef char *package
        cdef int err = app_get_package(&package)
        if err != APP_ERROR_NONE:
            raise TizenAppError(err)
        try:
            pypackage = package
        finally:
            free(package)
        return pypackage

    @property
    def id(self):
        cdef bytes pyid
        cdef char *id
        cdef int err = app_get_id(&id)
        if err != APP_ERROR_NONE:
            raise TizenAppError(err)
        try:
            pyid = id
        finally:
            free(id)
        return pyid

    @property
    def name(self):
        cdef bytes pystr
        cdef char *cstr
        cdef int err = app_get_id(&cstr)
        if err != APP_ERROR_NONE:
            raise TizenAppError(err)
        try:
            pystr = cstr
        finally:
            free(cstr)
        return pystr

    @property
    def version(self):
        cdef bytes pystr
        cdef char *cstr
        cdef int err = app_get_version(&cstr)
        if err != APP_ERROR_NONE:
            raise TizenAppError(err)
        try:
            pystr = cstr
        finally:
            free(cstr)
        return pystr

    def resource_path_get(self, resource):
        cdef bytes pystr
        # FIXME issues with buffer len
        cdef char cstr[1024]
        cdef char *res_conv = _fruni(resource)
        cdef char *res = app_get_resource(res_conv, cstr, sizeof(cstr))
        if res == NULL:
            raise TizenError("Getting '%s' resource path failed." % resource)
        pystr = cstr
        return pystr

    @property
    def data_dir(self):
        cdef bytes pystr
        # FIXME issues with buffer len
        cdef char cstr[1024]
        cdef char *res = app_get_data_directory(cstr, sizeof(cstr))
        if res == NULL:
            raise TizenError("Getting data directory failed.")
        pystr = cstr
        return pystr

    @property
    def device_orientation(self):
        return app_get_device_orientation()

    def reclaim_system_cache(self, val):
        app_set_reclaiming_system_cache_on_pause(bool(val))

    def get_alarms(self):
        alarms = []
        cdef int err = alarm_foreach_registered_alarm(_alarm_registered_alarm_cb, <void*>alarms)
        if err != ALARM_ERROR_NONE:
            raise TizenAlarmError(err)
        return alarms

    def cancel_all_alarms(self):
        cdef int err = alarm_cancel_all()
        if err != ALARM_ERROR_NONE:
            raise TizenAlarmError(err)

    def cancel_all_notifications(self, app_id=None, package=None, type=None,
                                 ongoing=False):
        cdef int err = UI_NOTIFICATION_ERROR_NONE
        cdef char *cstr
        if app_id:
            cstr = app_id
            err = ui_notification_cancel_all_by_app_id(cstr, ongoing)
        elif package:
            cstr = package
            ui_notification_cancel_all_by_package(cstr, ongoing)
        elif type:
            ui_notification_cancel_all_by_type(ongoing)

        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)

    def notifications(self):
        cdef err
        notis = []
        err = ui_notification_foreach_notification_posted(True,
                _ui_notification_cb, <void*>notis)
        if err != UI_NOTIFICATION_ERROR_NONE:
           raise TizenNotificationError(err)
        err = ui_notification_foreach_notification_posted(False,
                _ui_notification_cb, <void*>notis)
        if err != UI_NOTIFICATION_ERROR_NONE:
           raise TizenNotificationError(err)
        return notis

    def storage(self):
        cdef int err
        ret = []
        err = storage_foreach_device_supported(_storage_device_supported_cb,
                <void*>ret)
        if err != STORAGE_ERROR_NONE:
            raise TizenStorageError(err)
        return ret

    def storage_change_handler_add(self, id, call_obj):
        cdef int err
        err = storage_set_state_changed_cb(id, _storage_state_changed_cb,
                                           <void*>call_obj)
        if err != STORAGE_ERROR_NONE:
            raise TizenStorageError(err)

    def storage_change_handler_del(self, id):
        cdef int err = storage_unset_state_changed_cb(id)
        if err != STORAGE_ERROR_NONE:
            raise TizenStorageError(err)


cdef void _storage_state_changed_cb(int storage, storage_state_e state, void
                                    *user_data) with gil:
    cdef object func = <object>user_data
    info = _get_storage_attr(storage)
    func(info)


cdef bool _storage_device_supported_cb(int storage, storage_type_e type,
    storage_state_e state, const char *path, void *user_data):
    cdef object ret = <object>user_data
    info = _get_storage_attr(storage)
    ret.append(info)
    return True


cdef bool _ui_notification_cb(ui_notification_h notification, void *user_data):
    cdef object notis = <object>user_data
    noti = Notification(handle=notification)
    notis.append(noti)
    return True


cdef bool _alarm_registered_alarm_cb(int alarm_id, void *user_data):
    cdef object alarms = <object>user_data
    alarm = Alarm()
    alarm._set_id(alarm_id)
    alarms.append(alarm)
    return True

cdef bool _service_math_cb(service_h s, const char *app_id, void *data):
    cdef bytes aid = app_id
    cdef object all_ids = <object>data
    all_ids.append(aid)
    return True  # get next matching app_id


cdef bool _service_foreach_key_del(service_h handle, const char *key, void *data):
    cdef err = service_remove_extra_data(handle, key)
    if err != SERVICE_ERROR_NONE:
        return False
    return True


cdef bool _service_foreach_key(service_h handle, const char *key, void *data):
    cdef int is_extra_data
    cdef int err
    cdef bytes pkey = key
    cdef bytes val
    cdef object service_data = <object>data
    cdef object value = None
    cdef int length
    cdef char *values
    cdef char **avalues
    err = service_is_extra_data_array(handle, key, &is_extra_data);
    if err != SERVICE_ERROR_NONE:
        return False

    if is_extra_data:
        value = []
        err = service_get_extra_data_array(handle, key, &avalues, &length)
        if err != SERVICE_ERROR_NONE:
            return False
        for i in range(length):
            try:
                val = avalues[i]
                value.append(val)
            except:
                return False
            finally:
                free(avalues[i])
        free(avalues)
    else:
        err = service_get_extra_data(handle, key, &values)
        if err != SERVICE_ERROR_NONE:
            return False
        try:
            val = value
        except:
            return False
        finally:
            free(values)

    service_data[pkey] = value
    return True


cdef class ServiceAnswer(Service):
    def __init__(self, request):
        if not isinstance(request, Service):
            raise TizenError("Invalid type: request Service instance")
        Service.__init__(self)
        Service._set_handle(self, handle=NULL)
        self._request = request

    def __del__(self):
        Service.__del__(self)

    def send(self, value):
        cdef int err = service_reply_to_launch_request(
                                        Service._get_handle(self),
                                        Service._get_handle(self._request),
                                        value)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)


cdef void _service_reply_cb(service_h request, service_h reply,
            service_result_e result, void *user_data) with gil:
    cdef object inst = <object>user_data
    answer = Service()
    answer._set_handle(handle=reply)
    inst.request_handler(answer, result)
    Py_DECREF(inst)


cdef class ServiceRequest(Service):
    def __init__(self):
        Service.__init__(self)
        Service._set_handle(self, handle=NULL)

    def request_handler(self, answer, result):
        pass

    def send(self):
        cdef int err = service_send_launch_request(Service._get_handle(self),
                                _service_reply_cb, <void*>self)

        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        Py_INCREF(self)


cdef class Service(object):
    cdef service_h _handle

    def __cinit__(self):
        self._handle = NULL

    cdef int _set_handle(self, service_h handle, bool clone=True) except? 0:
        assert self._handle == NULL, "Object already has handle"
        cdef service_h hdl
        cdef int err = SERVICE_ERROR_NONE
        if handle == NULL:
            err = service_create(&hdl)
        else:
            if clone:
                err = service_clone(&hdl, handle)
            else:
                hdl = handle

        self._handle = hdl
        return err

    cdef service_h _get_handle(self) except NULL:
        return self._handle

    def __del__(self):
        service_destroy(self._handle)

    property app_id:
        def __get__(self):
            assert self._handle != NULL, "Service handle is NULL!"
            ret = None
            cdef char *cstr = NULL
            cdef int err = service_get_app_id(self._handle, &cstr)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)
            try:
                ret = _ctouni(cstr)
            finally:
                free(cstr)
            return ret

        def __set__(self, val):
            assert self._handle == NULL, "Service handle is NULL!"
            cdef char *cstr = _fruni(val)
            cdef err = service_set_app_id(self._handle, cstr)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)

    property category:
        def __get__(self):
            assert self._handle != NULL, "Service handle is NULL!"
            cdef char *cstr = NULL
            cdef int err = service_get_category(self._handle, &cstr)
            ret = None
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)
            try:
                ret = _ctouni(cstr)
            finally:
                free(cstr)
            return ret

        def __set__(self, val):
            assert self._handle != NULL, "Service handle is NULL!"
            cdef char *cstr = _fruni(val)
            cdef err = service_set_app_id(self._handle, cstr)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)

    property mime:
        def __get__(self):
            assert self._handle != NULL, "Service handle is NULL!"
            cdef char *cstr = NULL
            cdef int err = service_get_mime(self._handle, &cstr)
            ret = None
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)
            try:
                ret = _ctouni(cstr)
            finally:
                free(cstr)
            return ret

        def __set__(self, val):
            assert self._handle != NULL, "Service handle is NULL!"
            cdef char *cstr = _fruni(val)
            cdef err = service_set_mime(self._handle, cstr)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)

    property operation:
        def __get__(self):
            assert self._handle != NULL, "Service handle is NULL!"
            ret = None
            cdef char *cstr = NULL
            cdef int err = service_get_operation(self._handle, &cstr)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)
            try:
                ret = _ctouni(cstr)
            finally:
                free(cstr)
            return ret

        def __set__(self, val):
            assert self._handle != NULL, "Service handle is NULL!"
            cdef char *cstr = _fruni(val)
            cdef err = service_set_operation(self._handle, cstr)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)

    property uri:
        def __get__(self):
            assert self._handle != NULL, "Service handle is NULL!"
            ret = None
            cdef char *cstr = NULL
            cdef int err = service_get_uri(self._handle, &cstr)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)
            try:
                ret = _ctouni(cstr)
            finally:
                free(cstr)
            return ret

        def __set__(self, val):
            cdef char *cstr = _fruni(val)
            cdef err = service_set_uri(self._handle, cstr)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)

    property window:
        def __get__(self):
            cdef unsigned int cint
            cdef int err = service_get_window(self._handle, &cint)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)
            return int(cint)

        def __set__(self, val):
            cdef unsigned int cint = int(val)
            cdef err = service_set_window(self._handle, cint)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)

    property caller:
        def __get__(self):
            ret = None
            cdef char *cstr = NULL
            cdef int err = service_get_caller(self._handle, &cstr)
            if err != APP_ERROR_NONE:
                raise TizenServiceError(err)
            try:
                ret = _ctouni(cstr)
            finally:
                free(cstr)
            return ret

    def is_reply_requested(self):
        cdef int ret
        cdef int err = service_is_reply_requested(self._handle, &ret)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        return bool(ret)

    property data:
        def __get__(self):
            data = {}
            cdef int err = service_foreach_extra_data(self._handle,
                                 _service_foreach_key, <void*>data)
            if err != SERVICE_ERROR_NONE:
                raise TizenServiceError(err)
            return data

        def __set__(self, value):
            cdef char *ckey, *cvalue
            cdef char **cavalues
            cdef int err

            if not isinstance(value, dict):
                raise TizenError("Service data has to be a dictionary!")

            err = service_foreach_extra_data(self._handle, _service_foreach_key_del, NULL)
            if err != SERVICE_ERROR_NONE:
                raise TizenServiceError(err)

            for key, val in value.iteritems():
                ckey = _fruni(key)
                if isinstance(val, list):
                    try:
                        cavalues = <char**>malloc(len(val) * sizeof(char *))
                        for i in range(len(val)):
                            cavalues[i] = _fruni(val[i])
                        err = service_add_extra_data_array(self._handle, ckey,
                                                      cavalues, int(len(val)))
                    finally:
                        free(cavalues)
                    if err != SERVICE_ERROR_NONE:
                        raise TizenServiceError(err)
                elif isinstance(val, str):
                    cvalue = _fruni(val)
                    err = service_add_extra_data(self._handle, ckey, cvalue)
                    if err != SERVICE_ERROR_NONE:
                        raise TizenServiceError(err)
                else:
                    log.error("Invalid service error key data. Expecting strings or"
                              "list of strings. Skipping data for key %s" % key)

    def get_matching_apps(self):
        ret = []
        cdef int err = service_foreach_app_matched(self._handle, _service_math_cb, <void*>ret)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        return ret


cdef class Alarm:
    cdef int _id
    def __cinit__(self):
        self._id = 0

    def _set_id(self, id):
        self._id = id

    def cancel(self):
        if not self._id:
            return
        cdef err = alarm_cancel(self._id)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        self._id = None

    def service(self):
        if not self._id:
            return
        cdef service_h service
        cdef err = alarm_get_service(self._id, &service)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        srv = Service()
        srv._set_handle(handle=service)
        return srv

    @property
    def date(self):
        cdef tm ctime
        cdef err, period
        if not self._id:
            return None
        err = alarm_get_scheduled_date(self._id, &ctime)
        if err != ALARM_ERROR_NONE:
            raise TizenAlarmError(err)
        ctime.tm_year + 1900
        ctime.tm_mon + 1
        return ctime

    @property
    def period(self):
        cdef int err, period
        if not self._id:
            return None
        err = alarm_get_scheduled_period(self._id, &period)
        if err != ALARM_ERROR_NONE:
            raise TizenAlarmError(err)
        return period

    @property
    def week_flags(self):
        ret = []
        cdef int err, flags
        if not self._id:
            return None
        err = alarm_get_scheduled_recurrence_week_flag(self._id, &flags)
        if err != ALARM_ERROR_NONE:
            raise TizenAlarmError(err)
        for i in range(7):
            if flags & (0x1 << i) > 0:
                ret.appned(i)
        return ret

    def schedule(self, service, date, period=None, week_flags=None):
        cdef int err, alarm_id, flags = 0
        cdef tm tm_time
        if self._id:
            raise TizenError("Alarm already scheduled!")

        tm_time = _python_time_to_struct_tm(date)

        if (period is not None and week_flags) or not (period is not None or week_flags):
            raise TypeError("Please set period or week_flags")

        if period is not None:
            if not isinstance(period, int):
                raise TypeError("Tizen Alarm requires int type as period value.")
            err = alarm_schedule_at_date(Service._get_handle(service), &tm_time, period,
                                         &alarm_id)
        elif week_flags:
            for v in week_flags:
                if not isinstance(v, int) or v < 0 or v > 6:
                    raise TypeError("Week flags should be a list of integers, where"
                                    " every int: 0 <= i <= 6")
                _week_flags = list(set(week_flags))
                for wf in _week_flags:
                    flags = flags | (0x01 << wf)
                err = alarm_schedule_with_recurrence_week_flag(
                            Service._get_handle(service),
                            &tm_time, flags, &alarm_id)

        if err != ALARM_ERROR_NONE:
            raise TizenAlarmError(err)
        self._id = alarm_id


cdef tm _python_time_to_struct_tm(time):
    if not isinstance(time, datetime):
        raise TypeError('Not a Datetime object!')
    cdef tm ctime
    ctime.tm_sec = time.second
    ctime.tm_min = time.minute
    ctime.tm_hour = time.hour
    ctime.tm_mday = time.day
    ctime.tm_mon = time.month - 1
    ctime.tm_year = time.year - 1900
    ctime.tm_wday = time.weekday()
    diff = time - datetime(time.year, 1, 1)
    ctime.tm_yday = diff.days
    ctime.tm_isdst = 0
    return ctime


cdef object _struct_tm_to_python_time(tm ctime):
    return datetime.fromtimestamp(mktime(ctime))


cdef class Notification:
    def __init__(self, ongoing=False, handle=None, noclone=False):
        cdef int err = UI_NOTIFICATION_ERROR_NONE
        cdef ui_notification_h noti
        if handle:
            if noclone:
                noti = handle
            else:
                err = ui_notification_clone(&noti, handle)
        else:
            err = ui_notification_create(bool(ongoing), &noti)

        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._handle = noti

    def __del__(self):
        ui_notification_destroy(self._handle)

    @property
    def title(self):
        cdef int err
        cdef char *cstr
        cdef bytes ret
        if self._title:
            return self._title
        err = ui_notification_get_title(self._handle, &cstr)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        try:
            ret = cstr
        finally:
            free(cstr)
        self._title = ret
        return ret

    @title.setter
    def title(self, value):
        cdef int err
        cdef char *cstr
        cstr = _fruni(value)
        err = ui_notification_set_title(self._handle, cstr)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._title = cstr

    @property
    def content(self):
        cdef int err
        cdef char *cstr
        cdef bytes ret
        if self._content:
            return self._content
        err = ui_notification_get_content(self._handle, &cstr)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        try:
            ret = cstr
        finally:
            free(cstr)
        self._content = ret
        return ret

    @content.setter
    def content(self, value):
        cdef int err
        cdef char *cstr
        cstr = _fruni(value)
        err = ui_notification_set_content(self._handle, cstr)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._content = cstr

    @property
    def icon(self):
        cdef int err
        cdef char *cstr
        cdef bytes ret
        if self._icon:
            return self._icon
        err = ui_notification_get_content(self._handle, &cstr)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        try:
            ret = cstr
        finally:
            free(cstr)
        self._content = ret
        return ret

    @icon.setter
    def icon(self, value):
        cdef int err
        cdef char *cstr
        cstr = _fruni(value)
        err = ui_notification_set_icon(self._handle, cstr)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._icon = cstr

    @property
    def id(self):
        cdef int err, cid
        if self._id:
            return self._id
        err = ui_notification_get_id(self._handle, &cid)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._id = cid
        return cid

    @property
    def service(self):
        cdef int err
        cdef service_h serv
        if self._service:
            return self._service
        err = ui_notification_get_service(self._handle, &serv)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        pserv = Service()
        pserv._set_handle(handle=serv, clone=False)
        return pserv

    @service.setter
    def service(self, value):
        cdef int err
        err = ui_notification_set_service(self._handle,
                Service._get_handle(value))
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._service = value

    @property
    def time(self):
        cdef int err
        cdef tm *ctim
        if self._time:
            return self._time
        err = ui_notification_get_time(self._handle, &ctim)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        try:
            self._time = _struct_tm_to_python_time(deref(ctim))
        finally:
            free(ctim)
        return self._time

    @time.setter
    def time(self, value):
        cdef int err
        cdef tm ctim = _python_time_to_struct_tm(value)
        err = ui_notification_set_time(self._handle, &ctim)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._time = ctim

    @property
    def sound(self):
        cdef int err
        cdef char *cstr
        cdef bytes ret
        if self._sound is None:
            return self._sound
        err = ui_notification_get_sound(self._handle, &cstr)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        try:
            ret = cstr
        finally:
            free(cstr)
        self._sound = ret
        return ret

    @sound.setter
    def sound(self, value):
        cdef int err
        cdef char *cstr
        cstr = _fruni(value)
        err = ui_notification_set_sound(self._handle, cstr)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._sound = cstr

    @property
    def vibration(self):
        cdef int err
        cdef int ret
        if self._vibration is None:
            return self._vibration
        err = ui_notification_get_vibration(self._handle, &ret)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._vibration = bool(ret)
        return self._vibration

    @vibration.setter
    def vibration(self, value):
        cdef int err
        cdef bool vib
        vib = bool(value)
        err = ui_notification_set_vibration(self._handle, vib)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
        self._vibration = vib

    @property
    def ongoing(self):
        cdef int err
        cdef int ison
        if self._ongoing is None:
            err = ui_notification_is_ongoing(self._handle, &ison)
            if err != UI_NOTIFICATION_ERROR_NONE:
                raise TizenNotificationError(err)
            self._ongoing = bool(ison)
        return self._ongoing

    def post(self, title=None, content=None, ):
        cdef int err
        err = ui_notification_post(self._handle)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)

    def update(self, value=0):
        cdef int err
        if value == 0:
            err = ui_notification_update(self._handle)
        else:
            err = ui_notification_update_progress(self._handle,
                        UI_NOTIFICATION_PROGRESS_TYPE_PERCENTAGE,
                        value)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)

    def cancel(self):
        cdef err
        err = ui_notification_cancel(self._handle)
        if err != UI_NOTIFICATION_ERROR_NONE:
            raise TizenNotificationError(err)
