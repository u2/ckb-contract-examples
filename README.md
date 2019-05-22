# ckb-contract-examples

## toolchain
Toolchain for riscv64, there is a [docker image](https://hub.docker.com/r/xxuejie/riscv-gnu-toolchain-rv64imac).

## wallet
[wallet](https://github.com/rink1969/ckb-sdk-ruby)

Please use branch contract_examples.

This is a fork from NervosNetwork, add extra functions support contract development.

## ckb
[ckb](https://github.com/rink1969/ckb)

Please use branch contract_examples.

This is a fork from NervosNetwork.

## examples
### debug_cell
This is the most simple lock script, just print all arguments, then return 0.
##### compile
```shell
docker run -it --rm -v `pwd`:/data  xxuejie/riscv-gnu-toolchain-rv64imac:latest bin/bash
cd /data
make debug_cell
```

##### run
1. Setup wallet (use branch metioned above).

2. Then miner for a while to get some capacity.

3. Deploy contract. First arg is path of the elf file that we compiled. Seconed arg is name of the contract, we will use it later.
    ```Ruby
    api = CKB::API.new
    privkey = "0x***"
    wallet = CKB::Wallet.from_hex(api, privkey)
    c = CKB::Contract.new(wallet)
    c.deploy_contract("/path/to/debug_cell", "test", ["0xdead"])
    ```

4. Setup contract. Create a cell with some capacity and lock it with debug_cell. First arg is name of contract. Seconed arg is capacity we want to lock.
    ```Ruby
    prev_tx_hash = c.setup_contract("test", 10000*10**8, "0x", ["0xcafe"])
    ```
5. Call contract.
Just send all capacity to a new cell which also locked with debug_cell.
Seconed arg is the prev tx hash. First time prev tx hash is tx hash of setup_contract, then prev tx hash is tx hash of prev call_contract.
   
    ```Ruby
    prev_tx_hash = c.call_contract("test", prev_tx_hash, ["0xbeef"])
    ```
6. [Enable ckb debug log](https://github.com/nervosnetwork/ckb-demo-ruby#custom-log-config), we will see the debug log from script. 

##### result
We will see the args:

0. arg\[0\] is "verify"
1. arg\[1\] is "cafe" the output\[lock\]\[args\] which output point by input\[previous_output\]
2. if the args include many arguments, they will be flattened here.
3. arg\[2\] is "beef" input\[args\]
4. same to 2.
5. arg\[3\] is witness\[0\] which is a pubkey
6. arg\[4\] is witness\[1\] which is a signature
7. arg\[5\] is length of signature

### vote
Three people vote Yes/No, then summary result.

##### compile
```shell
docker run -it --rm -v `pwd`:/data  xxuejie/riscv-gnu-toolchain-rv64imac:latest bin/bash
cd /data
make vote
```
##### run
1. Setup wallet (use branch metioned above).

2. Then miner for a while to get some capacity.

3. Deploy contract and configure data for multi-signatures(M, N and pubkeys of M multi-signers). First arg is path of the elf file that we compiled.
    ```Ruby
    api = CKB::API.new
    privkey = "0x***"
    wallet = CKB::Wallet.from_hex(api, privkey)
    c = CKB::Contract.new(wallet)
    v = CKB::Vote.new(c)
    v.deploy("/path/to/vote", wallet.blake160)
    v.generate_configure_data(3, 2, wallet.blake160, wallet1.blake160, wallet2.blake160)
    ```

4. Publish contract info. In this demo, we use file to share it. Other people need call load_contracts.
    ```Ruby
    c.save_contracts
    ```
5. Vote. Second argument is hex string. The empty string("0x") means No. The other value means Yes. The last arg is pubkey of voter.
    ```Ruby
    vote_hash = v.vote(200, "0xaa", wallet.blake160)
    ```
6. Other people vote. Make sure the wallet have some capacity.
    ```Ruby
    privkey1 = "0x***"
    wallet1 = CKB::Wallet.from_hex(api, privkey1)
    c1 = CKB::Contract.new(wallet1)
    c1.load_contracts
    v1 = CKB::Vote.new(c1)
    vote1_hash = v1.vote(200, "0xbb", wallet1.blake160)

    privkey2 = "0x***"
    wallet2 = CKB::Wallet.from_hex(api, privkey2)
    c2 = CKB::Contract.new(wallet2)
    c2.load_contracts
    v2 = CKB::Vote.new(c2)
    vote2_hash = v2.vote(200, "0x", wallet2.blake160)
    ```
7. Summary. Each one of of M multi-signers call sum to get signed sum transaction. The data filed in output of tx is "0x0302", means total 3 votes and 2 is Yes.
    ```Ruby
    tx0 = v.sum(wallet.address, vote_hash, vote1_hash, vote2_hash)
    tx1 = v1.sum(wallet.address, vote_hash, vote1_hash, vote2_hash)
    tx2 = v2.sum(wallet.address, vote_hash, vote1_hash, vote2_hash)
    ```
8. Merge these signed sum transactions, get multi-singatures transaction. Then send it to ckb.
    ```Ruby
    v.merge(tx0, tx1, tx2)
    ```

### HTLC

Hash Time Locked Contracts, used for Atomic Swaps.

[中文](http://www.qukuaiwang.com.cn/news/15507.html)

[English](https://en.bitcoin.it/wiki/Hash_Time_Locked_Contracts)

##### compile

```shell
docker run -it --rm -v `pwd`:/data  xxuejie/riscv-gnu-toolchain-rv64imac:latest bin/bash
cd /data
make htlc
```

##### run

1. Alice 

   ```ruby
   api = CKB::API.new
   privkey = "0x***"
   wallet = CKB::Wallet.from_hex(api, privkey)
   wallet.get_balance
   c = CKB::Contract.new(wallet)
   alice = CKB::HTLC.new(c)
   alice_addr = wallet.blake160
   ```

2. Bob

   ```ruby
   privkey1 = "0x***"
   wallet1 = CKB::Wallet.from_hex(api, privkey1)
   wallet1.get_balance
   c1 = CKB::Contract.new(wallet1)
   bob = CKB::HTLC.new(c1)
   bob_addr = wallet1.blake160
   ```

3. After Alice and Bob check HTLC contract is correct, deploy it.

   ```ruby
   alice.deploy("/path/to/htlc", alice_addr)
   ```

4. Publish contract info. In this demo, we use file to share it. Alice call save_contracts , Bob call load_contracts.

   ```ruby
   c.save_contracts
   c1.load_contracts
   ```

5. Alice prepare the secret, share lock_hash with Bob and keep lock_image secret.

   ```ruby
   blake2b(0x5e628ed438b1a8a0f06f38ba93e9435f0f83e1afb520970cbf8039a3739b9f16) = 0x8fdcd42cfe36886c2001b2e59896e79d60b1280f3a03c0dee85acd7e8ba5d063
   lock_hash = "0x8fdcd42cfe36886c2001b2e59896e79d60b1280f3a03c0dee85acd7e8ba5d063"
   lock_image = "0x5e628ed438b1a8a0f06f38ba93e9435f0f83e1afb520970cbf8039a3739b9f16"
   ```

6. Alice opened this Atomic Swap. So She need wait longer time to exit (400 > 200). 2**63 is flag means relatively since.

   ```ruby
   alice_valid_since = 400 + 2**63
   bob_valid_since = 200 + 2**63
   ```

7. Alice build lock transaction and exit transaction.

   ```ruby
   alice_lock_tx = alice.build_lock_tx(bob_addr, lock_hash)
   alice_exit_tx = alice.build_exit_tx(alice_valid_since)
   ```

8. Bob build lock transaction and exit transaction.

   ```ruby
   bob_lock_tx = bob.build_lock_tx(alice_addr, lock_hash)
   bob_exit_tx = bob.build_exit_tx(bob_valid_since)
   ```

9. Alice check the transactions built by Bob.

   ```ruby
   alice.check_txs(bob_exit_tx, bob_lock_tx, bob_valid_since)
   ```

   if result is True, sign bob_exit_tx with her private key.

   ```ruby
   alice_for_bob_witness = alice.build_witnesses(bob_exit_tx)
   ```

10. Bob also check transactions built by alice, and sign alice_exit_tx.

    ```ruby
    bob.check_txs(alice_exit_tx, alice_lock_tx, alice_valid_since)
    bob_for_alice_witness = bob.build_witnesses(alice_exit_tx)
    ```

11. They swap witnesses, then build multi-signature exit transactions.

    ```ruby
    alice.build_multi_signature_exit_tx(bob_for_alice_witness)
    bob.build_multi_signature_exit_tx(alice_for_bob_witness)
    ```

12. Alice send lock transaction to ckb.

    ```ruby
    wallet.send_transaction(alice_lock_tx)
    ```

13. Bob send lock transaction to ckb.

    ```ruby
    wallet1.send_transaction(bob_lock_tx)
    ```

    Then begin to watching the block chain.

14. One case is Alice use the secret to build unlock transaction. Alice will get the coins locked by Bob.

    ```ruby
    alice_unlock_tx = alice.build_unlock_tx(bob_lock_tx, lock_image)
    wallet.send_transaction(alice_unlock_tx)
    ```

    Because Bob is watching the block chain, So he will get the secret from Alice's unlock transaction. Then he will get the coins locked by Alice.

    ```ruby
    bob_unlock_tx = bob.build_unlock_tx(alice_lock_tx, lock_image)
    wallet1.send_transaction(bob_unlock_tx)
    ```

15. Another case is Alice cancel the Atomic Swap. So she won't send unlock transaction. But she need wait 400 blocks to exit.

    After 200 blocks, Bob haven't found Alice's unlock transaction on ckb. Then he know the swap has canceled. He will send exit transaction.

    ```ruby
    wallet1.send_transaction(bob.exit_tx)
    ```

    After 400 blocks, Alice send exit transaction.

    ```ruby
    wallet.send_transaction(alice.exit_tx)
    ```

### lightning
Bidirectional Payment Channels

##### compile
```shell
docker run -it --rm -v `pwd`:/data  xxuejie/riscv-gnu-toolchain-rv64imac:latest bin/bash
cd /data
make tot
```
    