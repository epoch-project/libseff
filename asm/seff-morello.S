# Copyright (c) 2023 Huawei Technologies Co., Ltd.
# Copyright (c) 2024 Brian Campbell, University of Edinburgh
#
# libseff is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
# 	    http://license.coscl.org.cn/MulanPSL2
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND, EITHER
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT, MERCHANTABILITY OR
# FIT FOR A PARTICULAR PURPOSE.
# See the Mulan PSL v2 for more details.
#
# Architecture-specific code for context-switching
# This file is for the System V (Linux/OSX) 64 bit architecture
#

#include "dwarf.S"
#include "seff_types.S"

#ifdef STACK_POLICY_SEGMENTED
#error Segmented stacks not currently supported on Morello
#endif

.global seff_exit
.global seff_yield
.global seff_resume
.global coroutine_prelude

.type seff_exit,%function
.type seff_yield,%function
.type seff_resume,%function
.type coroutine_prelude,%function

.global _seff_current_coroutine
.global _seff_system_stack
.global _seff_paused_coroutine_stack

.section .tbss

# TODO: alignment?
_seff_current_coroutine:
    .zero 16
_seff_paused_coroutine_stack:
    .zero 16
_seff_system_stack:
    .zero 16
.size _seff_current_coroutine, 16
.size _seff_paused_coroutine_stack, 16
.size _seff_system_stack, 16

.macro swap_registers
    # Saved registers
    # TODO: ldp/stp?
    ldr c9, [c0, seff_coroutine_t__resume_point + seff_cont_t__r19]
    ldr c10, [c0, seff_coroutine_t__resume_point + seff_cont_t__r20]
    ldr c11, [c0, seff_coroutine_t__resume_point + seff_cont_t__r21]
    ldr c12, [c0, seff_coroutine_t__resume_point + seff_cont_t__r22]
    ldr c13, [c0, seff_coroutine_t__resume_point + seff_cont_t__r23]
    ldr c14, [c0, seff_coroutine_t__resume_point + seff_cont_t__r24]
    ldr c15, [c0, seff_coroutine_t__resume_point + seff_cont_t__r25]
    ldr c16, [c0, seff_coroutine_t__resume_point + seff_cont_t__r26]
    ldr c17, [c0, seff_coroutine_t__resume_point + seff_cont_t__r27]
    ldr c8, [c0, seff_coroutine_t__resume_point + seff_cont_t__r28]

    str c19, [c0, seff_coroutine_t__resume_point + seff_cont_t__r19]
    str c20, [c0, seff_coroutine_t__resume_point + seff_cont_t__r20]
    str c21, [c0, seff_coroutine_t__resume_point + seff_cont_t__r21]
    str c22, [c0, seff_coroutine_t__resume_point + seff_cont_t__r22]
    str c23, [c0, seff_coroutine_t__resume_point + seff_cont_t__r23]
    str c24, [c0, seff_coroutine_t__resume_point + seff_cont_t__r24]
    str c25, [c0, seff_coroutine_t__resume_point + seff_cont_t__r25]
    str c26, [c0, seff_coroutine_t__resume_point + seff_cont_t__r26]
    str c27, [c0, seff_coroutine_t__resume_point + seff_cont_t__r27]
    str c28, [c0, seff_coroutine_t__resume_point + seff_cont_t__r28]

    # TODO: avoid leaving copies lying around
    mov c19, c9
    mov c20, c10
    mov c21, c11
    mov c22, c12
    mov c23, c13
    mov c24, c14
    mov c25, c15
    mov c26, c16
    mov c27, c17
    mov c28, c8
.endm

.macro swap_stack
    ldr c10, [c0, seff_coroutine_t__resume_point + seff_cont_t__rbp]
    ldr c11, [c0, seff_coroutine_t__resume_point + seff_cont_t__rsp]

    str c29, [c0, seff_coroutine_t__resume_point + seff_cont_t__rbp]
    mov c29, csp
    str c29, [c0, seff_coroutine_t__resume_point + seff_cont_t__rsp]

    mov c29, c10
    mov csp, c11
.endm

.text

# void* seff_yield(seff_coroutine_t* self, void* arg)
seff_yield:
    .cfi_startproc
    # self in c0
    # arg1 in c1
    # arg2 in c2

    swap_registers

    # We get to pummel c3-c15 so we use those for fast swaps

    mrs c9, CTPIDR_EL0

    add c9, c9, :tprel_hi12:_seff_current_coroutine
    add c9, c9, :tprel_lo12_nc:_seff_current_coroutine
    # Keep c9 for later
    ldr c4, [c9]

    ldr c6, [c0, seff_coroutine_t__parent_coroutine]

    # _seff_current_coroutine
    str c6, [c9]

    str c4, [c0, seff_coroutine_t__resume_point + seff_cont_t__current_coroutine]

    # Save return pointer
    mov c3, c30
    ldr c30, [c0, seff_coroutine_t__resume_point + seff_cont_t__ip]
    str c3, [c0, seff_coroutine_t__resume_point + seff_cont_t__ip]

    swap_stack

    mov c0, c1
    mov c1, c2
    ret
    .cfi_endproc
.size seff_yield, . - seff_yield

# void* seff_resume(seff_coroutine_t* k, void* arg, effect_set handled)
seff_resume:
    .cfi_startproc
    # k in c0
    # arg in c1
    # handled in x2
    str x2, [c0, seff_coroutine_t__handled_effects]

    swap_registers

    # We get to pummel x3-x15 so we use those for fast swaps

    mrs c9, CTPIDR_EL0

    add c10, c9, :tprel_hi12:_seff_current_coroutine
    add c10, c10, :tprel_lo12_nc:_seff_current_coroutine
    ldr c4, [c10]

    ldr c6, [c0, seff_coroutine_t__resume_point + seff_cont_t__current_coroutine]

    str c6, [c10] /* _seff_current_coroutine */

    str c4, [c0, seff_coroutine_t__parent_coroutine]

    # Save return pointer
    mov c3, c30
    ldr c30, [c0, seff_coroutine_t__resume_point + seff_cont_t__ip]
    str c3, [c0, seff_coroutine_t__resume_point + seff_cont_t__ip]

    # At this point, the stack is aligned on a 16-byte boundary, so we use
    # this as the system stack if possible. Note that we need to do this
    # before clobbering x4
    cbnz x4, seff_resume_after_store_system_stack
    add c10, c9, :tprel_hi12:_seff_system_stack
    add c10, c10, :tprel_lo12_nc:_seff_system_stack
    mov c11, csp
    str c11, [c10]
seff_resume_after_store_system_stack:

    # Stack
    swap_stack

    mov c0, c1
    ret
    .cfi_endproc
.size seff_resume, . - seff_resume

# void coroutine_prelude(seff_coroutine_t *k, seff_start_fun_t *fn, void *arg);
# k in x26
# arg in x27
# fn in x28
coroutine_prelude:
    .cfi_startproc
    # needed or else gdb does not allow switching frames to a lower address in the backtrace
    .cfi_signal_frame

    # At this point we are already at a new stack frame, we need to recover the CFA from x26
    .cfi_escape DW_CFA_def_cfa_expression, 2, DW_OP_breg(DW_REG_aarch64_r26), seff_coroutine_t__resume_point
    # And then every other register from its offset to CFA
    .cfi_offset c30, seff_cont_t__ip
    .cfi_offset csp, seff_cont_t__rsp
    .cfi_offset c29, seff_cont_t__rbp
    .cfi_offset c19, seff_cont_t__r19
    .cfi_offset c20, seff_cont_t__r20
    .cfi_offset c21, seff_cont_t__r21
    .cfi_offset c22, seff_cont_t__r22
    .cfi_offset c23, seff_cont_t__r23
    .cfi_offset c24, seff_cont_t__r24
    .cfi_offset c25, seff_cont_t__r25
    .cfi_offset c26, seff_cont_t__r26
    .cfi_offset c27, seff_cont_t__r27
    .cfi_offset c28, seff_cont_t__r28

    mov c0, c27
    # c26 is a callee-save register, so the debugger will continue to find the correct CFA

    blr c28
    # FALLTHROUGH TO SEFF_EXIT
    # set the return value to (seff_result_t){ 0xFF...FF, %rax }
    mov c2, c0
    mov c0, c26
    mov x1, #RETURN_EFFECT_ID
    .cfi_endproc
.size coroutine_prelude, . - coroutine_prelude

# void seff_exit(seff_coroutine_t* k, void* result)
seff_exit:
    .cfi_startproc
    # k in c0
    # eff_id in x1
    # result in c2
    mov x9, #seff_coroutine_state_t__FINISHED
    str x9, [c0, seff_coroutine_t__state]

    # TODO: it would be faster to avoid swapping, since we're never restarting this coroutine
    swap_registers

    ldr c9, [c0, seff_coroutine_t__parent_coroutine]
    mrs c10, CTPIDR_EL0
    add c10, c10, :tprel_hi12:_seff_current_coroutine
    add c10, c10, :tprel_lo12_nc:_seff_current_coroutine
    str c9, [c10]

    ldr c9, [c0, seff_coroutine_t__resume_point + seff_cont_t__ip]

    ldr c29, [c0, seff_coroutine_t__resume_point + seff_cont_t__rbp]
    ldr c10, [c0, seff_coroutine_t__resume_point + seff_cont_t__rsp]
    mov csp, c10

#ifndef NDEBUG
    # Cleaning up
    str xzr, [c0, seff_coroutine_t__resume_point + seff_cont_t__ip]

    str xzr, [c0, seff_coroutine_t__resume_point + seff_cont_t__rbp]
    str xzr, [c0, seff_coroutine_t__resume_point + seff_cont_t__rsp]
#endif

    mov x0, x1
    mov c1, c2
    br c9
    .cfi_endproc
.size seff_exit, . - seff_exit
