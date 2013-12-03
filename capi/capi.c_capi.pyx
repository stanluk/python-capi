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
        inst.service(service)
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
