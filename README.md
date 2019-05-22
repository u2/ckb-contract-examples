# Payment Channels on CKB

## Prerequisites

- [CKB](https://github.com/nervosnetwork/ckb/tree/v0.12.2) (ckb 0.12.2 (v0.12.2 2019-05-20))
- [ckb-sdk-ruby](https://github.com/u2/ckb-sdk-ruby/tree/lightning) (https://github.com/u2/ckb-sdk-ruby/tree/lightning)

## Design

### Funding Transaction
The output for the Funding Transaction is a single 2-of-2 multisignature script with both participants in this channel, henceforth named Alice and Bob. It's for creating the channel.

Setps:
1. Create the parent (Funding Transaction)
2. Create the children (Commitment Transactions and all spends from the commitment transactions)
3. Sign the children
4. Exchange the signatures for the children
5. Sign the parent
6. Exchange the signatures for the parent
7. Broadcast the parent on the blockchain

### First Commitment Transaction
Commitment Transactions pay out the respective current balances to each party.

Note: Alice2 is Alice's another pubkey

Alice create the commitment transactions with two outputs:
```
    output-0. Revocable Maturity Contract Alice2&Bob 300 ckb
    output-1. bob 300 ckb
    No LockTime
```

Revocable Maturity Contract is that:
   - output for Alice, 100-block relative confirmations lock
   - or bob can spend it with alice2 and bob's signatures immediately, if bob has alice2 private key

Bob creates the commitment transactions with two outputs:
```
    output-0. Revocable Maturity Contract Alice&Bob2 300 ckb
    output-1. alice 300 ckb
    No LockTime
```

During Alice and Bob create the Funding Transaction, they already have two different signed commitment transactions.

### New Commitment Transaction

1. Create new commitment transaction

Alice create the commitment transactions with two outputs:
```
    output-0. Revocable Maturity Contract Alice3&Bob 400 ckb
    output-1. bob 200 ckb
    No LockTime
```

Bob creates the commitment transactions with two outputs:
```
    output-0. Revocable Maturity Contract Alice&Bob3 200 ckb
    output-1. alice 400 ckb
    No LockTime
```
2. Exchange the signatures for the children (the new commitment transaction)
3. Breach Remedy Transaction for parent commit transaction
   - alice discloses the alice2 private keys to the counterparty
   - bob discloses the bob2 private keys to the counterparty

4. Bob&Alice should destroy all old Commitment Transactions

### Exercise Settlement Transaction
Cooperatively Closing Out a Channel

Create the new transaction with no script encumbering conditions. There are two outputs:

```
    - output-0: alice 400 ckb
    - output-1: bob 200 ckb
    No LockTime
```

## Figure from Lightning Network Paper

http://lightning.network/lightning-network-paper.pdf

<img src=9.png></img>

## Demo

There are a little difference from the above design. The reasaon is that I am not familiar with C script on CKB and don't know how to get the `since` field in transaction.

In the First Commitment Transaction, instead of the output-0 (Revocable Maturity Contract Alice2&Bob 300 ckb), it's just a two-of-two multisignature output. And when Alice and Bob creates the commitment transaction, they need to sign the Revocable Delivery transaction which is a nLockTime relative transaction, and exchange their signatures. The same as the other commitment transactions.

The drawback is that the two parities should keep all the Revocable Delivery transactions, otherwise they will lose money when counterparty broadcasts the old commitment transactions.

## Run

Before this, you should already installed the ckb and ckb-sdk-ruby.

1. Compile

```
git submodule update --init --recursive
```

```
docker run -it --rm -v `pwd`:/data  xxuejie/riscv-gnu-toolchain-rv64imac:latest bin/bash
cd /data
make two_of_two
```

2. Run CKB

```
cd ckb-dev
ckb run
```
Open another terminal

```
cd ckb-dev
ckb miner
```
Wait for a few seconds...

3. Run lightning

Scenario 0: Both parities comply the rules and cooperatively close out the channel

```
bash scenario_0.sh
```
It works as below:

0) create first commitment transaction
1) create and boadcast the Funding Transaction
2) create another commitment transation for updating the current balances of both parties
3) create Exercise Settlement Transaction for cooperatively closing out the channel

```
➜ lightning git:(master) ✗ bash scenario_0.sh
0. prepare
transfer capacity to alice and bob
0x72f361903ed3b1ecde297d355c7bb3bdc50e65f89e1be87b97d3178c2479aa49
0x5ff36bc697e1e67440319cf84bc1c58eff5fba4a1e3950ff5e901754ba6faeb5
1. unsigned funding transaction
1.1 deploy two-of-two multi signatures script
deploy contract ./two_of_two
code len 1174384, use capacity 117448400000000
1.2 create unsigned finding transaction
2 create commit transaction (children transaction)
2.1 create commit transaction and sign
alice create commitment tx 1a (C1a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for bob 300 ckb
Rd1a (Revocable Delivery transaction): alice could spend output-0 after 100 blocks confirmation
bob create commitment tx 1b (C1b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for alice 300 ckb
Rd1b: bob could spend output-0 after 100 blocks confirmation
2.2 Exchange the signatures for the children
2.2.1 exchange signatures for the Revocable Delivery transaction
2.2.2 exchange signatures for the Commitment transaction
2.3 Sign the parent (Funding transaction)
2.4 Exchange the signatures for the parent
2.5 Broadcast the parent on the blockchain
0x81cf241e14be42466401bc3de7631bfda62cbd292ec3f1a8690e6518c17f005c
{:status=>"proposed", :block_hash=>nil}
3 new commit transaction
3.1 create commit transaction and sign
alice create commitment tx 2a (C2a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 400 ckb
      1: no locktime for bob 200 ckb
Rd2a: alice could spend output-0 100 blocks later
bob create commitment tx 2b (C2b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 200 ckb
      1: no locktime for alice 400 ckb
Rd2b: bob could spend output-0 100 blocks later
3.2 Exchange the signatures for the children
3.2.1 exchange signatures for the Revocable Delivery transaction
3.2.2 exchange signatures for the Commitment transaction
3.3 Breach Remedy Transaction for parent commit transaction
    alice discloses the alice2 private keys to the counterparty
    bob  discloses the bob2 private keys to the counterparty
3.4 Exchange the signatures for the Breach Remedy Transaction
Bob&Alice should destroy all old Commitment Transactions
Scenario_0: Both parities comply the rules and cooperatively close out the channel
4. Exercise Settlement Tx
alice balance: 60000000000
bob balance: 0
{:status=>"committed", :block_hash=>"0x6f670a78b214b11754316501b7be4f997a04f49abd4b2c5a14bc57e9d171bebb"}
now alice's balance is 100000000000
now bob's balance is 20000000000
alice: Fabulous 😎 !
bob: Terrific 😘 !
robot: see you next time!
```

Scenario 1: Alice broadcasts old commitment transaction and all the funds are given to the other party as a penalty

```
bash scenario_1.sh
```
It works as below:

0) create first commitment transaction
1) create and boadcast the Funding Transaction
2) create another commitment transation for updating the current balances of both parties
3) Alice broadcasts old commitment transaction and all the funds are given to the other party as a penalty

```
➜ lightning git:(master) ✗ bash scenario_1.sh
0. prepare
transfer capacity to alice and bob
0x5358162b707f14bf508a13c180afb06e95f29914c3fc47564c0d7ea03a478a45
0x4a338db2ba683803c4bb973b9f1742bcf4da16b3f436daee2b30283fe95d9f83
1. unsigned funding transaction
1.1 deploy two-of-two multi signatures script
deploy contract ./two_of_two
code len 1174384, use capacity 117448400000000
1.2 create unsigned finding transaction
2 create commit transaction (children transaction)
2.1 create commit transaction and sign
alice create commitment tx 1a (C1a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for bob 300 ckb
Rd1a (Revocable Delivery transaction): alice could spend output-0 after 100 blocks confirmation
bob create commitment tx 1b (C1b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for alice 300 ckb
Rd1b: bob could spend output-0 after 100 blocks confirmation
2.2 Exchange the signatures for the children
2.2.1 exchange signatures for the Revocable Delivery transaction
2.2.2 exchange signatures for the Commitment transaction
2.3 Sign the parent (Funding transaction)
2.4 Exchange the signatures for the parent
2.5 Broadcast the parent on the blockchain
0x1535549164c484651103fdbb89107ad79e642038bd45024d0f8434aca4942ca6
{:status=>"pending", :block_hash=>nil}
3 new commit transaction
3.1 create commit transaction and sign
alice create commitment tx 2a (C2a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 400 ckb
      1: no locktime for bob 200 ckb
Rd2a: alice could spend output-0 100 blocks later
bob create commitment tx 2b (C2b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 200 ckb
      1: no locktime for alice 400 ckb
Rd2b: bob could spend output-0 100 blocks later
3.2 Exchange the signatures for the children
3.2.1 exchange signatures for the Revocable Delivery transaction
3.2.2 exchange signatures for the Commitment transaction
3.3 Breach Remedy Transaction for parent commit transaction
    alice discloses the alice2 private keys to the counterparty
    bob  discloses the bob2 private keys to the counterparty
3.4 Exchange the signatures for the Breach Remedy Transaction
Bob&Alice should destroy all old Commitment Transactions
Scenario_1: Alice broadcast old commitment transaction and all the funds are given to the other party as a penalty
Alice broadcast the old commitment transaction c1a
Alice try to broadcast the rd1a
jsonrpc error: {:code=>-3, :message=>"InvalidTx(Immature)"}
Alice should delivery rd1a after 100-block confirmation
Bob monitor that alice broadcasted the c1a
And broadcast the Breach Remedy Transaction of c1a
Bob's balance: 60000000000
Bob take Alice's fund 30000000000 as a penalty
Bob's new balance: 90000000000
alice: Oh my...
bob: Terrific 😘 !
robot: see you next time!
```
:beer
