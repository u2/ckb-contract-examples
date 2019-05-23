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

alice2 = Wallet.from_hex(api, "0xdf51aa81f4e19c1c57ca764a7810400e68d899f5aebf8e46d89401a7ce568c7e")
alice3 = Wallet.from_hex(api, "0x70972471656087d365955112fa5f795be5c28ad342de64a79ac2530ce302cb7f")

bob2 = Wallet.from_hex(api, "0x2c1365696e17e37d277d44f6cef59eb9bf588974c103937ea52679a28702118c")
bob3 = Wallet.from_hex(api, "0x8665b2764dd353e3f63c86f261faf7b30a6a91ba6bbf546a2d6c4249a293f637")

puts god.send_capacity(bob.address, 300 * 10 ** 8)

while bob.get_balance < 300 * 10 ** 8
  sleep 1
end

sleep 10

puts god.send_capacity(alice.address, 300 * 10 ** 8)

while alice.get_balance < 300 * 10 ** 8
  sleep 1
end

sleep 10

puts "1. unsigned funding transaction"

god_c = CKB::Contract.new(god)

puts "1.1 deploy two-of-two multi signatures script"
god_c.deploy_contract("./two_of_two", :tot, [])

puts "1.2 create unsigned finding transaction"

capacity = 300 * 10 ** 8
inputs_from_alice = alice.send :gather_inputs, capacity, MIN_CELL_CAPACITY
inputs_from_bob = bob.send :gather_inputs, capacity, MIN_CELL_CAPACITY

tot_outpoint = Types::OutPoint.new(
  cell: Types::CellOutPoint.new(
    tx_hash: god_c.contracts[:tot][:tx_hash],
    index: 0
  )
)

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

sleep 2

# P18: Figure 4
puts "2 create commit transaction (children transaction)"
puts "2.1 create commit transaction and sign"
puts "alice create commitment tx 1a (C1a)"
puts "   Only alice can broadcast"
puts "   Outputs:"
puts "      0: RSMC alice&bob 300 ckb"
puts "      1: no locktime for bob 300 ckb"

c1a_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: funding_tx_hash, index: 0)),
  args: [],
  since: "0"
)

c1a_output_0 = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: Types::Script.new(
    args: [alice2.blake160, bob.blake160],
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

c1a_alice_witnesses = c1a.sign(alice.key, c1a_tx_hash).witnesses

puts "Rd1a (Revocable Delivery transaction): alice could spend output-0 after 100 blocks confirmation"

rd1a_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: c1a_tx_hash, index: 0)),
  args: [],
  since: ((1 << 63) + 100).to_s
)

rd1a_output = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: Types::Script.new(
    args: [alice2.blake160],
    code_hash: api.system_script_code_hash
  )
)

rd1a = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point],
  inputs: [rd1a_input],
  outputs: [rd1a_output]
)

rd1a_tx_hash = api.compute_transaction_hash(rd1a)

rd1a_alice_witnesses = rd1a.sign(alice2.key, rd1a_tx_hash).witnesses

puts "bob create commitment tx 1b (C1b)"
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
    args: [alice.blake160, bob2.blake160],
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

c1b_bob_witnesses = c1b.sign(bob.key, c1b_tx_hash).witnesses

puts "Rd1b: bob could spend output-0 after 100 blocks confirmation"

rd1b_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: c1b_tx_hash, index: 0)),
  args: [],
  since: ((1 << 63) + 100).to_s
)

rd1b_output = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: Types::Script.new(
    args: [bob2.blake160],
    code_hash: api.system_script_code_hash
  )
)

rd1b = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point],
  inputs: [rd1b_input],
  outputs: [rd1b_output]
)

rd1b_tx_hash = api.compute_transaction_hash(rd1b)

rd1b_bob_witnesses = rd1b.sign(bob.key, rd1b_tx_hash).witnesses

puts "2.2 Exchange the signatures for the children"
puts "2.2.1 exchange signatures for the Revocable Delivery transaction"
# TODO: alice should keep rd1a for if we add Revocable Sequence Maturity in the commitment tx

rd1a_bob_witnesses = rd1a.sign(bob.key, rd1a_tx_hash).witnesses

rd1a_witnesses = []
rd1a_alice_witnesses.each_with_index do |alice_witness, index|
  rd1a_witnesses.push(Witness.new(data: alice_witness.data + rd1a_bob_witnesses[index].data))
end

rd1b_alice_witnesses = rd1b.sign(alice.key, rd1b_tx_hash).witnesses

rd1b_witnesses = []
rd1b_bob_witnesses.each_with_index do |bob_witness, index|
  rd1b_witnesses.push(Witness.new(data: rd1b_alice_witnesses[index].data + bob_witness.data))
end

puts "2.2.2 exchange signatures for the Commitment transaction"

c1a_bob_witnesses = c1a.sign(bob.key, c1a_tx_hash).witnesses

c1a_witnesses = []
c1a_alice_witnesses.each_with_index do |alice_witness, index|
  c1a_witnesses.push(Witness.new(data: alice_witness.data + c1a_bob_witnesses[index].data))
end

c1b_alice_witnesses = c1b.sign(alice.key, c1b_tx_hash).witnesses

c1b_witnesses = []
c1b_bob_witnesses.each_with_index do |bob_witness, index|
  c1b_witnesses.push(Witness.new(data: c1b_alice_witnesses[index].data + bob_witness.data))
end

puts "2.3 Sign the parent (Funding transaction)"

alice_funding_witnesses = unsigned_funding_transaction.sign(alice.key, funding_tx_hash).witnesses
bob_funding_witnesses = unsigned_funding_transaction.sign(bob.key, funding_tx_hash).witnesses

puts "2.4 Exchange the signatures for the parent"

funding_witnesses = alice_funding_witnesses[0..(inputs_from_alice.inputs.size - 1)] + bob_funding_witnesses[(inputs_from_alice.inputs.size)..-1]

unsigned_funding_transaction.witnesses = funding_witnesses

puts "2.5 Broadcast the parent on the blockchain"

puts api.send_transaction(unsigned_funding_transaction)

sleep 5

puts api.get_transaction(funding_tx_hash).tx_status.to_h

puts "3 new commit transaction"
puts "3.1 create commit transaction and sign"
puts "alice create commitment tx 2a (C2a)"
puts "   Only alice can broadcast"
puts "   Outputs:"
puts "      0: RSMC alice&bob 400 ckb"
puts "      1: no locktime for bob 200 ckb"

c2a_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: funding_tx_hash, index: 0)),
  args: [],
  since: "0"
)

c2a_output_0 = Types::Output.new(
  capacity: 400 * 10 ** 8,
  data: "0x",
  lock: Types::Script.new(
    args: [alice3.blake160, bob.blake160],
    code_hash: god_c.contracts[:tot][:binary_hash]
  )
)

c2a_output_1 = Types::Output.new(
  capacity: 200 * 10 ** 8,
  data: "0x",
  lock: bob.lock
)

c2a = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point, tot_outpoint],
  inputs: [c2a_input],
  outputs: [c2a_output_0, c2a_output_1]
)

c2a_tx_hash = api.compute_transaction_hash(c2a)

c2a_alice_witnesses = c2a.sign(alice.key, c2a_tx_hash).witnesses

puts "Rd2a: alice could spend output-0 100 blocks later"

rd2a_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: c2a_tx_hash, index: 0)),
  args: [],
  since: ((1 << 63) + 100).to_s
)

rd2a_output = Types::Output.new(
  capacity: 400 * 10 ** 8,
  data: "0x",
  lock: Types::Script.new(
    args: [alice3.blake160],
    code_hash: api.system_script_code_hash
  )
)

rd2a = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point],
  inputs: [rd2a_input],
  outputs: [rd2a_output]
)

rd2a_tx_hash = api.compute_transaction_hash(rd2a)

rd2a_alice_witnesses = rd2a.sign(alice3.key, rd1a_tx_hash).witnesses

puts "bob create commitment tx 2b (C2b)"
puts "   Only bob can broadcast"
puts "   Outputs:"
puts "      0: RSMC alice&bob 200 ckb"
puts "      1: no locktime for alice 400 ckb"

c2b_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: funding_tx_hash, index: 0)),
  args: [],
  since: "0"
)

c2b_output_0 = Types::Output.new(
  capacity: 200 * 10 ** 8,
  data: "0x",
  lock: Types::Script.new(
    args: [alice.blake160, bob3.blake160],
    code_hash: god_c.contracts[:tot][:binary_hash]
  )
)

c2b_output_1 = Types::Output.new(
  capacity: 400 * 10 ** 8,
  data: "0x",
  lock: alice.lock
)

c2b = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point, tot_outpoint],
  inputs: [c2b_input],
  outputs: [c2b_output_0, c2b_output_1]
)

c2b_tx_hash = api.compute_transaction_hash(c2b)

c2b_bob_witnesses = c2b.sign(bob.key, c2b_tx_hash).witnesses

puts "Rd2b: bob could spend output-0 100 blocks later"

rd2b_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: c2b_tx_hash, index: 0)),
  args: [],
  since: ((1 << 63) + 100).to_s
)

rd2b_output = Types::Output.new(
  capacity: 200 * 10 ** 8,
  data: "0x",
  lock: Types::Script.new(
    args: [bob3.blake160],
    code_hash: api.system_script_code_hash
  )
)

rd2b = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point],
  inputs: [rd2b_input],
  outputs: [rd2b_output]
)

rd2b_tx_hash = api.compute_transaction_hash(rd2b)

rd2b_bob_witnesses = rd2b.sign(bob3.key, rd2b_tx_hash).witnesses

puts "3.2 Exchange the signatures for the children"
puts "3.2.1 exchange signatures for the Revocable Delivery transaction"

c2a_bob_witnesses = c2a.sign(bob.key, c2a_tx_hash).witnesses
c2a_witnesses = []
c2a_alice_witnesses.each_with_index do |alice_witness, index|
  c2a_witnesses.push(Witness.new(data: alice_witness.data + c2a_bob_witnesses[index].data))
end

c2b_alice_witnesses = c2b.sign(alice.key, c2b_tx_hash).witnesses
c2b_witnesses = []
c2b_bob_witnesses.each_with_index do |bob_witness, index|
  c2b_witnesses.push(Witness.new(data: c2b_alice_witnesses[index].data + bob_witness.data))
end

puts "3.2.2 exchange signatures for the Commitment transaction"

rd2a_bob_witnesses = rd2a.sign(bob.key, rd2a_tx_hash).witnesses

rd2a_witnesses = []
rd2a_alice_witnesses.each_with_index do |alice_witness, index|
  rd2a_witnesses.push(Witness.new(data: alice_witness.data + rd2a_bob_witnesses[index].data))
end

rd2b_alice_witnesses = rd2b.sign(alice.key, rd2b_tx_hash).witnesses

rd2b_witnesses = []
rd2b_bob_witnesses.each_with_index do |bob_witness, index|
  rd2b_witnesses.push(Witness.new(data: rd2b_alice_witnesses[index].data + bob_witness.data))
end

puts "3.3 Breach Remedy Transaction for parent commit transaction"
puts "    alice discloses the alice2 private keys to the counterparty"
puts "    bob  discloses the bob2 private keys to the counterparty"

br2a_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: c1a_tx_hash, index: 0)),
  args: [],
  since: "0"
)

br2a_output = Types::Output.new(
  capacity: 300 * 10 ** 8,
  data: "0x",
  lock: Types::Script.new(
    args: [bob.blake160],
    code_hash: api.system_script_code_hash
  )
)

br2a = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point, tot_outpoint],
  inputs: [br2a_input],
  outputs: [br2a_output]
)

br2a_tx_hash = api.compute_transaction_hash(br2a)

br2a_alice_witnesses = br2a.sign(alice2.key, br2a_tx_hash).witnesses

br2b_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: c1b_tx_hash, index: 0)),
  args: [],
  since: "0"
)

br2b_output = Types::Output.new(
  capacity: 300 * 10 ** 8,
  data: "0x",
  lock: Types::Script.new(
    args: [alice.blake160],
    code_hash: api.system_script_code_hash
  )
)

br2b = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point, tot_outpoint],
  inputs: [br2b_input],
  outputs: [br2b_output]
)

br2b_tx_hash = api.compute_transaction_hash(br2b)

br2b_bob_witnesses = br2b.sign(bob2.key, br2b_tx_hash).witnesses

puts "3.4 Exchange the signatures for the Breach Remedy Transaction"

br2a_bob_witnesses = br2a.sign(bob.key, br2a_tx_hash).witnesses
br2b_alice_witnesses = br2b.sign(alice.key, br2b_tx_hash).witnesses

br2a_witnesses = []
br2a_alice_witnesses.each_with_index do |alice_witness, index|
  br2a_witnesses.push(Witness.new(data: alice_witness.data + br2a_bob_witnesses[index].data))
end

br2b_witnesses = []
br2b_bob_witnesses.each_with_index do |bob_witness, index|
  br2b_witnesses.push(Witness.new(data: br2b_alice_witnesses[index].data + bob_witness.data))
end

puts "Bob&Alice should destroy all old Commitment Transactions"

sleep 3
