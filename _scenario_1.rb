puts "Scenario_1: Alice broadcasts old commitment transaction and all the funds are given to the other party as a penalty"

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

rd1a_alice_witnesses = rd1a.sign(alice2.key, rd1a_tx_hash).witnesses

rd1a.witnesses = rd1a_alice_witnesses

sleep 3

begin
  api.send_transaction(rd1a)
rescue => exception
  puts exception
  puts "Alice should delivery rd1a after 10-block confirmation"
end

puts "Bob monitor that alice broadcasted the c1a"
puts "And broadcast the Breach Remedy Transaction of c1a"

br2a.witnesses = br2a_witnesses

bob_balance = bob.get_balance()

puts "Bob's balance: #{bob_balance}"

puts api.send_transaction(br2a)

sleep 8

puts api.get_transaction(br2a_tx_hash).tx_status.to_h

raise "got the wrong balance #{bob.get_balance}" if bob.get_balance != bob_balance + 300 * 10 ** 8

puts "Bob take Alice's fund #{300 * 10 ** 8} as a penalty"
puts "Bob's new balance: #{bob.get_balance}"

puts "alice: Oh my..."
puts "bob: Terrific \u{1f618} !"
puts "robot: see you next time!"
