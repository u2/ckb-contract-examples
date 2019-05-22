gem 'ckb-sdk-ruby'
require 'ckb'
include CKB
include Types

puts "0. prepare"
puts "transfer capacity to alice and bob"

api = API.new
god = Wallet.from_hex(api, "0xe79f3207ea4980b7fed79956d5934249ceac4751a4fae01a0f7c4a96884bc4e3")

bob = Wallet.from_hex(api, "0xa272f08f25809112aa8a8c42967418d8404e80f4313a8ae928c15beee3482012")
alice = Wallet.from_hex(api, "0xefc3957bc1d1ee67aaea83e54d7bdfc8069d0eba52e7a247bcdcb8b2d9705601")

god.send_capacity(alice.address, 300 * 10 ** 8)

while alice.get_balance < 300 * 10 ** 8
  sleep 1
end

god.send_capacity(bob.address, 300 * 10 ** 8)

while bob.get_balance < 300 * 10 ** 8
  sleep 1
end

puts "1. unsigned funding transaction"

god_c = CKB::Contract.new(god)

puts "1.1 deploy two-of-two multi signatures script"
god_c.deploy_contract("./tot", :tot, [])

puts "1.2 create unsigned finding transaction"

capacity = 300 * 10 ** 8
inputs_from_alice = alice.send :gather_inputs, capacity, MIN_CELL_CAPACITY
inputs_from_bob = bob.send :gather_inputs, capacity, MIN_CELL_CAPACITY

tot_outpoint = Types::OutPoint.new(
                 cell: Types::CellOutPoint.new(
                 tx_hash: god_c.contracts[:tot][:tx_hash],
                 index: 0
               ))

outputs = [
  Types::Output.new(
    capacity: capacity * 2,
    data: "0x",
    lock: Types::Script.new(
      args: [alice.blake160, bob.blake160],
      code_hash: god_c.contracts[:tot][:binary_hash]
    )
  )
]

unsigned_funding_transaction = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point, tot_outpoint],
  inputs: inputs_from_alice.inputs + inputs_from_bob.inputs,
  outputs: outputs
)

funding_tx_hash = api.compute_transaction_hash(unsigned_funding_transaction)

# P18: Figure 4
puts "2 create commit transaction (children transaction)"
puts "2.1 create commit transaction and sign"
puts "alice create commitment tx 1a (C1a)"
puts "   Only alice can broadcast"
puts "   Outputs:"
puts "      0: RSMC alice&bob 300 ckb"
puts "      1: no locktime for bob 300 ckb"

# TODO:
# 这里不太会调用tx中的since，如果可以调用的话，alice&bob的签名都有的情况下可以立即花费，否则需要等待一定时间alice才能花费。
# 这个时候output实际上是alice的一个临时私钥的pubkey hash锁定的，
# 在构建Breach Remedy Transaction的时候，只要把这个alice的临时私钥给对手方bob即可。

# 现在的做法是，额外构建一个交易，然后双方签名的交易需要在等待一段时间后，这个交易才可以被alice花费。
# 构建Breach Remedy Transaction的时候，只要双方另外再构建一个交易，使得这个交易可以被立刻执行，并被bob花费。
# 这种情况客户端会额外构造一些交易，上面的情况客户端需要额外多保存私钥，且交易的数据量要远远大于私钥。

c1a_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: funding_tx_hash, index: 0)),
  args: [],
  since: "0"
)

c1a_output_0 = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: Types::Script.new(
    args: [alice.blake160, bob.blake160],
    code_hash: god_c.contracts[:tot][:binary_hash]
  )
)

c1a_output_1 = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: bob.lock
)

c1a = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point, tot_outpoint],
  inputs: [c1a_input],
  outputs: [c1a_output_0, c1a_output_1]
)

c1a_tx_hash = api.compute_transaction_hash(c1a)

c1a_alice_witness = c1a.sign(alice.key, c1a_tx_hash).witnesses

puts "Rd1a: alice could spend output1 100 blocks later"

rd1a_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: c1a_tx_hash, index: 0)),
  args: [],
  since: ((1 << 63) + 100).to_s
)

rd1a_output = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: Types::Script.new(
    args: [alice.blake160],
    code_hash: api.system_script_cell_hash
  )
)

rd1a = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point],
  inputs: [rd1a_input],
  outputs: [rd1a_output]
)

rd1a_tx_hash = api.compute_transaction_hash(rd1a)

rd1a_alice_witness = rd1a.sign(alice.key, rd1a_tx_hash).witnesses

puts "bob create commitment tx 1a (C1b)"
puts "   Only bob can broadcast"
puts "   Outputs:"
puts "      0: RSMC alice&bob 300 ckb"
puts "      1: no locktime for alice 300 ckb"

c1b_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: funding_tx_hash, index: 0)),
  args: [],
  since: "0"
)

c1b_output_0 = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: Types::Script.new(
    args: [alice.blake160, bob.blake160],
    code_hash: god_c.contracts[:tot][:binary_hash]
  )
)

c1b_output_1 = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: alice.lock
)

c1b = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point, tot_outpoint],
  inputs: [c1b_input],
  outputs: [c1b_output_0, c1b_output_1]
)

c1b_tx_hash = api.compute_transaction_hash(c1b)

c1b_bob_witness = c1b.sign(bob.key, c1b_tx_hash).witnesses

puts "Rd1b: bob could spend output1 100 blocks later"

rd1b_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: c1b_tx_hash, index: 0)),
  args: [],
  since: ((1 << 63) + 100).to_s
)

rd1b_output = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: Types::Script.new(
    args: [bob.blake160],
    code_hash: api.system_script_cell_hash
  )
)

rd1b = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point],
  inputs: [rd1b_input],
  outputs: [rd1b_output]
)

rd1b_tx_hash = api.compute_transaction_hash(rd1b)

rd1b_bob_witness = rd1b.sign(bob.key, rd1b_tx_hash).witnesses

puts "2.2 Exchange the signatures for the children"

c1a_alice_witness = c1a.sign(alice.key, c1a_tx_hash).witnesses
rd1a_alice_witness = rd1a.sign(alice.key, rd1a_tx_hash).witnesses

c1b_bob_witness = c1b.sign(bob.key, c1b_tx_hash).witnesses
rd1b_bob_witness = rd1b.sign(bob.key, rd1b_tx_hash).witnesses

puts "2.3 Sign the parent (Funding transaction)"

alice_funding_witnesses = unsigned_funding_transaction.sign(alice.key, funding_tx_hash).witnesses
bob_funding_witnesses = unsigned_funding_transaction.sign(bob.key, funding_tx_hash).witnesses

puts "2.4 Exchange the signatures for the parent"

funding_witnesses = alice_funding_witnesses[0..(inputs_from_alice.inputs.size - 1)] + bob_funding_witnesses[(inputs_from_alice.inputs.size)..-1]

unsigned_funding_transaction.witnesses = funding_witnesses

puts "2.5 Broadcast the parent on the blockchain"

puts api.send_transaction(unsigned_funding_transaction)

sleep 5

# puts api.get_transaction(funding_tx_hash).to_h

puts "3 create commit transaction"


