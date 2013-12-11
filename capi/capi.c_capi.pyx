from cpython cimport PyMem_Malloc, PyMem_Free
from cpython cimport bool

import sys
import logging

logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger("capi")


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
        srv = ServiceRequest(handle=service)
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

cdef bool _alarm_registered_alarm_cb(int alarm_id, void *user_data):
    cdef object alarms = <object>user_data
    alarm = Alarm(alarm_id)
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
        Service.__init__(self)
        cdef service_h service
        if not isinstance(request, Service):
            raise TizenError("Invalid type: request Service instance")
        err = service_clone(&service, <service_h>request._service)
        self._request = service
        if err != SERVICE_ERROR_NONE:
            raise TizenServiceError(err)

    def __del__(self):
        Service.__del__(self)
        service_destroy(self._request)

    def send(self, value):
        cdef int err = service_reply_to_launch_request(self._service, self._request, value)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)


cdef void _service_reply_cb(service_h request, service_h reply, service_result_e result, void *user_data):
    cdef object inst = <object>user_data
    answer = Service(reply)
    inst.request_handler(answer, result)


cdef class ServiceRequest(Service):
    def __init__(self, handle=None):
        Service.__init__(self, <service_h>handle)

    def request_handler(self, result):
        pass

    def send(self):
        cdef int err = service_send_launch_request(self._service, _service_reply_cb, <void*>self)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)


cdef class Service:
    def __cinit__(self, service_h handle):
        cdef int err
        cdef service_h service

        if <void*>handle == NULL:
            err = service_create(&service)
        else:
            err = service_clone(&service, handle)

        if err != SERVICE_ERROR_NONE:
            raise TizenServiceError(err)

        self._service = service

    def __del__(self):
        service_destroy(self._service)

    @property
    def app_id(self):
        cdef bytes pystr
        cdef char *cstr
        cdef int err = service_get_app_id(self._service, &cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        try:
            pystr = cstr
        finally:
            free(cstr)
        return pystr

    @app_id.setter
    def app_id(self, val):
        cdef char *cstr = _fruni(val)
        cdef err = service_set_app_id(self._service, cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)

    @property
    def category(self):
        cdef bytes pystr
        cdef char *cstr
        cdef int err = service_get_category(self._service, &cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        try:
            pystr = cstr
        finally:
            free(cstr)
        return pystr

    @category.setter
    def category(self, val):
        cdef char *cstr = _fruni(val)
        cdef err = service_set_app_id(self._service, cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)

    @property
    def mime(self):
        cdef bytes pystr
        cdef char *cstr
        cdef int err = service_get_mime(self._service, &cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        try:
            pystr = cstr
        finally:
            free(cstr)
        return pystr

    @mime.setter
    def mime(self, val):
        cdef char *cstr = _fruni(val)
        cdef err = service_set_mime(self._service, cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)

    @property
    def operation(self):
        cdef bytes pystr
        cdef char *cstr
        cdef int err = service_get_operation(self._service, &cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        try:
            pystr = cstr
        finally:
            free(cstr)
        return pystr

    @operation.setter
    def operation(self, val):
        cdef char *cstr = _fruni(val)
        cdef err = service_set_operation(self._service, cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)

    @property
    def uri(self):
        cdef bytes pystr
        cdef char *cstr
        cdef int err = service_get_uri(self._service, &cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        try:
            pystr = cstr
        finally:
            free(cstr)
        return pystr

    @uri.setter
    def uri(self, val):
        cdef char *cstr = _fruni(val)
        cdef err = service_set_uri(self._service, cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)

    @property
    def window(self):
        cdef unsigned int cint
        cdef int err = service_get_window(self._service, &cint)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        return int(cint)

    @window.setter
    def window(self, val):
        cdef unsigned int cint = int(val)
        cdef err = service_set_window(self._service, cint)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)

    @property
    def caller(self):
        cdef bytes pystr
        cdef char *cstr
        cdef int err = service_get_caller(self._service, &cstr)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        try:
            pystr = cstr
        finally:
            free(cstr)
        return pystr

    def is_reply_requested(self):
        cdef int ret
        cdef int err = service_is_reply_requested(self._service, &ret)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        return ret

    @property
    def data(self):
        data = {}
        cdef int err = service_foreach_extra_data(self._service, _service_foreach_key, <void*>data)
        if err != SERVICE_ERROR_NONE:
            raise TizenServiceError(err)
        return data

    @data.setter
    def data(self, value):
        cdef char *ckey, *cvalue
        cdef char **cavalues
        cdef int err

        if not isinstance(value, dict):
            raise TizenError("Service data has to be a dictionary!")

        err = service_foreach_extra_data(self._service, _service_foreach_key_del, NULL)
        if err != SERVICE_ERROR_NONE:
            raise TizenServiceError(err)

        for key, val in value.iteritems():
            ckey = _fruni(key)
            if isinstance(val, list):
                try:
                    cavalues = <char**>malloc(len(val) * sizeof(char *))
                    for i in range(len(val)):
                        cavalues[i] = _fruni(val[i])
                    err = service_add_extra_data_array(self._service, ckey, cavalues, int(len(val)))
                finally:
                    free(cavalues)
                if err != SERVICE_ERROR_NONE:
                    raise TizenServiceError(err)
            elif isinstance(val, str):
                cvalue = _fruni(val)
                err = service_add_extra_data(self._service, ckey, cvalue)
                if err != SERVICE_ERROR_NONE:
                    raise TizenServiceError(err)
            else:
                log.error("Invalid service error key data. Expecting strings or"
                          "list of strings. Skipping data for key %s" % key)

    def get_matching_apps(self):
        ret = []
        cdef int err = service_foreach_app_matched(self._service, _service_math_cb, <void*>ret)
        if err != APP_ERROR_NONE:
            raise TizenServiceError(err)
        return ret


cdef class Alarm:

    def __init__(self, id=None):
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
        return Service(service)

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

    cdef tm _python_time_to_struct_tm(self, time):
        cdef tm ctime
        ctime.tm_sec = int(time.tm_sec)
        ctime.tm_min = int(time.tm_min)
        ctime.tm_hour = int(time.tm_hour)
        ctime.tm_mday = int(time.tm_mday)
        ctime.tm_mon = int(time.tm_mon) - 1
        ctime.tm_year = int(time.tm_year) - 1900
        ctime.tm_wday = int(time.tm_wday)
        ctime.tm_yday = int(time.tm_yday)
        ctime.tm_isdst = int(time.tm_isdta)
        return ctime

    def schedule(self, service, date, period=None, week_flags=None):
        cdef int err, alarm_id, flags = 0
        cdef tm tm_time
        if self._id:
            raise TizenError("Alarm already scheduled!")

        tm_time = self._python_time_to_struct_tm(date)

        if (period and week_flags) or not (period or week_flags):
            raise TypeError("Please set period or week_flags")

        if period:
            if not isinstance(period, int):
                raise TypeError("Tizen Alarm requires int type as period value.")
            err = alarm_schedule_at_date(service._service, &tm_time, period,
                                         &alarm_id)
        elif week_flags:
            for v in week_flags:
                if not isinstance(v, int) or v < 0 or v > 6:
                    raise TypeError("Week flags should be a list of integers, where"
                                    " every int: 0 <= i <= 6")
                _week_flags = list(set(week_flags))
                for wf in _week_flags:
                    flags = flags | (0x01 << wf)
                err = alarm_schedule_with_recurrence_week_flag(service._service,
                        &tm_time, flags, &alarm_id)

        if err != ALARM_ERROR_NONE:
            raise TizenAlarmError(err)
        self._id = alarm_id
