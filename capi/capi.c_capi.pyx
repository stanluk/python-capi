from cpython cimport PyMem_Malloc, PyMem_Free
from cpython cimport bool

import sys
import logging

logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger("capi")


class TizenException(Exception):
    def __init__(self, msg):
        self.message = msg

    def __str__(self):
        return self.message


class TizenAppException(TizenException):
    TIZEN_APP_ERRORS = {
        APP_ERROR_NONE: "Successful",
        APP_ERROR_INVALID_PARAMETER: "Invalid parameter",
        APP_ERROR_OUT_OF_MEMORY: "Out of memory",
        APP_ERROR_INVALID_CONTEXT: "Invalid application context",
        APP_ERROR_NO_SUCH_FILE: "No such file or directory",
        APP_ERROR_ALREADY_RUNNING: "Application is already running"
    }

    def __init__(self, error):
        self.error_code = error
        self.message = TizenAppException.TIZEN_APP_ERRORS[self.error_code]


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
    return bool(inst.create())


cdef void on_pause(void *cls) with gil:
    cdef object inst = <object>cls
    inst.pause()


cdef void on_resume(void *cls) with gil:
    cdef object inst = <object>cls
    inst.resume()


cdef void on_terminate(void *cls) with gil:
    cdef object inst = <object>cls
    inst.terminate()


cdef void on_service(service_h service, void *cls) with gil:
    cdef object inst = <object>cls
    inst.service()


cdef void on_low_memory(void *cls) with gil:
    cdef object inst = <object>cls
    inst.low_memory()


cdef void on_low_battery(void *cls) with gil:
    cdef object inst = <object>cls
    inst.low_battery()


cdef void on_device_orientation_change(app_device_orientation_e orient, void *cls) with gil:
    cdef object inst = <object>cls
    inst.app_device_orientation_change(orient)


cdef void on_language_changed(void *cls) with gil:
    cdef object inst = <object>cls
    inst.language_changed()


cdef void on_region_format_changed(void *cls) with gil:
    cdef object inst = <object>cls
    inst.region_format_changed()


cdef class TizenEflApp:
    def __init__(self):
        pass

    def create(self):
        return True

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

        if err != APP_ERROR_NONE:
            raise TizenAppException(err)

    def exit(self):
        app_efl_exit()

    @property
    def package(self):
        cdef bytes pypackage
        cdef char *package
        cdef int err = app_get_package(&package)
        if err != APP_ERROR_NONE:
            raise TizenAppException(err)
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
            raise TizenAppException(err)
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
            raise TizenAppException(err)
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
            raise TizenAppException(err)
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
            raise TizenException("Getting '%s' resource path failed." % resource)
        pystr = cstr
        return pystr

    @property
    def data_dir(self):
        cdef bytes pystr
        # FIXME issues with buffer len
        cdef char cstr[1024]
        cdef char *res = app_get_data_directory(cstr, sizeof(cstr))
        if res == NULL:
            raise TizenException("Getting data directory failed.")
        pystr = cstr
        return pystr

    @property
    def device_orientation(self):
        return app_get_device_orientation()

    def reclaim_system_cache(self, val):
        app_set_reclaiming_system_cache_on_pause(bool(val))

