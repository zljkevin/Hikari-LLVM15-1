; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=i686-unknown-unknown -mattr=+sse2 | FileCheck %s --check-prefix=X86
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+sse2 | FileCheck %s --check-prefix=X64
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+f16c | FileCheck %s --check-prefix=F16C
; RUN: llc < %s -mtriple=x86_64-unknown-unknown -mattr=+f16c -O0 | FileCheck %s --check-prefix=F16C-O0

define <1 x half> @ir_fadd_v1f16(<1 x half> %arg0, <1 x half> %arg1) nounwind {
; X86-LABEL: ir_fadd_v1f16:
; X86:       # %bb.0:
; X86-NEXT:    subl $28, %esp
; X86-NEXT:    movups %xmm1, {{[-0-9]+}}(%e{{[sb]}}p) # 16-byte Spill
; X86-NEXT:    pextrw $0, %xmm0, %eax
; X86-NEXT:    movw %ax, (%esp)
; X86-NEXT:    calll __extendhfsf2
; X86-NEXT:    movdqu {{[-0-9]+}}(%e{{[sb]}}p), %xmm0 # 16-byte Reload
; X86-NEXT:    pextrw $0, %xmm0, %eax
; X86-NEXT:    movw %ax, (%esp)
; X86-NEXT:    fstps {{[0-9]+}}(%esp)
; X86-NEXT:    calll __extendhfsf2
; X86-NEXT:    fstps {{[0-9]+}}(%esp)
; X86-NEXT:    movss {{.*#+}} xmm0 = mem[0],zero,zero,zero
; X86-NEXT:    addss {{[0-9]+}}(%esp), %xmm0
; X86-NEXT:    movss %xmm0, (%esp)
; X86-NEXT:    calll __truncsfhf2
; X86-NEXT:    addl $28, %esp
; X86-NEXT:    retl
;
; X64-LABEL: ir_fadd_v1f16:
; X64:       # %bb.0:
; X64-NEXT:    subq $40, %rsp
; X64-NEXT:    movaps %xmm0, {{[-0-9]+}}(%r{{[sb]}}p) # 16-byte Spill
; X64-NEXT:    movaps %xmm1, %xmm0
; X64-NEXT:    callq __extendhfsf2@PLT
; X64-NEXT:    movss %xmm0, {{[-0-9]+}}(%r{{[sb]}}p) # 4-byte Spill
; X64-NEXT:    movaps {{[-0-9]+}}(%r{{[sb]}}p), %xmm0 # 16-byte Reload
; X64-NEXT:    callq __extendhfsf2@PLT
; X64-NEXT:    addss {{[-0-9]+}}(%r{{[sb]}}p), %xmm0 # 4-byte Folded Reload
; X64-NEXT:    callq __truncsfhf2@PLT
; X64-NEXT:    addq $40, %rsp
; X64-NEXT:    retq
;
; F16C-LABEL: ir_fadd_v1f16:
; F16C:       # %bb.0:
; F16C-NEXT:    vpextrw $0, %xmm0, %eax
; F16C-NEXT:    vpextrw $0, %xmm1, %ecx
; F16C-NEXT:    movzwl %cx, %ecx
; F16C-NEXT:    vmovd %ecx, %xmm0
; F16C-NEXT:    vcvtph2ps %xmm0, %xmm0
; F16C-NEXT:    movzwl %ax, %eax
; F16C-NEXT:    vmovd %eax, %xmm1
; F16C-NEXT:    vcvtph2ps %xmm1, %xmm1
; F16C-NEXT:    vaddss %xmm0, %xmm1, %xmm0
; F16C-NEXT:    vcvtps2ph $4, %xmm0, %xmm0
; F16C-NEXT:    vmovd %xmm0, %eax
; F16C-NEXT:    vpinsrw $0, %eax, %xmm0, %xmm0
; F16C-NEXT:    retq
;
; F16C-O0-LABEL: ir_fadd_v1f16:
; F16C-O0:       # %bb.0:
; F16C-O0-NEXT:    vpextrw $0, %xmm1, %eax
; F16C-O0-NEXT:    # kill: def $ax killed $ax killed $eax
; F16C-O0-NEXT:    movzwl %ax, %eax
; F16C-O0-NEXT:    vmovd %eax, %xmm1
; F16C-O0-NEXT:    vcvtph2ps %xmm1, %xmm1
; F16C-O0-NEXT:    vpextrw $0, %xmm0, %eax
; F16C-O0-NEXT:    # kill: def $ax killed $ax killed $eax
; F16C-O0-NEXT:    movzwl %ax, %eax
; F16C-O0-NEXT:    vmovd %eax, %xmm0
; F16C-O0-NEXT:    vcvtph2ps %xmm0, %xmm0
; F16C-O0-NEXT:    vaddss %xmm1, %xmm0, %xmm0
; F16C-O0-NEXT:    vcvtps2ph $4, %xmm0, %xmm0
; F16C-O0-NEXT:    vmovd %xmm0, %eax
; F16C-O0-NEXT:    movw %ax, %cx
; F16C-O0-NEXT:    # implicit-def: $eax
; F16C-O0-NEXT:    movw %cx, %ax
; F16C-O0-NEXT:    # implicit-def: $xmm0
; F16C-O0-NEXT:    vpinsrw $0, %eax, %xmm0, %xmm0
; F16C-O0-NEXT:    retq
  %retval = fadd <1 x half> %arg0, %arg1
  ret <1 x half> %retval
}

define <2 x half> @ir_fadd_v2f16(<2 x half> %arg0, <2 x half> %arg1) nounwind {
; X86-LABEL: ir_fadd_v2f16:
; X86:       # %bb.0:
; X86-NEXT:    subl $84, %esp
; X86-NEXT:    movdqu %xmm0, {{[-0-9]+}}(%e{{[sb]}}p) # 16-byte Spill
; X86-NEXT:    psrld $16, %xmm0
; X86-NEXT:    movdqu %xmm0, {{[-0-9]+}}(%e{{[sb]}}p) # 16-byte Spill
; X86-NEXT:    movdqa %xmm1, %xmm0
; X86-NEXT:    psrld $16, %xmm0
; X86-NEXT:    movdqu %xmm0, {{[-0-9]+}}(%e{{[sb]}}p) # 16-byte Spill
; X86-NEXT:    pextrw $0, %xmm1, %eax
; X86-NEXT:    movw %ax, (%esp)
; X86-NEXT:    calll __extendhfsf2
; X86-NEXT:    fstpt {{[-0-9]+}}(%e{{[sb]}}p) # 10-byte Folded Spill
; X86-NEXT:    movdqu {{[-0-9]+}}(%e{{[sb]}}p), %xmm0 # 16-byte Reload
; X86-NEXT:    pextrw $0, %xmm0, %eax
; X86-NEXT:    movw %ax, (%esp)
; X86-NEXT:    calll __extendhfsf2
; X86-NEXT:    fstpt {{[-0-9]+}}(%e{{[sb]}}p) # 10-byte Folded Spill
; X86-NEXT:    movdqu {{[-0-9]+}}(%e{{[sb]}}p), %xmm0 # 16-byte Reload
; X86-NEXT:    pextrw $0, %xmm0, %eax
; X86-NEXT:    movw %ax, (%esp)
; X86-NEXT:    calll __extendhfsf2
; X86-NEXT:    movdqu {{[-0-9]+}}(%e{{[sb]}}p), %xmm0 # 16-byte Reload
; X86-NEXT:    pextrw $0, %xmm0, %eax
; X86-NEXT:    movw %ax, (%esp)
; X86-NEXT:    fstps {{[0-9]+}}(%esp)
; X86-NEXT:    fldt {{[-0-9]+}}(%e{{[sb]}}p) # 10-byte Folded Reload
; X86-NEXT:    fstps {{[0-9]+}}(%esp)
; X86-NEXT:    calll __extendhfsf2
; X86-NEXT:    movss {{.*#+}} xmm0 = mem[0],zero,zero,zero
; X86-NEXT:    addss {{[0-9]+}}(%esp), %xmm0
; X86-NEXT:    movss %xmm0, (%esp)
; X86-NEXT:    fstps {{[0-9]+}}(%esp)
; X86-NEXT:    fldt {{[-0-9]+}}(%e{{[sb]}}p) # 10-byte Folded Reload
; X86-NEXT:    fstps {{[0-9]+}}(%esp)
; X86-NEXT:    calll __truncsfhf2
; X86-NEXT:    movups %xmm0, {{[-0-9]+}}(%e{{[sb]}}p) # 16-byte Spill
; X86-NEXT:    movss {{.*#+}} xmm0 = mem[0],zero,zero,zero
; X86-NEXT:    addss {{[0-9]+}}(%esp), %xmm0
; X86-NEXT:    movss %xmm0, (%esp)
; X86-NEXT:    calll __truncsfhf2
; X86-NEXT:    movdqu {{[-0-9]+}}(%e{{[sb]}}p), %xmm1 # 16-byte Reload
; X86-NEXT:    punpcklwd {{.*#+}} xmm0 = xmm0[0],xmm1[0],xmm0[1],xmm1[1],xmm0[2],xmm1[2],xmm0[3],xmm1[3]
; X86-NEXT:    addl $84, %esp
; X86-NEXT:    retl
;
; X64-LABEL: ir_fadd_v2f16:
; X64:       # %bb.0:
; X64-NEXT:    subq $72, %rsp
; X64-NEXT:    movdqa %xmm1, {{[-0-9]+}}(%r{{[sb]}}p) # 16-byte Spill
; X64-NEXT:    movdqa %xmm0, {{[-0-9]+}}(%r{{[sb]}}p) # 16-byte Spill
; X64-NEXT:    psrld $16, %xmm0
; X64-NEXT:    movdqa %xmm0, {{[-0-9]+}}(%r{{[sb]}}p) # 16-byte Spill
; X64-NEXT:    movdqa %xmm1, %xmm0
; X64-NEXT:    psrld $16, %xmm0
; X64-NEXT:    callq __extendhfsf2@PLT
; X64-NEXT:    movd %xmm0, {{[-0-9]+}}(%r{{[sb]}}p) # 4-byte Folded Spill
; X64-NEXT:    movaps {{[-0-9]+}}(%r{{[sb]}}p), %xmm0 # 16-byte Reload
; X64-NEXT:    callq __extendhfsf2@PLT
; X64-NEXT:    addss {{[-0-9]+}}(%r{{[sb]}}p), %xmm0 # 4-byte Folded Reload
; X64-NEXT:    callq __truncsfhf2@PLT
; X64-NEXT:    movaps %xmm0, {{[-0-9]+}}(%r{{[sb]}}p) # 16-byte Spill
; X64-NEXT:    movaps {{[-0-9]+}}(%r{{[sb]}}p), %xmm0 # 16-byte Reload
; X64-NEXT:    callq __extendhfsf2@PLT
; X64-NEXT:    movss %xmm0, {{[-0-9]+}}(%r{{[sb]}}p) # 4-byte Spill
; X64-NEXT:    movaps {{[-0-9]+}}(%r{{[sb]}}p), %xmm0 # 16-byte Reload
; X64-NEXT:    callq __extendhfsf2@PLT
; X64-NEXT:    addss {{[-0-9]+}}(%r{{[sb]}}p), %xmm0 # 4-byte Folded Reload
; X64-NEXT:    callq __truncsfhf2@PLT
; X64-NEXT:    punpcklwd {{[-0-9]+}}(%r{{[sb]}}p), %xmm0 # 16-byte Folded Reload
; X64-NEXT:    # xmm0 = xmm0[0],mem[0],xmm0[1],mem[1],xmm0[2],mem[2],xmm0[3],mem[3]
; X64-NEXT:    addq $72, %rsp
; X64-NEXT:    retq
;
; F16C-LABEL: ir_fadd_v2f16:
; F16C:       # %bb.0:
; F16C-NEXT:    vcvtph2ps %xmm1, %ymm1
; F16C-NEXT:    vcvtph2ps %xmm0, %ymm0
; F16C-NEXT:    vaddps %ymm1, %ymm0, %ymm0
; F16C-NEXT:    vcvtps2ph $4, %ymm0, %xmm0
; F16C-NEXT:    vzeroupper
; F16C-NEXT:    retq
;
; F16C-O0-LABEL: ir_fadd_v2f16:
; F16C-O0:       # %bb.0:
; F16C-O0-NEXT:    vcvtph2ps %xmm1, %ymm1
; F16C-O0-NEXT:    vcvtph2ps %xmm0, %ymm0
; F16C-O0-NEXT:    vaddps %ymm1, %ymm0, %ymm0
; F16C-O0-NEXT:    vcvtps2ph $4, %ymm0, %xmm0
; F16C-O0-NEXT:    vzeroupper
; F16C-O0-NEXT:    retq
  %retval = fadd <2 x half> %arg0, %arg1
  ret <2 x half> %retval
}