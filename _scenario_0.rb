puts "Scenario_0: Both parities comply the rules and cooperatively close out the channel"

puts "4. Exercise Settlement Tx"

sleep 5

es_input = Types::Input.new(
  previous_output: Types::OutPoint.new(cell: Types::CellOutPoint.new(tx_hash: funding_tx_hash, index: 0)),
  args: [],
  since: "0"
)

es_output_0 = Types::Output.new(
  capacity: 400 * 10 ** 8,
  data: "0x",
  lock: alice.lock
)

es_output_1 = Types::Output.new(
  capacity: 200 * 10 ** 8,
  data: "0x",
  lock: bob.lock
)

es = Transaction.new(
  version: 0,
  deps: [api.system_script_out_point, tot_outpoint],
  inputs: [es_input],
  outputs: [es_output_0, es_output_1]
)

es_tx_hash = api.compute_transaction_hash(es)

es_alice_witnesses = es.sign(alice.key, es_tx_hash).witnesses
es_bob_witnesses = es.sign(bob.key, es_tx_hash).witnesses

es_witnesses = []
es_alice_witnesses.each_with_index do |alice_witness, index|
  es_witnesses.push(Witness.new(data: alice_witness.data + es_bob_witnesses[index].data))
end

es.witnesses = es_witnesses

alice_balance = alice.get_balance
bob_balance = bob.get_balance

puts "alice balance: #{alice.get_balance}"
puts "bob balance: #{bob.get_balance}"

api.send_transaction(es)

sleep 10

puts api.get_transaction(es_tx_hash).tx_status.to_h

raise "blice's balance is not correct, got #{alice.get_balance}" if alice.get_balance != alice_balance + 400 * 10 ** 8
raise "bob's balance is not correct, got #{bob.get_balance}" if bob.get_balance != bob_balance + 200 * 10 ** 8

puts "now alice's balance is #{alice.get_balance}"
puts "now bob's balance is #{bob.get_balance}"

puts "alice: Fabulous \u{1f60e} !"
puts "bob: Terrific \u{1f618} !"
puts "robot: see you next time!"
