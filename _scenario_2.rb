puts "Scenario_2: Alice broadcasts old commitment transaction"
puts "            but Bob is napping,"
puts "            so Alice takes the fund in the old commitment transaction"

c1a.witnesses = c1a_witnesses

puts "Alice broadcast the old commitment transaction c1a"
api.send_transaction(c1a)

sleep 5

puts "Alice try to broadcast the rd1a but failed"

puts "Rd1a (Revocable Delivery transaction): alice could spend output-0 after 10 blocks confirmation"

rd1a_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: c1a_tx_hash, index: 0)),
  args: [],
  since: ((1 << 63) + 10).to_s
)

rd1a_output = Types::Output.new(
  capacity: capacity,
  data: "0x",
  lock: Types::Script.new(
    args: [alice.blake160],
    code_hash: api.system_script_code_hash
  )
)

rd1a = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point, revocable_maturity_outpoint],
  inputs: [rd1a_input],
  outputs: [rd1a_output]
)

rd1a_tx_hash = api.compute_transaction_hash(rd1a)

rd1a = rd1a.sign(alice2.key, rd1a_tx_hash)

alice_balance = alice.get_balance()

puts "Alice's balance #{alice_balance}"

puts "Bob is napping..."

sleep 28

api.send_transaction(rd1a)

sleep 10

raise "got the wrong balance #{alice.get_balance}" if alice.get_balance != alice_balance + 300 * 10 ** 8

puts "Alice takes the input-0 in the old commitment transaction #{300 * 10 ** 8}"
puts "Alice's new balance: #{alice.get_balance}"

puts "alice: Terrific \u{1f618} !"
puts "bob: Oh my..."
puts "robot: see you next time!"
