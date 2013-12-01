from cpython cimport PyMem_Malloc, PyMem_Free
from cpython cimport bool

import sys
import logging

logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger("capi")


class TizenException(Exception):
    pass


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
        self._error = error

    def __str__(self):
        return repr(TizenAppException.TIZEN_APP_ERRORS[self._error])


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

cdef bool on_create(void *cls):
    cdef object inst = <object>cls
    return bool(inst.on_create)

cdef class TizenEflApp:

    def on_create(self):
        return True

    def run(self):
        cdef int argc, i, arg_len
        cdef char **argv, *arg
        cdef app_event_callback_s cbs
        memset(&cbs, 0x0, sizeof(cbs))
        cbs.create = on_create
        argc = len(sys.argv)
        argv = <char **>PyMem_Malloc(argc * sizeof(char *))
        for i from 0 <= i < argc:
            arg = _fruni(sys.argv[i])
            arg_len = len(arg)
            argv[i] = <char *>PyMem_Malloc(arg_len + 1)
            memcpy(argv[i], arg, arg_len + 1)

        i = app_efl_main(&argc, &argv, &cbs, <void*>self)
        if i != 0:
            raise TizenAppException(i)

    def exit(self):
        app_efl_exit()
