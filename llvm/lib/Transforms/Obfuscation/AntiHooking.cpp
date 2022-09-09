/*
    LLVM Anti Hooking Pass
    Copyright (C) 2017 Zhang(https://github.com/Naville/)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published
    by the Free Software Foundation, either version 3 of the License, or
    any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
#include "llvm/IR/Constants.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/Module.h"
#include "llvm/IR/Value.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/Linker/Linker.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Transforms/Obfuscation/Obfuscation.h"
#include "llvm/Transforms/Utils/BasicBlockUtils.h"
#include "llvm/ADT/Triple.h"
#if LLVM_VERSION_MAJOR >= 11
#include "llvm/Transforms/Obfuscation/compat/CallSite.h"
#else
#include "llvm/IR/CallSite.h"
#endif
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
/*
#define SUBSTRATE_SIGNATURE_AARCH64                                            \
  0xd61f020058000050 // Assembled from ldr x16,#0x8,br x16 using Keystone
                     // Engine.Then endian swapped
*/
#define BR_X16 0xd61f0200
#define BR_X17 0xd61f0220

static cl::opt<string>
    PreCompiledIRPath("adhexrirpath",
                      cl::desc("External Path Pointing To Pre-compiled Anti "
                               "Hooking Handler IR.See Wiki"),
                      cl::value_desc("filename"), cl::init(""));
using namespace llvm;
using namespace std;
namespace llvm {
struct AntiHook : public ModulePass {
  static char ID;
  bool flag;
  bool initialized;
  AntiHook() : ModulePass(ID) { this->flag = true;this->initialized=false;}
  AntiHook(bool flag) : ModulePass(ID) { this->flag = flag;this->initialized=false;}
  StringRef getPassName() const override { return StringRef("AntiHook"); }
  bool Initialize(Module &M){
    if (PreCompiledIRPath == "") {
      SmallString<32> Path;
      if (sys::path::home_directory(Path)) { // Stolen from LineEditor.cpp
        sys::path::append(Path, "Hikari");
        Triple tri(M.getTargetTriple());
        sys::path::append(Path, "PrecompiledAntiHooking-" +
                                    Triple::getArchTypeName(tri.getArch()) +
                                    "-" + Triple::getOSTypeName(tri.getOS()) +
                                    ".bc");
#if LLVM_VERSION_MAJOR >= 12
        PreCompiledIRPath = Path.c_str();
#else
        PreCompiledIRPath = Path.str();
#endif
      }
    }
    ifstream f(PreCompiledIRPath);
    if (f.good()) {
      errs() << "Linking PreCompiled AntiHooking IR From:" << PreCompiledIRPath
             << "\n";
      SMDiagnostic SMD;
      unique_ptr<Module> ADBM(
          parseIRFile(StringRef(PreCompiledIRPath), SMD, M.getContext()));
      Linker::linkModules(M, std::move(ADBM), Linker::Flags::OverrideFromSrc);
    } else {
      errs() << "Failed To Link PreCompiled AntiHooking IR From:"
             << PreCompiledIRPath << "\n";
    }
    return true;
  }

  bool runOnModule(Module &M) override {
    Triple tri(M.getTargetTriple());
    vector<uint32_t> signatures;
    if (tri.getArch() == Triple::ArchType::aarch64) {
      signatures.push_back(BR_X16);
      signatures.push_back(BR_X17);
    }
    for (Module::iterator iter = M.begin(); iter != M.end(); iter++) {
      Function &F = *iter;
      if (toObfuscate(flag, &F, "antihook")) {
        errs() << "Running AntiHooking On " << F.getName() << "\n";
        if(this->initialized==false){
          Initialize(M);
          this->initialized=true;
        }
        // Analyze CallInst And InvokeInst
        vector<Function *> calledFunctions;
        calledFunctions.push_back(&F);
        for (Instruction &Ins : instructions(F)) {
          Instruction *Inst = &Ins;
          if (isa<CallInst>(Inst) || isa<InvokeInst>(Inst)) {
            CallSite CS(Inst);
            Function *calledFunction = CS.getCalledFunction();
            if (calledFunction == NULL) {
              calledFunction = dyn_cast<Function>(CS.getCalledValue()->stripPointerCasts());
            }
            // It's only safe to restrict our modification to external symbols
            // Otherwise stripped binary will crash
            if (calledFunction == NULL || !calledFunction->empty() ||
                calledFunction->isIntrinsic()) {
              continue;
            }
            calledFunctions.push_back(calledFunction);
            // FIXME:Handle dlsym() return value generated from FCO
            // It's non-trival to calculate the insertpt correctly
            // So the DominatorTree wont be broken by us
            /*if (calledFunction->hasName() &&
                calledFunction->getName() == StringRef("dlsym")) {
              calledFunctions.push_back(Inst);
            }*/
          }
        }

        for (uint32_t sig : signatures) {
          HandleInlineHook(&(F), sig, calledFunctions);
        }
      }
    }
    // TODO:Do ObjC Method Detection and Fishhook Detection
    return true;
  } // End runOnFunction
  void HandleInlineHook(Function *F, uint32_t signature,
                        vector<Function *> &FunctionToDetect) {
    // First we locate an insert point to check ourself
    // The following is equivalent to
    //    uint32_t *foo=(uint32_t *)(Function + 8);
    // if(*foo==SIGNATURE){
    //    Handler();
    //}

    /*
    We split the originalBB A into:
               A
               |\
               |  B <-Address Detection
               |/ |
               |  D for handler()
               | /
               C <-Original Following BB
    */
    for (Function *called : FunctionToDetect) {
      BasicBlock *A = &(F->getEntryBlock());
      BasicBlock *C = A->splitBasicBlock(A->getFirstNonPHIOrDbgOrLifetime());
      BasicBlock *B = BasicBlock::Create(A->getContext(), "HookDetection",
                                         A->getParent(), A);
      BasicBlock *D = BasicBlock::Create(A->getContext(), "HookDetectedHandler",
                                         A->getParent(), C);
      // Change A's terminator to jump to B
      // We'll add new terminator in B to jump C later
      A->getTerminator()->eraseFromParent();
      IRBuilder<> IRBA(A);
      // End BB Spliting
      Type *Int64Ty = Type::getInt64Ty(A->getContext());
      Type *Int32Ty = Type::getInt32Ty(A->getContext());
      Type *Int1Ty = Type::getInt1Ty(A->getContext());
      IRBuilder<> IRBB(B);
      IRBuilder<> IRBC(C);
      IRBuilder<> IRBD(D);
      IRBA.CreateBr(B);
      // Now operate on Linked AntiHookCallbacks
      // First Extract the value
      Value *lastCondition = ConstantInt::get(Int1Ty, 0);
      Value *BitCasted =
          IRBB.CreateBitCast(called, Type::getInt8PtrTy(A->getContext()));
      Value *PtrToInted = IRBB.CreatePtrToInt(BitCasted, Int64Ty);
      Value *Added = IRBB.CreateAdd(PtrToInted, ConstantInt::get(Int64Ty, 8));
      Value *IntToPtred =
          IRBB.CreateIntToPtr(Added, Type::getInt32PtrTy(A->getContext()));
      Value *rawValue =
          IRBB.CreateLoad(Type::getInt32Ty(A->getContext()), IntToPtred);
      assert(rawValue->getType()->isIntegerTy() &&
             "Value Passed Into HandleInlineHook() Not A Pointer To Integer!");
      lastCondition =
          IRBB.CreateICmpEQ(rawValue, ConstantInt::get(Int32Ty, signature));
      IRBB.CreateCondBr(lastCondition, D, C);
      Function *AHCallBack = A->getModule()->getFunction("AHCallBack");
      if (AHCallBack) {
        IRBD.CreateCall(AHCallBack, ArrayRef<Value *>());
      } else {
        // First. Build up declaration for abort();
        FunctionType *ABFT =
            FunctionType::get(Type::getVoidTy(A->getContext()), false);
#if LLVM_VERSION_MAJOR >= 9
        Function *abort_declare = cast<Function>(
            A->getModule()->getOrInsertFunction("abort", ABFT).getCallee());
#else
        Function *abort_declare =
            cast<Function>(A->getModule()->getOrInsertFunction("abort", ABFT));
#endif
        abort_declare->addFnAttr(Attribute::AttrKind::NoReturn);
        IRBD.CreateCall(abort_declare, ArrayRef<Value *>());
      }
      IRBD.CreateBr(C); // Insert a new br into the end of B to jump back to C*/
    }
  }                   // End HandleAArch64InlineHook
};
} // namespace llvm
ModulePass *llvm::createAntiHookPass() { return new AntiHook(); }
ModulePass *llvm::createAntiHookPass(bool flag) { return new AntiHook(flag); }
char AntiHook::ID = 0;
INITIALIZE_PASS(AntiHook, "antihook", "AntiHook", true, true)
