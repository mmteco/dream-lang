# 加密标准库

def sha256(value: str) -> str:
    return __c_crypto_sha256(value)

def sha256_bytes(value: bytes) -> str:
    return __c_crypto_sha256_bytes(value)
