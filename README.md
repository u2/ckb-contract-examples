# Lightning Network's Bidirectional Payment Channels on CKB

## Prerequisites

- [CKB](https://github.com/nervosnetwork/ckb/tree/v0.12.2) (ckb 0.12.2 (v0.12.2 2019-05-20))
- [ckb-sdk-ruby](https://github.com/u2/ckb-sdk-ruby/tree/lightning)

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

```
ruby lightning.rb
```
It works as below:

0) create first commitment transaction
1) create and boadcast the Funding Transaction
2) create another commitment transation for updating the current balances of both parties
3) create Exercise Settlement Transaction for cooperatively closing out the channel
