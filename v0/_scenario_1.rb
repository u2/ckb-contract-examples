puts "Scenario_1: Alice broadcasts old commitment transaction and all the funds are given to the other party as a penalty"

c1a.witnesses = c1a_witnesses

puts "Alice broadcast the old commitment transaction c1a"
api.send_transaction(c1a)

sleep 5

puts "Alice try to broadcast the rd1a"

rd1a.witnesses = rd1a_alice_witnesses

begin
  api.send_transaction(rd1a)
rescue => exception
  puts exception
  puts "Alice should delivery rd1a after 100-block confirmation"
end

puts "Bob monitor that alice broadcasted the c1a"
puts "And broadcast the Breach Remedy Transaction of c1a"

br2a.witnesses = br2a_witnesses

bob_balance = bob.get_balance()

puts "Bob's balance: #{bob_balance}"

api.send_transaction(br2a)

sleep 5

raise "got the wrong balance #{bob.get_balance}" if bob.get_balance != bob_balance + 300 * 10 ** 8

puts "Bob take Alice's fund #{300 * 10 ** 8} as a penalty"
puts "Bob's new balance: #{bob.get_balance}"

puts "alice: Oh my..."
puts "bob: Terrific \u{1f618} !"
puts "robot: see you next time!"
