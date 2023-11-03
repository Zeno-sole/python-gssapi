GSSAPI="BASE"  # This ensures that a full module is generated by Cython

from gssapi.raw.cython_types cimport *
from gssapi.raw.sec_contexts cimport SecurityContext

from gssapi.raw.misc import GSSError
from gssapi.raw.named_tuples import WrapResult, UnwrapResult


cdef extern from "python_gssapi_ext.h":
    OM_uint32 gss_wrap_aead(OM_uint32 *min_stat, gss_ctx_id_t ctx_handle,
                            int conf_req, gss_qop_t qop_req,
                            gss_buffer_t input_assoc_buffer,
                            gss_buffer_t input_payload_buffer, int *conf_ret,
                            gss_buffer_t output_message_buffer) nogil

    OM_uint32 gss_unwrap_aead(OM_uint32 *min_stat, gss_ctx_id_t ctx_handle,
                              gss_buffer_t input_message_buffer,
                              gss_buffer_t input_assoc_buffer,
                              gss_buffer_t output_payload_buffer,
                              int *conf_ret, gss_qop_t *qop_ret) nogil


def wrap_aead(SecurityContext context not None, bytes message not None,
              bytes associated=None, confidential=True, qop=None):
    cdef int conf_req = confidential
    cdef gss_qop_t qop_req = qop if qop is not None else GSS_C_QOP_DEFAULT
    cdef gss_buffer_desc message_buffer = gss_buffer_desc(len(message),
                                                          message)

    cdef gss_buffer_t assoc_buffer_ptr = GSS_C_NO_BUFFER
    cdef gss_buffer_desc assoc_buffer
    if associated is not None:
        assoc_buffer = gss_buffer_desc(len(associated), associated)
        assoc_buffer_ptr = &assoc_buffer

    cdef int conf_used
    # GSS_C_EMPTY_BUFFER
    cdef gss_buffer_desc output_buffer = gss_buffer_desc(0, NULL)

    cdef OM_uint32 maj_stat, min_stat

    with nogil:
        maj_stat = gss_wrap_aead(&min_stat, context.raw_ctx, conf_req, qop_req,
                                 assoc_buffer_ptr, &message_buffer,
                                 &conf_used, &output_buffer)

    if maj_stat == GSS_S_COMPLETE:
        output_message = (<char*>output_buffer.value)[:output_buffer.length]
        gss_release_buffer(&min_stat, &output_buffer)
        return WrapResult(output_message, <bint>conf_used)
    else:
        raise GSSError(maj_stat, min_stat)


def unwrap_aead(SecurityContext context not None, bytes message not None,
                bytes associated=None):
    cdef gss_buffer_desc input_buffer = gss_buffer_desc(len(message), message)

    cdef gss_buffer_t assoc_buffer_ptr = GSS_C_NO_BUFFER
    cdef gss_buffer_desc assoc_buffer
    if associated is not None:
        assoc_buffer = gss_buffer_desc(len(associated), associated)
        assoc_buffer_ptr = &assoc_buffer

    # GSS_C_EMPTY_BUFFER
    cdef gss_buffer_desc output_buffer = gss_buffer_desc(0, NULL)
    cdef int conf_state
    cdef gss_qop_t qop_state

    cdef OM_uint32 maj_stat, min_stat

    with nogil:
        maj_stat = gss_unwrap_aead(&min_stat, context.raw_ctx, &input_buffer,
                                   assoc_buffer_ptr, &output_buffer,
                                   &conf_state, &qop_state)

    if maj_stat == GSS_S_COMPLETE:
        output_message = (<char*>output_buffer.value)[:output_buffer.length]
        gss_release_buffer(&min_stat, &output_buffer)
        return UnwrapResult(output_message, <bint>conf_state, qop_state)
    else:
        raise GSSError(maj_stat, min_stat)
