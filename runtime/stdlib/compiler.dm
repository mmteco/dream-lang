# Compiler utilities

def build_llvm(llvm_path: str, output_path: str, optimized: bool = true) -> bool:
    let status = __c_build_llvm(llvm_path, output_path, optimized)
    if status == 0:
        return false
    return true
