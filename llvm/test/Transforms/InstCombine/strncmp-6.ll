; NOTE: Assertions have been autogenerated by utils/update_test_checks.py
; RUN: opt < %s -passes=instcombine -S | FileCheck %s
;
; Exercise folding of strncmp calls with constant arrays including both
; negative and positive characters and both constant and nonconstant sizes.

declare i32 @strncmp(i8*, i8*, i64)

@a = constant [7 x i8] c"abcdef\7f"
@b = constant [7 x i8] c"abcdef\80"


; Exercise strncmp(A + C, B + C, 2) folding of small arrays that differ in
; a character with the opposite sign and a constant size.

define void @fold_strncmp_cst_cst(i32* %pcmp) {
; CHECK-LABEL: @fold_strncmp_cst_cst(
; CHECK-NEXT:    store i32 -1, i32* [[PCMP:%.*]], align 4
; CHECK-NEXT:    [[SB5_A5:%.*]] = getelementptr i32, i32* [[PCMP]], i64 1
; CHECK-NEXT:    store i32 1, i32* [[SB5_A5]], align 4
; CHECK-NEXT:    [[SA6_B6:%.*]] = getelementptr i32, i32* [[PCMP]], i64 2
; CHECK-NEXT:    store i32 -1, i32* [[SA6_B6]], align 4
; CHECK-NEXT:    [[SB6_A6:%.*]] = getelementptr i32, i32* [[PCMP]], i64 3
; CHECK-NEXT:    store i32 1, i32* [[SB6_A6]], align 4
; CHECK-NEXT:    ret void
;
  %p5 = getelementptr [7 x i8], [7 x i8]* @a, i64 0, i64 5
  %p6 = getelementptr [7 x i8], [7 x i8]* @a, i64 0, i64 6

  %q5 = getelementptr [7 x i8], [7 x i8]* @b, i64 0, i64 5
  %q6 = getelementptr [7 x i8], [7 x i8]* @b, i64 0, i64 6

  ; Fold strncmp(a + 5, b + 5, 2) to -1.
  %ca5_b5 = call i32 @strncmp(i8* %p5, i8* %q5, i64 2)
  %sa5_b5 = getelementptr i32, i32* %pcmp, i64 0
  store i32 %ca5_b5, i32* %sa5_b5

  ; Fold strncmp(b + 5, a + 5, 2) to +1.
  %cb5_a5 = call i32 @strncmp(i8* %q5, i8* %p5, i64 2)
  %sb5_a5 = getelementptr i32, i32* %pcmp, i64 1
  store i32 %cb5_a5, i32* %sb5_a5

  ; Fold strncmp(a + 6, b + 6, 1) to -1.
  %ca6_b6 = call i32 @strncmp(i8* %p6, i8* %q6, i64 1)
  %sa6_b6 = getelementptr i32, i32* %pcmp, i64 2
  store i32 %ca6_b6, i32* %sa6_b6

  ; Fold strncmp(b + 6, a + 6, 1) to  +1.
  %cb6_a6 = call i32 @strncmp(i8* %q6, i8* %p6, i64 1)
  %sb6_a6 = getelementptr i32, i32* %pcmp, i64 3
  store i32 %cb6_a6, i32* %sb6_a6

  ret void
}


; Exercise strncmp(A, B, N) folding of arrays that differ in a character
; with the opposite sign and a variable size

define void @fold_strncmp_cst_var(i32* %pcmp, i64 %n) {
; CHECK-LABEL: @fold_strncmp_cst_var(
; CHECK-NEXT:    [[TMP1:%.*]] = icmp ugt i64 [[N:%.*]], 6
; CHECK-NEXT:    [[TMP2:%.*]] = sext i1 [[TMP1]] to i32
; CHECK-NEXT:    store i32 [[TMP2]], i32* [[PCMP:%.*]], align 4
; CHECK-NEXT:    [[TMP3:%.*]] = icmp ugt i64 [[N]], 6
; CHECK-NEXT:    [[TMP4:%.*]] = zext i1 [[TMP3]] to i32
; CHECK-NEXT:    [[SB0_A0:%.*]] = getelementptr i32, i32* [[PCMP]], i64 1
; CHECK-NEXT:    store i32 [[TMP4]], i32* [[SB0_A0]], align 4
; CHECK-NEXT:    [[TMP5:%.*]] = icmp ne i64 [[N]], 0
; CHECK-NEXT:    [[TMP6:%.*]] = sext i1 [[TMP5]] to i32
; CHECK-NEXT:    [[SA6_B6:%.*]] = getelementptr i32, i32* [[PCMP]], i64 2
; CHECK-NEXT:    store i32 [[TMP6]], i32* [[SA6_B6]], align 4
; CHECK-NEXT:    [[TMP7:%.*]] = icmp ne i64 [[N]], 0
; CHECK-NEXT:    [[TMP8:%.*]] = zext i1 [[TMP7]] to i32
; CHECK-NEXT:    [[SB6_A6:%.*]] = getelementptr i32, i32* [[PCMP]], i64 3
; CHECK-NEXT:    store i32 [[TMP8]], i32* [[SB6_A6]], align 4
; CHECK-NEXT:    ret void
;
  %p0 = getelementptr [7 x i8], [7 x i8]* @a, i64 0, i64 0
  %p6 = getelementptr [7 x i8], [7 x i8]* @a, i64 0, i64 6

  %q0 = getelementptr [7 x i8], [7 x i8]* @b, i64 0, i64 0
  %q6 = getelementptr [7 x i8], [7 x i8]* @b, i64 0, i64 6

  ; Fold strncmp(a, b, n) to -1.
  %ca0_b0 = call i32 @strncmp(i8* %p0, i8* %q0, i64 %n)
  %sa0_b0 = getelementptr i32, i32* %pcmp, i64 0
  store i32 %ca0_b0, i32* %sa0_b0

  ; Fold strncmp(b, a, n) to +1.
  %cb0_a0 = call i32 @strncmp(i8* %q0, i8* %p0, i64 %n)
  %sb0_a0 = getelementptr i32, i32* %pcmp, i64 1
  store i32 %cb0_a0, i32* %sb0_a0

  ; Fold strncmp(a + 6, b + 6, n) to -1.
  %ca6_b6 = call i32 @strncmp(i8* %p6, i8* %q6, i64 %n)
  %sa6_b6 = getelementptr i32, i32* %pcmp, i64 2
  store i32 %ca6_b6, i32* %sa6_b6

  ; Fold strncmp(b + 6, a + 6, n) to +1.
  %cb6_a6 = call i32 @strncmp(i8* %q6, i8* %p6, i64 %n)
  %sb6_a6 = getelementptr i32, i32* %pcmp, i64 3
  store i32 %cb6_a6, i32* %sb6_a6

  ret void
}