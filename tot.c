#include "secp256k1_blake160.h"

// two of two multi signature
int main(int argc, char* argv[])
{
    int ret;
    uint64_t length = 0;

    if (argc == 9) {
        // signed args:
        // arg[1] alice pubkey hash
        // arg[2] bob pubkey hash

        // witnesses:
        // arg[3] alice pubkey
        // arg[4] alice signature
        // arg[5] alice signature size
        // arg[6] bob pubkey
        // arg[7] bob signature
        // arg[8] bob signature size

        length = *((uint64_t *) argv[5]);
        ret = verify_sighash_all(argv[1], argv[3], argv[4], length);
        if (ret != CKB_SUCCESS) {
            return ret;
        }

        length = *((uint64_t *) argv[8]);
        return verify_sighash_all(argv[2], argv[6], argv[7], length);
    }
    return -99;
}
