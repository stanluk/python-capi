from cpython cimport PyMem_Malloc, PyMem_Free
from cpython cimport bool

import sys
import logging

logging.basicConfig(level=logging.DEBUG)
log = logging.getLogger("capi")


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

        app_efl_main(&argc, &argv, &cbs, <void*>self)

    def exit(self):
        app_efl_exit()
