@ RUN: llvm-mc < %s -triple armv7m-elf -filetype=obj | llvm-objdump -d - | FileCheck %s

.arch armv7m

umlal:
umlal r0, r1, r2, r3

@ CHECK-LABEL: umlal
@ CHECK: fbe2 0103   umlal r0, r1, r2, r3

