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
   - output for Alice, 10-block relative confirmations lock
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

## Run

Before this, you should already installed the ckb and ckb-sdk-ruby.

1. Compile

```
git submodule update --init --recursive
```

```
docker run -it --rm -v `pwd`:/data  xxuejie/riscv-gnu-toolchain-rv64imac:latest bin/bash
cd /data
make
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

### Scenario 0

Both parities comply the rules and cooperatively close out the channel

```
bash scenario_0.sh
```
It works as below:

0) create first commitment transaction
1) create and boadcast the Funding Transaction
2) create another commitment transation for updating the current balances of both parties
3) create Exercise Settlement Transaction for cooperatively closing out the channel

```
rm: cannot remove 'scenario_0.rb': No such file or directory
0. prepare
transfer capacity to alice and bob
0x114b76bdccb4002ce3754fe22e2ae0d86908e679935af7a90cfe3e3b05b94f80
0x156ba2ad0826438ea64ac062181ade49aa68f66f38d7cfbee8f4ff58558ce97f
1. unsigned funding transaction
1.1 deploy two-of-two multi signatures script
    and revocable_maturity script
deploy contract ./two_of_two
code len 1174384, use capacity 117448400000000
deploy contract ./revocable_maturity
code len 1216312, use capacity 121641200000000
1.2 create unsigned finding transaction
2 create commit transaction (children transaction)
2.1 create commit transaction and sign
alice create commitment tx 1a (C1a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for bob 300 ckb
bob create commitment tx 1b (C1b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for alice 300 ckb
2.2 Exchange the signatures for the children
2.3 Sign the parent (Funding transaction)
2.4 Exchange the signatures for the parent
2.5 Broadcast the parent on the blockchain
0xe44a109f8c8f1360d04bb8776999b920501d292ea29f7a8bdf0a6b12851912f3
{:status=>"committed", :block_hash=>"0x01a1c5f74fdf5a2daf90089b5975680bbd55e3fb6093448506453a74462eb995"}
3 new commit transaction
3.1 create commit transaction and sign
alice create commitment tx 2a (C2a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 400 ckb
      1: no locktime for bob 200 ckb
bob create commitment tx 2b (C2b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 200 ckb
      1: no locktime for alice 400 ckb
3.2 Exchange the signatures for the children
3.3 Breach Remedy Transaction for parent commit transaction
    alice discloses the alice2 private keys to the counterparty
    bob  discloses the bob2 private keys to the counterparty
3.4 Exchange the signatures for the Breach Remedy Transaction
Bob&Alice should destroy all old Commitment Transactions
Scenario_0: Both parities comply the rules and cooperatively close out the channel
4. Exercise Settlement Tx
alice balance: 0
bob balance: 240000000000
{:status=>"committed", :block_hash=>"0xa5fba52b25f5f58db8f774440570575a011f18c96d6b660ba0975505885fd727"}
now alice's balance is 40000000000
now bob's balance is 260000000000
alice: Fabulous 😎 !
bob: Terrific 😘 !
robot: see you next time!
```

### Scenario 1

Alice broadcasts old commitment transaction and all the funds are given to the other party as a penalty

```
bash scenario_1.sh
```
It works as below:

0) create first commitment transaction
1) create and boadcast the Funding Transaction
2) create another commitment transation for updating the current balances of both parties
3) Alice broadcasts old commitment transaction
4) Bob monitors the event and broadcasts Breach Remedy Transaction immediately, all the funds are given to Bob as a penalty of Alice

```
rm: cannot remove 'scenario_1.rb': No such file or directory
0. prepare
transfer capacity to alice and bob
0x65949e9981a7d688e5102905bdaa697276e1eaf724283f65e0f5b9a1d4cf4f5f
0xb276c13253847b6d3be984120e895948b919f5b71f53e4478fd5b664a74a5453
1. unsigned funding transaction
1.1 deploy two-of-two multi signatures script
    and revocable_maturity script
deploy contract ./two_of_two
code len 1174384, use capacity 117448400000000
deploy contract ./revocable_maturity
code len 1216312, use capacity 121641200000000
1.2 create unsigned finding transaction
2 create commit transaction (children transaction)
2.1 create commit transaction and sign
alice create commitment tx 1a (C1a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for bob 300 ckb
bob create commitment tx 1b (C1b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for alice 300 ckb
2.2 Exchange the signatures for the children
2.3 Sign the parent (Funding transaction)
2.4 Exchange the signatures for the parent
2.5 Broadcast the parent on the blockchain
0x073ff8d6224c086f9e889b5f486977976489cd493968b12e5ec3d2f0c8877bc6
{:status=>"committed", :block_hash=>"0xf67bfa132787c8a02d9685f4115b2ab2dead9ea8e2c878111505c823a62bf13c"}
3 new commit transaction
3.1 create commit transaction and sign
alice create commitment tx 2a (C2a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 400 ckb
      1: no locktime for bob 200 ckb
bob create commitment tx 2b (C2b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 200 ckb
      1: no locktime for alice 400 ckb
3.2 Exchange the signatures for the children
3.3 Breach Remedy Transaction for parent commit transaction
    alice discloses the alice2 private keys to the counterparty
    bob  discloses the bob2 private keys to the counterparty
3.4 Exchange the signatures for the Breach Remedy Transaction
Bob&Alice should destroy all old Commitment Transactions
Scenario_1: Alice broadcasts old commitment transaction and all the funds are given to the other party as a penalty
Alice broadcast the old commitment transaction c1a
Alice try to broadcast the rd1a but failed
Rd1a (Revocable Delivery transaction): alice could spend output-0 after 10 blocks confirmation
jsonrpc error: {:code=>-3, :message=>"InvalidTx(Immature)"}
Alice should delivery rd1a after 10-block confirmation
Bob monitor that alice broadcasted the c1a
And broadcast the Breach Remedy Transaction of c1a
Bob's balance: 290000000000
0x914c0c3e0f876a9eba49d79367f2c585dd60c534d673f552931cb976bde04d9f
{:status=>"committed", :block_hash=>"0x1593ef5df7eed81156f00db41155319467f8ae285ce519be294779422a043209"}
Bob take Alice's fund 30000000000 as a penalty
Bob's new balance: 320000000000
alice: Oh my...
bob: Terrific 😘 !
robot: see you next time!
```

### Scenario 2

Alice broadcasts old commitment transaction, but Bob is napping, so Alice takes the fund in the old commitment transaction

```
bash scenario_2.sh
```
It works as below:

0) create first commitment transaction
1) create and boadcast the Funding Transaction
2) create another commitment transation for updating the current balances of both parties
3) Alice broadcasts old commitment transaction
4) Bob is napping and missing that
5) Alice steals the funds

```
0. prepare
transfer capacity to alice and bob
0x4f30480f02f9410fa2f3b7e9cf1a89cc7d851d6e68c58ca5193f200ee51c801f
0x29a207aa983ebacf3ac136402c1c5979612c01e614e7c3c851510331aaea2f61
1. unsigned funding transaction
1.1 deploy two-of-two multi signatures script
    and revocable_maturity script
deploy contract ./two_of_two
code len 1174384, use capacity 117448400000000
deploy contract ./revocable_maturity
code len 1203360, use capacity 120346000000000
1.2 create unsigned finding transaction
2 create commit transaction (children transaction)
2.1 create commit transaction and sign
alice create commitment tx 1a (C1a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for bob 300 ckb
bob create commitment tx 1b (C1b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 300 ckb
      1: no locktime for alice 300 ckb
2.2 Exchange the signatures for the children
2.3 Sign the parent (Funding transaction)
2.4 Exchange the signatures for the parent
2.5 Broadcast the parent on the blockchain
0x155c15809cf1a473c40f238a4a85feded958d459f2c54af103b727fae930a138
{:status=>"committed", :block_hash=>"0x100ee47d305d2523c9cec2d02f42f9a66ade649ba0cfddecb49c7f5d95e4d8e5"}
3 new commit transaction
3.1 create commit transaction and sign
alice create commitment tx 2a (C2a)
   Only alice can broadcast
   Outputs:
      0: RSMC alice&bob 400 ckb
      1: no locktime for bob 200 ckb
bob create commitment tx 2b (C2b)
   Only bob can broadcast
   Outputs:
      0: RSMC alice&bob 200 ckb
      1: no locktime for alice 400 ckb
3.2 Exchange the signatures for the children
3.3 Breach Remedy Transaction for parent commit transaction
    alice discloses the alice2 private keys to the counterparty
    bob  discloses the bob2 private keys to the counterparty
3.4 Exchange the signatures for the Breach Remedy Transaction
Bob&Alice should destroy all old Commitment Transactions
Scenario_2: Alice broadcasts old commitment transaction
            but Bob is napping,
            so Alice takes the fund in the old commitment transaction
Alice broadcast the old commitment transaction c1a
Alice try to broadcast the rd1a but failed
Rd1a (Revocable Delivery transaction): alice could spend output-0 after 10 blocks confirmation
Alice's balance 60000000000
Bob is napping...
Alice takes the input-0 in the old commitment transaction 30000000000
Alice's new balance: 90000000000
alice: Terrific 😘 !
bob: Oh my...
robot: see you next time!
```

:beer:

## References:

- [The Bitcoin Lightning Network: Scalable Off-Chain Instant Payments](http://lightning.network/lightning-network-paper.pdf)
- [漫谈闪电网络](https://talk.nervos.org/t/topic/1854)
- [如何在CKB上实现闪电网络（一）](https://talk.nervos.org/t/ckb/2563)
