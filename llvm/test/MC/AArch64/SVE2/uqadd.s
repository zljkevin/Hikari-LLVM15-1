// RUN: llvm-mc -triple=aarch64 -show-encoding -mattr=+sve2 < %s \
// RUN:        | FileCheck %s --check-prefixes=CHECK-ENCODING,CHECK-INST
// RUN: llvm-mc -triple=aarch64 -show-encoding -mattr=+sme < %s \
// RUN:        | FileCheck %s --check-prefixes=CHECK-ENCODING,CHECK-INST
// RUN: not llvm-mc -triple=aarch64 -show-encoding < %s 2>&1 \
// RUN:        | FileCheck %s --check-prefix=CHECK-ERROR
// RUN: llvm-mc -triple=aarch64 -filetype=obj -mattr=+sve2 < %s \
// RUN:        | llvm-objdump -d --mattr=+sve2 - | FileCheck %s --check-prefix=CHECK-INST
// RUN: llvm-mc -triple=aarch64 -filetype=obj -mattr=+sve2 < %s \
// RUN:   | llvm-objdump -d --mattr=-sve2 - | FileCheck %s --check-prefix=CHECK-UNKNOWN

uqadd z0.b, p0/m, z0.b, z1.b
// CHECK-INST: uqadd z0.b, p0/m, z0.b, z1.b
// CHECK-ENCODING: [0x20,0x80,0x19,0x44]
// CHECK-ERROR: instruction requires: sve2 or sme
// CHECK-UNKNOWN: 44198020 <unknown>

uqadd z0.h, p0/m, z0.h, z1.h
// CHECK-INST: uqadd z0.h, p0/m, z0.h, z1.h
// CHECK-ENCODING: [0x20,0x80,0x59,0x44]
// CHECK-ERROR: instruction requires: sve2 or sme
// CHECK-UNKNOWN: 44598020 <unknown>

uqadd z29.s, p7/m, z29.s, z30.s
// CHECK-INST: uqadd z29.s, p7/m, z29.s, z30.s
// CHECK-ENCODING: [0xdd,0x9f,0x99,0x44]
// CHECK-ERROR: instruction requires: sve2 or sme
// CHECK-UNKNOWN: 44999fdd <unknown>

uqadd z31.d, p7/m, z31.d, z30.d
// CHECK-INST: uqadd z31.d, p7/m, z31.d, z30.d
// CHECK-ENCODING: [0xdf,0x9f,0xd9,0x44]
// CHECK-ERROR: instruction requires: sve2 or sme
// CHECK-UNKNOWN: 44d99fdf <unknown>

// --------------------------------------------------------------------------//
// Test compatibility with MOVPRFX instruction.

movprfx z31.d, p0/z, z6.d
// CHECK-INST: movprfx z31.d, p0/z, z6.d
// CHECK-ENCODING: [0xdf,0x20,0xd0,0x04]
// CHECK-ERROR: instruction requires: sve or sme
// CHECK-UNKNOWN: 04d020df <unknown>

uqadd z31.d, p0/m, z31.d, z30.d
// CHECK-INST: uqadd z31.d, p0/m, z31.d, z30.d
// CHECK-ENCODING: [0xdf,0x83,0xd9,0x44]
// CHECK-ERROR: instruction requires: sve2 or sme
// CHECK-UNKNOWN: 44d983df <unknown>

movprfx z31, z6
// CHECK-INST: movprfx z31, z6
// CHECK-ENCODING: [0xdf,0xbc,0x20,0x04]
// CHECK-ERROR: instruction requires: sve or sme
// CHECK-UNKNOWN: 0420bcdf <unknown>

uqadd z31.d, p7/m, z31.d, z30.d
// CHECK-INST: uqadd z31.d, p7/m, z31.d, z30.d
// CHECK-ENCODING: [0xdf,0x9f,0xd9,0x44]
// CHECK-ERROR: instruction requires: sve2 or sme
// CHECK-UNKNOWN: 44d99fdf <unknown>
